import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../domain/entities/sync_queue_item.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_item.dart';
import '../../domain/entities/stok_history.dart';
import '../../domain/entities/service_master.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/expense.dart';
import 'firestore_sync_service.dart';
import '../providers/objectbox_provider.dart';
import '../../objectbox.g.dart';
import '../sync/sync_lock_manager.dart';
import '../sync/circuit_breaker.dart';
import '../sync/sync_telemetry.dart';
import '../sync/concurrency_pool.dart';
import 'device_session_service.dart';
import '../constants/app_strings.dart';
import '../constants/logic_constants.dart';
import 'session_manager.dart';
import '../utils/app_logger.dart';

/// 🏎️ SyncWorker — Optimized background worker with Concurrency Pool(2).
/// Implements the ServisLog+ Sync Framework v1.4 for production reliability.
class SyncWorker {
  final ObjectBoxProvider _db;
  final FirestoreSyncService _syncService;
  final DeviceSessionService? _deviceService;
  final SessionManager? _sessionManager;
  final SyncLockManager _lockManager;
  final String bengkelId;
  final String? userId;
  final Connectivity _connectivity;

  // FIX [PERINGATAN]: Tambah parameter syncWifiOnly agar setting dari UI
  // pengaturan benar-benar diterapkan saat memproses antrian sync.
  final bool syncWifiOnly;

  Timer? _timer;
  bool _isRunning = false;
  bool _isDisposed = false;
  bool _isProcessing = false;
  StreamSubscription? _connectivitySubscription;

  // Framework Components
  final _circuitBreaker = HierarchicalCircuitBreaker();
  final _pool = Pool(2); // Concurrency Level 2

  // Callbacks for UI updates
  void Function(SyncWorkerState state)? onStateChanged;

  SyncWorker({
    required ObjectBoxProvider db,
    required FirestoreSyncService syncService,
    required this.bengkelId,
    this.userId,
    DeviceSessionService? deviceService,
    SessionManager? sessionManager,
    SyncLockManager? lockManager,
    Connectivity? connectivity,
    this.onStateChanged,
    this.syncWifiOnly = false, // default: sync di semua koneksi
  })  : _db = db,
        _syncService = syncService,
        _deviceService = deviceService,
        _sessionManager = sessionManager,
        _lockManager = lockManager ?? SyncLockManager(),
        _connectivity = connectivity ?? Connectivity();

  /// Start background sync — checks every 30 seconds + on network change.
  /// FIX: Memastikan workshop ter-resolve sebelum memulai sync
  void start() {
    if (_isRunning || _isDisposed) return;
    _isRunning = true;

    // FIX: Pastikan workshop ter-resolve sebelum memproses queue
    // Ini penting untuk mendapatkan ownerId yang valid
    _sessionManager?.ensureWorkshopResolved().then((_) {
      appLogger.info(
        'SyncWorker started: workshopId=${_sessionManager.activeWorkshopId}, '
        'ownerId=${_sessionManager.activeWorkshopOwnerId}',
        context: 'SyncWorker',
      );
      
      // Process immediately after resolution
      _processQueue();
    }).catchError((e) {
      appLogger.warning(
        'Failed to resolve workshop, sync may use legacy path: $e',
        context: 'SyncWorker',
      );
      // Tetap coba proses meskipun resolusi gagal (akan menggunakan legacy path)
      _processQueue();
    });

    // Check every 120 seconds for automatic retries
    _timer = Timer.periodic(const Duration(seconds: 120), (_) {
      if (!_isDisposed && _isRunning && !_isProcessing) {
        _processQueue();
      }
    });

    // Also process on network change
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !_isDisposed && _isRunning) {
        _processQueue();
      }
    });

    SyncTelemetry().log(SyncEvent(
      type: 'worker_started',
      metadata: {
        'ownerId': _sessionManager?.activeWorkshopOwnerId,
        'workshopId': _sessionManager?.activeWorkshopId,
        'syncWifiOnly': syncWifiOnly
      },
      level: TelemetryLevel.info,
      timestamp: DateTime.now(),
    ));
  }

  /// Stop background sync.
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _lockManager.stopAutoHeartbeat();
    SyncTelemetry().log(SyncEvent(
      type: 'worker_stopped',
      level: TelemetryLevel.info,
      timestamp: DateTime.now(),
    ));
  }

  void dispose() {
    stop();
    _isDisposed = true;
    _connectivitySubscription?.cancel();
  }

  /// Enqueue an entity for sync.
  void enqueue({
    required String entityType,
    required String entityUuid,
    SyncPriority priority = SyncPriority.normal,
  }) {
    if (_db.store.isClosed()) {
      SyncTelemetry().log(SyncEvent(
        type: 'enqueue_skipped',
        metadata: {'reason': 'store_closed'},
        level: TelemetryLevel.warning,
        timestamp: DateTime.now(),
      ));
      return;
    }
    final item = SyncQueueItem(
      entityType: entityType,
      entityUuid: entityUuid,
      priority: priority.code,
    );
    _db.syncQueueBox.put(item);
    
    // Efficiency: Process immediately for ANY item if not already processing
    if (_isRunning && !_isProcessing) {
      _processQueue();
    }
  }

  /// Process the queue — using SyncLockManager and Concurrency Pool.
  Future<void> _processQueue() async {
    if (_db.store.isClosed() || _isProcessing) return;
    _isProcessing = true;

    // 1. Acquire lock with heartbeat
    if (!await _lockManager.acquire()) {
      appLogger.info(AppStrings.sync.anotherActive, context: 'SyncWorker'); 
      return;
    }

    try {
      // 1b. Device Heartbeat Sync
      final currentUserId = userId;
      if (_deviceService != null && currentUserId != null) {
        unawaited(_deviceService.heartbeatSync(currentUserId));
      }

      _lockManager.startAutoHeartbeat();
      SyncTelemetry().lockAcquired();

      // FIX [PERINGATAN]: Pemeriksaan koneksi sekarang menghormati
      // setting syncWifiOnly dari pengaturan pengguna.
      final connectivity = await _connectivity.checkConnectivity();

      if (connectivity == ConnectivityResult.none) {
        // Tidak ada koneksi sama sekali — skip
        return;
      }

      if (syncWifiOnly && connectivity != ConnectivityResult.wifi) {
        // User memilih "Sync hanya via WiFi" tapi sedang pakai data seluler
        appLogger.info(AppStrings.sync.wifiOnlyNotice, context: 'SyncWorker'); 
        SyncTelemetry().log(SyncEvent(
          type: 'sync_skipped_wifi_only',
          metadata: {'connectivity': connectivity.toString()},
          level: TelemetryLevel.info,
          timestamp: DateTime.now(),
        ));
        return;
      }

      // 1. Session & Connectivity Protection
      if (_sessionManager != null) {
        final sessionStatus = await _sessionManager.validateSession();
        if (sessionStatus == SessionStatus.blocked || 
            sessionStatus == SessionStatus.invalid) {
          appLogger.warning('Sync paused (Session Blocked/Invalid)', context: 'SyncWorker');
          return;
        }
      }

      onStateChanged?.call(SyncWorkerState.syncing);

      // 2. Fetch pending items
      final items = _db.syncQueueBox
          .query(SyncQueueItem_.status.equals('pending'))
          .order(SyncQueueItem_.priority)
          .order(SyncQueueItem_.createdAt)
          .build()
          .find();

      if (items.isEmpty) {
        onStateChanged?.call(SyncWorkerState.idle);
        return;
      }

      // 3. Process with Concurrency Pool(2)
      await Future.wait(
        items.map((item) => _pool.withResource(() => _syncWithProtection(item))),
        eagerError: false,
      );

      final failedCount = _db.syncQueueBox
              .query(SyncQueueItem_.status.equals('failed'))
              .build()
              .count();

      final pendingCount = _db.syncQueueBox
              .query(SyncQueueItem_.status.equals('pending'))
              .build()
              .count();

      if (failedCount > 0) {
        onStateChanged?.call(SyncWorkerState.error);
      } else if (pendingCount > 0) {
        onStateChanged?.call(SyncWorkerState.warning);
      } else {
        onStateChanged?.call(SyncWorkerState.success);
      }
    } catch (e, stack) {
      SyncTelemetry().log(SyncEvent(
        type: 'queue_processing_error',
        metadata: {'error': e.toString()},
        level: TelemetryLevel.error,
        stackTrace: stack,
        timestamp: DateTime.now(),
      ));
      onStateChanged?.call(SyncWorkerState.error);
    } finally {
      await _lockManager.release();
      _lockManager.stopAutoHeartbeat(); 
      SyncTelemetry().lockReleased();
      _isProcessing = false;
    }
  }

  /// Forces a retry of all failed items by moving them back to pending.
  void retryFailedItems() {
    final failedItems = _db.syncQueueBox
        .query(SyncQueueItem_.status.equals('failed'))
        .build()
        .find();
    
    if (failedItems.isEmpty) return;

    for (final item in failedItems) {
      item.status = 'pending';
      item.retryCount = 0;
    }
    _db.syncQueueBox.putMany(failedItems);
    
    if (_isRunning && !_isProcessing) {
      _processQueue();
    }
  }

  /// Returns a summary of the current sync queue.
  Map<String, int> getQueueSummary() {
    final pending = _db.syncQueueBox.query(SyncQueueItem_.status.equals('pending')).build().count();
    final synced = _db.syncQueueBox.query(SyncQueueItem_.status.equals('synced')).build().count();
    final failed = _db.syncQueueBox.query(SyncQueueItem_.status.equals('failed')).build().count();
    final syncing = _db.syncQueueBox.query(SyncQueueItem_.status.equals('syncing')).build().count();

    return {
      'pending': pending,
      'synced': synced,
      'failed': failed,
      'syncing': syncing,
      'total': pending + synced + failed + syncing,
    };
  }

  /// Protects single item sync with CircuitBreaker and Telemetry.
  Future<void> _syncWithProtection(SyncQueueItem item) async {
    // 1. Exponential Backoff Check
    if (item.retryCount > 0 && item.lastRetryAt != null) {
      // Delay = 2^(retryCount-1) minutes. Clamp to max 4 minutes.
      final delayMins = (1 << (item.retryCount - 1)).clamp(1, 4);
      final nextAllowed = item.lastRetryAt!.add(Duration(minutes: delayMins));
      
      if (DateTime.now().isBefore(nextAllowed)) {
        return;
      }
    }

    final decision =
        _circuitBreaker.shouldProceed(item.entityUuid, DriveErrorType.unknown);
    if (decision == SyncDecision.block) return;

    try {
      item.status = 'syncing';
      item.lastRetryAt = DateTime.now(); // Record start of attempt
      _db.syncQueueBox.put(item);

      SyncTelemetry().syncStart(item.entityUuid, item.entityType);
      final startTime = DateTime.now();

      await _syncEntity(item);

      item.status = 'synced';
      item.syncedAt = DateTime.now();
      item.retryCount = 0;
      _db.syncQueueBox.put(item);

      _circuitBreaker.recordSuccess(item.entityUuid);
      SyncTelemetry()
          .syncSuccess(item.entityUuid, DateTime.now().difference(startTime));
    } catch (e) {
      item.retryCount++;
      final errorType = _classifyError(e);
      _circuitBreaker.recordFailure(item.entityUuid, errorType);

      if (item.retryCount >= 5) {
        item.status = 'failed';
      } else {
        item.status = 'pending';
      }
      _db.syncQueueBox.put(item);

      SyncTelemetry().syncFailed(
        item.entityUuid,
        e.toString(),
        errorType: errorType,
        retryCount: item.retryCount,
      );
    }
  }

  /// Categorize errors for CircuitBreaker decisions.
  DriveErrorType _classifyError(dynamic e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains('quota')) return DriveErrorType.quotaExceeded;
    if (errorString.contains('ratelimit') || errorString.contains('429')) {
      return DriveErrorType.rateLimit;
    }
    if (errorString.contains('auth') || errorString.contains('401')) {
      return DriveErrorType.auth;
    }
    if (errorString.contains('permission') || errorString.contains('403')) {
      return DriveErrorType.permission;
    }
    if (errorString.contains('not found') || errorString.contains('404')) {
      return DriveErrorType.notFound;
    }
    if (errorString.contains('network') ||
        errorString.contains('connectivity')) {
      return DriveErrorType.network;
    }
    return DriveErrorType.unknown;
  }

  /// Sync a single entity (Core Implementation).
  Future<void> _syncEntity(SyncQueueItem item) async {
    final now = DateTime.now();
    final syncedCode = SyncStatus.synced.code;

    switch (item.entityType) {
      case 'transaction':
        final tx = _db.transactionBox
            .query(Transaction_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (tx != null) {
          await _syncService.pushTransaction(bengkelId, tx);
          tx.syncStatus = syncedCode;
          tx.lastSyncedAt = now;
          _db.transactionBox.put(tx);
        }
        break;

      case 'pelanggan':
        final p = _db.pelangganBox
            .query(Pelanggan_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (p != null) {
          await _syncService.pushPelanggan(bengkelId, p);
          p.syncStatus = syncedCode;
          p.lastSyncedAt = now;
          _db.pelangganBox.put(p);
        }
        break;

      case 'stok':
        final s = _db.stokBox
            .query(Stok_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (s != null) {
          await _syncService.pushStok(bengkelId, s);
          s.syncStatus = syncedCode;
          s.lastSyncedAt = now;
          _db.stokBox.put(s);
        }
        break;

      case 'staff':
        final s = _db.staffBox
            .query(Staff_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (s != null) {
          await _syncService.pushStaff(bengkelId, s);
          s.syncStatus = syncedCode;
          s.lastSyncedAt = now;
          _db.staffBox.put(s);
        }
        break;

      case 'vehicle':
        final v = _db.vehicleBox
            .query(Vehicle_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (v != null) {
          await _syncService.pushVehicle(bengkelId, v);
          v.syncStatus = syncedCode;
          v.lastSyncedAt = now;
          _db.vehicleBox.put(v);
        }
        break;

      case 'stok_history':
        final sh = _db.stokHistoryBox
            .query(StokHistory_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (sh != null) {
          await _syncService.pushStokHistory(bengkelId, sh);
          sh.syncStatus = syncedCode;
          sh.lastSyncedAt = now;
          _db.stokHistoryBox.put(sh);
        }
        break;

      case 'service_master':
        final sm = _db.serviceMasterBox
            .query(ServiceMaster_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (sm != null) {
          await _syncService.pushServiceMaster(bengkelId, sm);
          sm.syncStatus = syncedCode;
          sm.lastSyncedAt = now;
          _db.serviceMasterBox.put(sm);
        }
        break;

      case 'sale':
        final s = _db.saleBox
            .query(Sale_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (s != null) {
          await _syncService.pushSale(bengkelId, s);
          s.syncStatus = syncedCode;
          s.lastSyncedAt = now;
          _db.saleBox.put(s);
        }
        break;

      case 'expense':
        final e = _db.expenseBox
            .query(Expense_.uuid.equals(item.entityUuid))
            .build()
            .findFirst();
        if (e != null) {
          await _syncService.pushExpense(bengkelId, e);
          e.syncStatus = syncedCode;
          e.lastSyncedAt = now;
          _db.expenseBox.put(e);
        }
        break;

      default:
        appLogger.warning('Unknown entity type: ${item.entityType}',
            context: 'SyncWorker');
    }
  }

  static bool _isLocalNewer(dynamic existing, dynamic cloudUpdatedAtStr) {
    // REINSTALL CASE: database kosong
    if (existing == null) return false;
    if (cloudUpdatedAtStr == null) return false;
    
    try {
      DateTime? existingUpdatedAt;
      
      // Safe type checking (bukan dynamic casting)
      switch (existing) {
        case Staff s: existingUpdatedAt = s.updatedAt;
        case Pelanggan p: existingUpdatedAt = p.updatedAt;
        case Stok s: existingUpdatedAt = s.updatedAt;
        case Transaction t: existingUpdatedAt = t.updatedAt;
        case Vehicle v: existingUpdatedAt = v.updatedAt;
        case StokHistory h: existingUpdatedAt = h.createdAt;
        case ServiceMaster sm: existingUpdatedAt = sm.updatedAt;
        case Sale sale: existingUpdatedAt = sale.updatedAt;
        case Expense e: existingUpdatedAt = e.updatedAt;
        default: return false; // Tidak punya updatedAt, overwrite saja
      }
      
      if (existingUpdatedAt == null) return false;
      
      final cloudUpdatedAt = _toDateTime(cloudUpdatedAtStr);
      return existingUpdatedAt.isAfter(cloudUpdatedAt);
    } catch (e) {
      appLogger.warning('_isLocalNewer error: $e', context: 'SyncWorker');
      return false; // JANGAN SKIP DATA jika error
    }
  }

  /// Rebuild local database from Firestore data (Restore process).
  /// ADR-012: Implements Upsert logic to prevent Unique Constraint violations.
  Future<void> syncDownAll(
    Map<String, List<Map<String, dynamic>>> data, {
    bool forceOverwrite = false,
  }) async {
    if (_db.store.isClosed()) return;

    // FIX: Log data yang masuk untuk debugging
    appLogger.info(
      'syncDownAll called with: '
      'transactions=${data['transactions']?.length ?? 0}, '
      'customers=${data['customers']?.length ?? 0}, '
      'inventory=${data['inventory']?.length ?? 0}, '
      'staff=${data['staff']?.length ?? 0}, '
      'vehicles=${data['vehicles']?.length ?? 0}, '
      'sales=${data['sales']?.length ?? 0}, '
      'expenses=${data['expenses']?.length ?? 0}',
      context: 'SyncWorker',
    );

    // Sanitize data to remove non-sendable types (like Timestamp)
    final sanitizedData = _sanitizeForIsolate(data);

    // Pass bengkelId to the isolate
    final payload = {
      'data': sanitizedData,
      'bengkelId': bengkelId,
    };

    await _db.store.runInTransactionAsync(TxMode.write, (store, p) {
      final dataMap = p['data'] as Map;
      final currentBengkelId = p['bengkelId'] as String;

      // 1. Staff (with Upsert)
      final staffBox = store.box<Staff>();
      final List<Staff> rawStaffList = [];
      for (var m in (dataMap['staff'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = staffBox.query(Staff_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.name = m['name'] ?? '';
          existing.role = m['role'] ?? LogicConstants.roleMekanik;
          existing.phoneNumber = m['phone'];
          existing.bengkelId = currentBengkelId;
          existing.isActive = m['isActive'] ?? true;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawStaffList.add(existing);
        } else {
          rawStaffList.add(Staff(
            name: m['name'] ?? '',
            role: m['role'] ?? LogicConstants.roleMekanik,
            phoneNumber: m['phone'],
            uuid: uuid,
          )
            ..bengkelId = currentBengkelId
            ..isActive = m['isActive'] ?? true
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }

      final staffList = _deduplicateByUuid<Staff>(rawStaffList, (s) => s.uuid);
      staffBox.putMany(staffList);

      // 2. Customers (with Upsert)
      final customerBox = store.box<Pelanggan>();
      final List<Pelanggan> rawCustomerList = [];
      for (var m in (dataMap['customers'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = customerBox.query(Pelanggan_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.nama = m['name'] ?? '';
          existing.telepon = m['phone'] ?? '';
          existing.alamat = m['address'] ?? '';
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawCustomerList.add(existing);
        } else {
          rawCustomerList.add(Pelanggan(
            nama: m['name'] ?? '',
            telepon: m['phone'] ?? '',
            alamat: m['address'] ?? '',
            uuid: uuid,
          )
            ..bengkelId = currentBengkelId
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }

      final customerList =
          _deduplicateByUuid<Pelanggan>(rawCustomerList, (p) => p.uuid);
      customerBox.putMany(customerList);

      // 3. Vehicles (with Upsert)
      final vehicleBox = store.box<Vehicle>();
      final List<Vehicle> rawVehicleList = [];
      for (var m in (dataMap['vehicles'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = vehicleBox.query(Vehicle_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.model = m['model'] ?? '';
          existing.plate = m['plate'] ?? '';
          existing.type = m['type'] ?? LogicConstants.vehicleMotor;
          existing.vin = m['vin'] ?? '';
          existing.year = m['year'];
          existing.color = m['color'];
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawVehicleList.add(existing);
        } else {
          rawVehicleList.add(Vehicle(
            model: m['model'] ?? '',
            plate: m['plate'] ?? '',
            type: m['type'] ?? LogicConstants.vehicleMotor,
            vin: m['vin'] ?? '',
            year: m['year'],
            color: m['color'],
            uuid: uuid,
          )
            ..bengkelId = currentBengkelId
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }

      final vehicleList =
          _deduplicateByUuid<Vehicle>(rawVehicleList, (v) => v.uuid);
      vehicleBox.putMany(vehicleList);

      // Set owner reference for vehicles
      for (var m in (dataMap['vehicles'] as List? ?? [])) {
        final ownerUuid = m['ownerUuid'] as String?;
        if (ownerUuid != null) {
          final v = vehicleBox
              .query(Vehicle_.uuid.equals(m['uuid']))
              .build()
              .findFirst();
          final owner = customerBox
              .query(Pelanggan_.uuid.equals(ownerUuid))
              .build()
              .findFirst();
          if (v != null && owner != null) {
            v.owner.target = owner;
            vehicleBox.put(v);
          }
        }
      }

      // 4. Inventory (Stok) with Upsert
      final stokBox = store.box<Stok>();
      final List<Stok> rawStokList = [];
      for (var m in (dataMap['inventory'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = stokBox.query(Stok_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.nama = m['nama'] ?? m['name'] ?? '';
          existing.sku = m['sku'];
          existing.hargaBeli = (m['hargaBeli'] ?? m['buyPrice'] ?? 0).toInt();
          existing.hargaJual = (m['hargaJual'] ?? m['sellPrice'] ?? 0).toInt();
          existing.jumlah = (m['jumlah'] ?? m['stock'] ?? 0).toInt();
          existing.minStok = (m['minStok'] ?? m['minStock'] ?? 5).toInt();
          existing.kategori =
              m['kategori'] ?? m['category'] ?? LogicConstants.catSparepart;
          existing.bengkelId = currentBengkelId;
          existing.updatedAt = SyncWorker._toDateTime(m['updatedAt']);
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawStokList.add(existing);
        } else {
          rawStokList.add(Stok(
            nama: m['nama'] ?? m['name'] ?? '',
            sku: m['sku'],
            hargaBeli: (m['hargaBeli'] ?? m['buyPrice'] ?? 0).toInt(),
            hargaJual: (m['hargaJual'] ?? m['sellPrice'] ?? 0).toInt(),
            jumlah: (m['jumlah'] ?? m['stock'] ?? 0).toInt(),
            minStok: (m['minStok'] ?? m['minStock'] ?? 5).toInt(),
            kategori:
                m['kategori'] ?? m['category'] ?? LogicConstants.catSparepart,
            uuid: uuid,
          )
            ..bengkelId = currentBengkelId
            ..createdAt = SyncWorker._toDateTime(m['createdAt'])
            ..updatedAt = SyncWorker._toDateTime(m['updatedAt'])
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }

      final stokList = _deduplicateByUuid<Stok>(rawStokList, (s) => s.uuid);
      stokBox.putMany(stokList);

      // 5. Transactions & Items (with Upsert)
      final transactionBox = store.box<Transaction>();
      final transactionItemBox = store.box<TransactionItem>();

      for (var m in (dataMap['transactions'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        Transaction tx;
        final existing = transactionBox
            .query(Transaction_.uuid.equals(uuid))
            .build()
            .findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          tx = existing;
          tx.customerName = m['customerName'] ?? '';
          tx.customerPhone = m['customerPhone'] ?? '';
          tx.vehicleModel = m['vehicleModel'] ?? '';
          tx.vehiclePlate = m['vehiclePlate'] ?? '';
          tx.trxNumber = m['trxNumber'] ?? '';
          tx.complaint = m['complaint'];
          tx.mechanicNotes = m['mechanicNotes'];
          tx.recommendationTimeMonth = m['recommendationTimeMonth'];
          tx.recommendationKm = m['recommendationKm'];
          tx.odometer = m['odometer'];
        } else {
          tx = Transaction(
            customerName: m['customerName'] ?? '',
            customerPhone: m['customerPhone'] ?? '',
            vehicleModel: m['vehicleModel'] ?? '',
            vehiclePlate: m['vehiclePlate'] ?? '',
            uuid: uuid,
            trxNumber: m['trxNumber'],
            complaint: m['complaint'],
            mechanicNotes: m['mechanicNotes'],
            recommendationTimeMonth: m['recommendationTimeMonth'],
            recommendationKm: m['recommendationKm'],
            odometer: m['odometer'],
          );
        }

        tx.bengkelId = currentBengkelId;
        tx.status = m['status'] ?? LogicConstants.trxPending;
        tx.statusValue = m['statusValue'] ?? 0;
        tx.paymentMethod = m['paymentMethod'];
        tx.totalAmount = (m['totalAmount'] ?? 0).toInt();
        tx.partsCost = (m['partsCost'] ?? 0).toInt();
        tx.laborCost = (m['laborCost'] ?? 0).toInt();
        tx.totalRevenue = (m['totalRevenue'] ?? 0).toInt();
        tx.totalHpp = (m['totalHpp'] ?? 0).toInt();
        tx.totalMechanicBonus = (m['totalMechanicBonus'] ?? 0).toInt();
        tx.totalProfit = (m['totalProfit'] ?? 0).toInt();
        tx.createdAt = SyncWorker._toDateTime(m['createdAt']);
        tx.updatedAt = SyncWorker._toDateTime(m['updatedAt']);
        tx.syncStatus = 2; // Marked as synced
        tx.lastSyncedAt = DateTime.now();

        // Set relations
        final custUuid = m['customerUuid'] as String?;
        if (custUuid != null) {
          tx.pelanggan.target = customerBox
              .query(Pelanggan_.uuid.equals(custUuid))
              .build()
              .findFirst();
        }
        final vehUuid = m['vehicleUuid'] as String?;
        if (vehUuid != null) {
          tx.vehicle.target = vehicleBox
              .query(Vehicle_.uuid.equals(vehUuid))
              .build()
              .findFirst();
        }
        final mechUuid = m['mechanicUuid'] as String?;
        if (mechUuid != null) {
          tx.mechanic.target = staffBox
              .query(Staff_.uuid.equals(mechUuid))
              .build()
              .findFirst();
        }

        transactionBox.put(tx);

        // Process items: Clear old and insert fresh for reliability
        final existingItems = tx.items.toList();
        for (var item in existingItems) {
          transactionItemBox.remove(item.id);
        }

        final itemsList = m['items'] as List? ?? [];
        for (var im in itemsList) {
          final item = TransactionItem(
            name: im['name'] ?? '',
            price: (im['price'] ?? 0).toInt(),
            costPrice: (im['costPrice'] ?? 0).toInt(),
            quantity: (im['quantity'] ?? 1).toInt(),
            isService: im['isService'] ?? false,
            notes: im['notes'],
            mechanicBonus: (im['mechanicBonus'] ?? 0).toInt(),
            uuid: im['uuid'],
            createdAt: SyncWorker._toDateTime(im['createdAt']),
            updatedAt: SyncWorker._toDateTime(im['updatedAt']),
          )..bengkelId = currentBengkelId;
          item.transaction.target = tx;
          transactionItemBox.put(item);
        }
      }

      // 6. Inventory History with Upsert
      final historyBox = store.box<StokHistory>();
      final List<StokHistory> rawHistoryList = [];
      for (var m in (dataMap['stok_history'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = historyBox.query(StokHistory_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.stokUuid = m['stokUuid'] ?? '';
          existing.quantityChange = (m['quantityChange'] ?? 0).toInt();
          existing.previousQuantity = (m['previousQuantity'] ?? 0).toInt();
          existing.newQuantity = (m['newQuantity'] ?? 0).toInt();
          existing.type = m['type'] ?? LogicConstants.catAdjustment;
          existing.note = m['note'];
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawHistoryList.add(existing);
        } else {
          rawHistoryList.add(StokHistory(
            stokUuid: m['stokUuid'] ?? '',
            quantityChange: (m['quantityChange'] ?? 0).toInt(),
            previousQuantity: (m['previousQuantity'] ?? 0).toInt(),
            newQuantity: (m['newQuantity'] ?? 0).toInt(),
            type: m['type'] ?? LogicConstants.catAdjustment,
            note: m['note'],
            uuid: uuid,
            createdAt: SyncWorker._toDateTime(m['createdAt']),
          )
            ..bengkelId = currentBengkelId
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }

      final historyList =
          _deduplicateByUuid<StokHistory>(rawHistoryList, (h) => h.uuid);
      historyBox.putMany(historyList);

      // 7. Service Master with Upsert
      final serviceMasterBox = store.box<ServiceMaster>();
      final List<ServiceMaster> rawServiceList = [];
      for (var m in (dataMap['service_master'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = serviceMasterBox.query(ServiceMaster_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.name = m['name'] ?? '';
          existing.basePrice = (m['basePrice'] ?? 0).toInt();
          existing.category = m['category'];
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawServiceList.add(existing);
        } else {
          rawServiceList.add(ServiceMaster(
            name: m['name'] ?? '',
            basePrice: (m['basePrice'] ?? 0).toInt(),
            category: m['category'],
            uuid: uuid,
            createdAt: SyncWorker._toDateTime(m['createdAt']),
            updatedAt: SyncWorker._toDateTime(m['updatedAt']),
          )
            ..bengkelId = currentBengkelId
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }
      final serviceList = _deduplicateByUuid<ServiceMaster>(rawServiceList, (s) => s.uuid);
      serviceMasterBox.putMany(serviceList);

      // 8. Sales with Upsert
      final saleBox = store.box<Sale>();
      final List<Sale> rawSaleList = [];
      for (var m in (dataMap['sales'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = saleBox.query(Sale_.uuid.equals(uuid)).build().findFirst();

        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.itemName = m['itemName'] ?? '';
          existing.quantity = (m['quantity'] ?? 0).toInt();
          existing.totalPrice = (m['totalPrice'] ?? 0).toInt();
          existing.costPrice = (m['costPrice'] ?? 0).toInt();
          existing.paymentMethod = m['paymentMethod'];
          existing.customerName = m['customerName'];
          existing.stokUuid = m['stokUuid'];
          existing.transactionId = m['transactionId'];
          existing.trxNumber = m['trxNumber'] ?? '';
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawSaleList.add(existing);
        } else {
          rawSaleList.add(Sale(
            itemName: m['itemName'] ?? '',
            quantity: (m['quantity'] ?? 0).toInt(),
            totalPrice: (m['totalPrice'] ?? 0).toInt(),
            costPrice: (m['costPrice'] ?? 0).toInt(),
            customerName: m['customerName'],
            stokUuid: m['stokUuid'],
            transactionId: m['transactionId'],
            trxNumber: m['trxNumber'] ?? '',
            uuid: uuid,
            createdAt: SyncWorker._toDateTime(m['createdAt']),
            updatedAt: SyncWorker._toDateTime(m['updatedAt']),
          )
            ..bengkelId = currentBengkelId
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }
      final saleList = _deduplicateByUuid<Sale>(rawSaleList, (s) => s.uuid);
      saleBox.putMany(saleList);

      // 9. Expenses with Upsert
      final expenseBox = store.box<Expense>();
      final List<Expense> rawExpenseList = [];
      for (var m in (dataMap['expenses'] as List? ?? [])) {
        final uuid = m['uuid'] as String;
        final existing = expenseBox.query(Expense_.uuid.equals(uuid)).build().findFirst();
        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.amount = (m['amount'] ?? 0).toInt();
          existing.category = m['category'] ?? '';
          existing.description = m['description'] ?? '';
          existing.date = SyncWorker._toDateTime(m['date']);
          existing.photoPath = m['photoPath'];
          existing.isDeleted = m['isDeleted'] ?? false;
          existing.debtStatus = m['debtStatus'];
          existing.supplierName = m['supplierName'];
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawExpenseList.add(existing);
        } else {
          rawExpenseList.add(Expense(
            amount: (m['amount'] ?? 0).toInt(),
            category: m['category'] ?? '',
            description: m['description'] ?? '',
            date: SyncWorker._toDateTime(m['date']),
            uuid: uuid,
            bengkelId: currentBengkelId,
          )
            ..photoPath = m['photoPath']
            ..isDeleted = m['isDeleted'] ?? false
            ..debtStatus = m['debtStatus']
            ..supplierName = m['supplierName']
            ..createdAt = SyncWorker._toDateTime(m['createdAt'])
            ..updatedAt = SyncWorker._toDateTime(m['updatedAt'])
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      }
      final expenseList = _deduplicateByUuid<Expense>(rawExpenseList, (e) => e.uuid);
      expenseBox.putMany(expenseList);

      // 10. Link Expense relations (Parent-Child for debts/repayments)
      for (var m in (dataMap['expenses'] as List? ?? [])) {
        final parentUuid = m['parentExpenseUuid'] as String?;
        if (parentUuid != null) {
          final current = expenseBox.query(Expense_.uuid.equals(m['uuid'])).build().findFirst();
          final parent = expenseBox.query(Expense_.uuid.equals(parentUuid)).build().findFirst();
          if (current != null && parent != null) {
            current.parentExpense.target = parent;
            expenseBox.put(current);
          }
        }
      }
      
      // FIX: Log hasil penyimpanan di dalam transaction
      // Catatan: appLogger tidak bisa dipanggil dari isolate, jadi kita skip logging di sini
      // dan rely on logging di luar transaction
    }, payload); // Fix: pass payload instead of sanitizedData
    
    // FIX: Log hasil akhir setelah transaction selesai
    appLogger.info(
      'syncDownAll completed. Local DB counts: '
      'tx=${_db.transactionBox.count()}, '
      'customers=${_db.pelangganBox.count()}, '
      'stok=${_db.stokBox.count()}, '
      'staff=${_db.staffBox.count()}, '
      'vehicles=${_db.vehicleBox.count()}, '
      'sales=${_db.saleBox.count()}, '
      'expenses=${_db.expenseBox.count()}',
      context: 'SyncWorker',
    );
  }

  /// Recursively convert non-sendable types (like Timestamp) to sendable ones (like int).
  static dynamic _sanitizeForIsolate(dynamic data) {
    if (data is Timestamp) return data.millisecondsSinceEpoch;
    if (data is DateTime) return data.millisecondsSinceEpoch;
    if (data is String) {
      // FIX: Konversi ISO string ke milliseconds
      final parsed = DateTime.tryParse(data);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key, _sanitizeForIsolate(value)));
    }
    if (data is List) {
      return data.map((item) => _sanitizeForIsolate(item)).toList();
    }
    return data;
  }

  static DateTime _toDateTime(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      // FIX: Parse ISO 8601 string
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
    }
    return DateTime.now(); // fallback terakhir
  }

  void cleanupSyncedItems() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final oldItems = _db.syncQueueBox
        .query(SyncQueueItem_.status.equals('synced') &
            SyncQueueItem_.syncedAt
                .lessThan(cutoff.millisecondsSinceEpoch))
        .build()
        .find();
    for (final item in oldItems) {
      _db.syncQueueBox.remove(item.id);
    }
  }

  /// Helper method for de-duplicating a list based on UUID.
  /// ADR-012: Ensures only the latest entry per UUID is processed during recovery.
  static List<T> _deduplicateByUuid<T>(
      List<T> list, String Function(T) getUuid) {
    final seen = <String, T>{};
    for (final item in list) {
      final uuid = getUuid(item);
      // Latest entry wins
      seen[uuid] = item;
    }
    return seen.values.toList();
  }
}

enum SyncWorkerState { idle, syncing, success, warning, error }

