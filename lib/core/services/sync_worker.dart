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
  /// ADR-012: Implements Granular Processing to prevent UI freezing.
  Future<void> syncDownAll(
    Map<String, List<Map<String, dynamic>>> data, {
    bool forceOverwrite = false,
    void Function(String collection, double progress)? onProgress,
  }) async {
    if (_db.store.isClosed()) return;

    appLogger.info('syncDownAll started (Granular Mode)', context: 'SyncWorker');

    final sanitizedData = (_sanitizeForIsolate(data) as Map).cast<String, dynamic>();
    const totalSteps = 10; // 9 collections + 1 relink phase
    int currentStep = 0;

    void updateProgress(String col, double subProgress) {
      if (onProgress != null) {
        final progress = (currentStep + subProgress) / totalSteps;
        onProgress(col, progress);
      }
    }

    final collections = {
      'staff': _handleStaff,
      'customers': _handleCustomers,
      'vehicles': _handleVehicles,
      'inventory': _handleInventory,
      'service_master': _handleServiceMaster,
      'transactions': _handleTransactions,
      'inventory_history': _handleHistory,
      'sales': _handleSales,
      'expenses': _handleExpenses,
    };

    for (final entry in collections.entries) {
      final colName = entry.key;
      final handler = entry.value;
      
      updateProgress(colName, 0.1);
      
      try {
        final itemCount = (sanitizedData[colName] as List?)?.length ?? 0;
        appLogger.info('SyncWorker: Processing $colName with $itemCount items', context: 'SyncWorker');
        
        if (itemCount == 0) {
          appLogger.info('SyncWorker: Skipping $colName — no data from cloud', context: 'SyncWorker');
        } else {
          await _db.store.runInTransactionAsync(TxMode.write, handler, {
            'data': sanitizedData[colName] ?? [],
            'bengkelId': bengkelId,
            'forceOverwrite': forceOverwrite,
          });
          appLogger.info('SyncWorker: $colName completed successfully', context: 'SyncWorker');
        }
      } catch (e, stack) {
        appLogger.error(
          'Error syncing collection $colName: $e\nStack: $stack', 
          context: 'SyncWorker', error: e,
        );
        // Continue with other collections instead of failing entirely
      }

      currentStep++;
      updateProgress(colName, 1.0);
      
      // Yield to allow UI to breathe
      await Future.delayed(Duration.zero);
    }

    // Final Phase: Relink Relations
    updateProgress('relinking', 0.5);
    try {
      await _db.store.runInTransactionAsync(TxMode.write, _handleRelink, {
        'data': sanitizedData,
        'bengkelId': bengkelId,
      });
    } catch (e) {
      appLogger.error('Error in relink phase: $e', context: 'SyncWorker');
    }
    
    currentStep++;
    updateProgress('complete', 1.0);

    appLogger.info(
      'syncDownAll completed. Local DB counts: '
      'tx=${_db.transactionBox.count()}, '
      'customers=${_db.pelangganBox.count()}, '
      'stok=${_db.stokBox.count()}, '
      'staff=${_db.staffBox.count()}, '
      'vehicles=${_db.vehicleBox.count()}, '
      'history=${_db.stokHistoryBox.count()}, '
      'services=${_db.serviceMasterBox.count()}, '
      'sales=${_db.saleBox.count()}, '
      'expenses=${_db.expenseBox.count()}',
      context: 'SyncWorker',
    );
  }

  /// Recursively convert non-sendable types (like Timestamp) to sendable ones (like int).
  static dynamic _sanitizeForIsolate(dynamic data) {
    if (data is Timestamp) return data.millisecondsSinceEpoch;
    if (data is DateTime) return data.millisecondsSinceEpoch;
    if (data is String) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), _sanitizeForIsolate(value)));
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

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  static bool _toBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val != 0;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  // --- Static Handlers for runInTransactionAsync (Granular Sync) ---

  static void _handleStaff(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final staffBox = store.box<Staff>();
    final List<Staff> rawStaffList = [];
    for (var m in data) {
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
    staffBox.putMany(_deduplicateByUuid<Staff>(rawStaffList, (s) => s.uuid));
  }

  static void _handleCustomers(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final customerBox = store.box<Pelanggan>();
    final List<Pelanggan> rawCustomerList = [];
    appLogger.info('SyncWorker: Found ${data.length} customers in cloud data', context: 'SyncWorker');
    for (var m in data) {
      try {
        final uuid = m['uuid'] as String?;
        if (uuid == null) continue;

        final existing = customerBox.query(Pelanggan_.uuid.equals(uuid)).build().findFirst();
        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.nama = m['name'] ?? '';
          existing.telepon = m['phone'] ?? '';
          existing.alamat = m['address'] ?? '';
          existing.isDeleted = _toBool(m['isDeleted']);
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
            createdAt: m['createdAt'] != null ? _toDateTime(m['createdAt']) : null,
          )
            ..isDeleted = _toBool(m['isDeleted'])
            ..bengkelId = currentBengkelId
            ..updatedAt = m['updatedAt'] != null ? _toDateTime(m['updatedAt']) : DateTime.now()
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      } catch (e) {
        appLogger.error('Error parsing customer uuid=${m['uuid']}: $e', context: 'SyncWorker');
      }
    }
    final deduplicated = _deduplicateByUuid<Pelanggan>(rawCustomerList, (p) => p.uuid);
    appLogger.info('SyncWorker: Saving ${deduplicated.length} customers to ObjectBox', context: 'SyncWorker');
    customerBox.putMany(deduplicated);
  }

  static void _handleVehicles(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final vehicleBox = store.box<Vehicle>();
    final List<Vehicle> rawVehicleList = [];
    for (var m in data) {
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
    vehicleBox.putMany(_deduplicateByUuid<Vehicle>(rawVehicleList, (v) => v.uuid));
  }

  static void _handleInventory(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final stokBox = store.box<Stok>();
    final List<Stok> rawStokList = [];
    for (var m in data) {
      final uuid = m['uuid'] as String;
      final existing = stokBox.query(Stok_.uuid.equals(uuid)).build().findFirst();
      if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;
      if (existing != null) {
        existing.nama = m['nama'] ?? m['name'] ?? '';
        existing.sku = m['sku'];
        existing.hargaBeli = _toInt(m['hargaBeli'] ?? m['buyPrice']);
        existing.hargaJual = _toInt(m['hargaJual'] ?? m['sellPrice']);
        existing.jumlah = _toInt(m['jumlah'] ?? m['stock']);
        existing.minStok = _toInt(m['minStok'] ?? m['minStock'] ?? 5);
        existing.kategori = m['kategori'] ?? m['category'] ?? LogicConstants.catSparepart;
        existing.bengkelId = currentBengkelId;
        existing.updatedAt = _toDateTime(m['updatedAt']);
        existing.syncStatus = 2;
        existing.lastSyncedAt = DateTime.now();
        rawStokList.add(existing);
      } else {
        rawStokList.add(Stok(
          nama: m['nama'] ?? m['name'] ?? '',
          sku: m['sku'],
          hargaBeli: _toInt(m['hargaBeli'] ?? m['buyPrice']),
          hargaJual: _toInt(m['hargaJual'] ?? m['sellPrice']),
          jumlah: _toInt(m['jumlah'] ?? m['stock']),
          minStok: _toInt(m['minStok'] ?? m['minStock'] ?? 5),
          kategori: m['kategori'] ?? m['category'] ?? LogicConstants.catSparepart,
          uuid: uuid,
        )
          ..bengkelId = currentBengkelId
          ..createdAt = _toDateTime(m['createdAt'])
          ..updatedAt = _toDateTime(m['updatedAt'])
          ..syncStatus = 2
          ..lastSyncedAt = DateTime.now());
      }
    }
    stokBox.putMany(_deduplicateByUuid<Stok>(rawStokList, (s) => s.uuid));
  }

  static void _handleTransactions(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final transactionBox = store.box<Transaction>();
    final transactionItemBox = store.box<TransactionItem>();

    for (var m in data) {
      final uuid = m['uuid'] as String;
      Transaction tx;
      final existing = transactionBox.query(Transaction_.uuid.equals(uuid)).build().findFirst();
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
      tx.totalAmount = _toInt(m['totalAmount']);
      tx.partsCost = _toInt(m['partsCost']);
      tx.laborCost = _toInt(m['laborCost']);
      tx.totalRevenue = _toInt(m['totalRevenue']);
      tx.totalHpp = _toInt(m['totalHpp']);
      tx.totalMechanicBonus = _toInt(m['totalMechanicBonus']);
      tx.totalProfit = _toInt(m['totalProfit']);
      tx.createdAt = _toDateTime(m['createdAt']);
      tx.updatedAt = _toDateTime(m['updatedAt']);
      tx.syncStatus = 2;
      tx.lastSyncedAt = DateTime.now();

      transactionBox.put(tx);

      final existingItems = tx.items.toList();
      for (var item in existingItems) {
        transactionItemBox.remove(item.id);
      }

      final itemsList = m['items'] as List? ?? [];
      for (var im in itemsList) {
        final item = TransactionItem(
          name: im['name'] ?? '',
          price: _toInt(im['price']),
          costPrice: _toInt(im['costPrice']),
          quantity: _toInt(im['quantity'] ?? 1),
          isService: im['isService'] ?? false,
          notes: im['notes'],
          mechanicBonus: _toInt(im['mechanicBonus']),
          uuid: im['uuid'],
          createdAt: _toDateTime(im['createdAt']),
          updatedAt: _toDateTime(im['updatedAt']),
        )..bengkelId = currentBengkelId;
        item.transaction.target = tx;
        transactionItemBox.put(item);
      }
    }
  }

  static void _handleHistory(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final historyBox = store.box<StokHistory>();
    final List<StokHistory> rawHistoryList = [];
    for (var m in data) {
      final uuid = m['uuid'] as String;
      final existing = historyBox.query(StokHistory_.uuid.equals(uuid)).build().findFirst();
      if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;
      if (existing != null) {
        existing.stokUuid = m['stokUuid'] ?? '';
        existing.quantityChange = _toInt(m['quantityChange']);
        existing.previousQuantity = _toInt(m['previousQuantity']);
        existing.newQuantity = _toInt(m['newQuantity']);
        existing.type = m['type'] ?? LogicConstants.catAdjustment;
        existing.note = m['note'];
        existing.bengkelId = currentBengkelId;
        existing.syncStatus = 2;
        existing.lastSyncedAt = DateTime.now();
        rawHistoryList.add(existing);
      } else {
        rawHistoryList.add(StokHistory(
          stokUuid: m['stokUuid'] ?? '',
          quantityChange: _toInt(m['quantityChange']),
          previousQuantity: _toInt(m['previousQuantity']),
          newQuantity: _toInt(m['newQuantity']),
          type: m['type'] ?? LogicConstants.catAdjustment,
          note: m['note'],
          uuid: uuid,
          createdAt: _toDateTime(m['createdAt']),
        )
          ..bengkelId = currentBengkelId
          ..syncStatus = 2
          ..lastSyncedAt = DateTime.now());
      }
    }
    historyBox.putMany(_deduplicateByUuid<StokHistory>(rawHistoryList, (h) => h.uuid));
  }

  static void _handleServiceMaster(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final serviceMasterBox = store.box<ServiceMaster>();
    final List<ServiceMaster> rawServiceList = [];
    for (var m in data) {
      final uuid = m['uuid'] as String;
      final existing = serviceMasterBox.query(ServiceMaster_.uuid.equals(uuid)).build().findFirst();
      if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;
      if (existing != null) {
        existing.name = m['name'] ?? '';
        existing.basePrice = _toInt(m['basePrice']);
        existing.category = m['category'];
        existing.bengkelId = currentBengkelId;
        existing.syncStatus = 2;
        existing.lastSyncedAt = DateTime.now();
        rawServiceList.add(existing);
      } else {
        rawServiceList.add(ServiceMaster(
          name: m['name'] ?? '',
          basePrice: _toInt(m['basePrice']),
          category: m['category'],
          uuid: uuid,
          createdAt: _toDateTime(m['createdAt']),
          updatedAt: _toDateTime(m['updatedAt']),
        )
          ..bengkelId = currentBengkelId
          ..syncStatus = 2
          ..lastSyncedAt = DateTime.now());
      }
    }
    serviceMasterBox.putMany(_deduplicateByUuid<ServiceMaster>(rawServiceList, (s) => s.uuid));
  }

  static void _handleSales(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final saleBox = store.box<Sale>();
    final List<Sale> rawSaleList = [];
    for (var m in data) {
      final uuid = m['uuid'] as String;
      final existing = saleBox.query(Sale_.uuid.equals(uuid)).build().findFirst();
      if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;
      if (existing != null) {
        existing.itemName = m['itemName'] ?? '';
        existing.quantity = _toInt(m['quantity']);
        existing.totalPrice = _toInt(m['totalPrice']);
        existing.costPrice = _toInt(m['costPrice']);
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
          quantity: _toInt(m['quantity']),
          totalPrice: _toInt(m['totalPrice']),
          costPrice: _toInt(m['costPrice']),
          customerName: m['customerName'],
          stokUuid: m['stokUuid'],
          transactionId: m['transactionId'],
          trxNumber: m['trxNumber'] ?? '',
          uuid: uuid,
          createdAt: _toDateTime(m['createdAt']),
          updatedAt: _toDateTime(m['updatedAt']),
        )
          ..bengkelId = currentBengkelId
          ..syncStatus = 2
          ..lastSyncedAt = DateTime.now());
      }
    }
    saleBox.putMany(_deduplicateByUuid<Sale>(rawSaleList, (s) => s.uuid));
  }

  static void _handleExpenses(Store store, Map<String, dynamic> p) {
    final data = p['data'] as List? ?? [];
    final currentBengkelId = p['bengkelId'] as String;
    final forceOverwrite = p['forceOverwrite'] as bool;
    final expenseBox = store.box<Expense>();
    final List<Expense> rawExpenseList = [];
    appLogger.info('SyncWorker: Found ${data.length} expenses in cloud data', context: 'SyncWorker');
    for (var m in data) {
      try {
        final uuid = m['uuid'] as String?;
        if (uuid == null) continue;

        final existing = expenseBox.query(Expense_.uuid.equals(uuid)).build().findFirst();
        if (!forceOverwrite && _isLocalNewer(existing, m['updatedAt'])) continue;

        if (existing != null) {
          existing.amount = _toInt(m['amount']);
          existing.category = m['category'] as String? ?? 'Umum';
          existing.description = m['description'] as String? ?? '';
          existing.date = _toDateTime(m['date']);
          existing.photoPath = m['photoPath'] as String?;
          existing.isDeleted = _toBool(m['isDeleted']);
          existing.aiConfidence = _toDouble(m['aiConfidence']);
          existing.debtStatus = m['debtStatus'] as String?;
          existing.supplierName = m['supplierName'] as String?;
          existing.bengkelId = currentBengkelId;
          existing.syncStatus = 2;
          existing.lastSyncedAt = DateTime.now();
          rawExpenseList.add(existing);
        } else {
          rawExpenseList.add(Expense(
            amount: _toInt(m['amount']),
            category: m['category'] as String? ?? 'Umum',
            description: m['description'] as String? ?? '',
            date: _toDateTime(m['date']),
            uuid: uuid,
            bengkelId: currentBengkelId,
          )
            ..photoPath = m['photoPath'] as String?
            ..isDeleted = _toBool(m['isDeleted'])
            ..aiConfidence = _toDouble(m['aiConfidence'])
            ..debtStatus = m['debtStatus'] as String?
            ..supplierName = m['supplierName'] as String?
            ..createdAt = _toDateTime(m['createdAt'])
            ..updatedAt = _toDateTime(m['updatedAt'])
            ..syncStatus = 2
            ..lastSyncedAt = DateTime.now());
        }
      } catch (e) {
        appLogger.error('Error parsing expense uuid=${m['uuid']}: $e', context: 'SyncWorker');
      }
    }
    final deduplicated = _deduplicateByUuid<Expense>(rawExpenseList, (e) => e.uuid);
    appLogger.info('SyncWorker: Saving ${deduplicated.length} expenses to ObjectBox', context: 'SyncWorker');
    expenseBox.putMany(deduplicated);
  }

  static void _handleRelink(Store store, Map<String, dynamic> p) {
    final dataMap = p['data'] as Map;
    final staffBox = store.box<Staff>();
    final customerBox = store.box<Pelanggan>();
    final vehicleBox = store.box<Vehicle>();
    final transactionBox = store.box<Transaction>();
    final expenseBox = store.box<Expense>();

    // 1. Vehicle Owners
    for (var m in (dataMap['vehicles'] as List? ?? [])) {
      final ownerUuid = m['ownerUuid'] as String?;
      if (ownerUuid != null) {
        final v = vehicleBox.query(Vehicle_.uuid.equals(m['uuid'])).build().findFirst();
        final owner = customerBox.query(Pelanggan_.uuid.equals(ownerUuid)).build().findFirst();
        if (v != null && owner != null) {
          v.owner.target = owner;
          vehicleBox.put(v);
        }
      }
    }

    // 2. Transaction Relations
    for (var m in (dataMap['transactions'] as List? ?? [])) {
      final tx = transactionBox.query(Transaction_.uuid.equals(m['uuid'])).build().findFirst();
      if (tx == null) continue;

      bool changed = false;
      final custUuid = m['customerUuid'] as String?;
      if (custUuid != null) {
        tx.pelanggan.target = customerBox.query(Pelanggan_.uuid.equals(custUuid)).build().findFirst();
        changed = true;
      }
      final vehUuid = m['vehicleUuid'] as String?;
      if (vehUuid != null) {
        tx.vehicle.target = vehicleBox.query(Vehicle_.uuid.equals(vehUuid)).build().findFirst();
        changed = true;
      }
      final mechUuid = m['mechanicUuid'] as String?;
      if (mechUuid != null) {
        tx.mechanic.target = staffBox.query(Staff_.uuid.equals(mechUuid)).build().findFirst();
        changed = true;
      }
      if (changed) transactionBox.put(tx);
    }

    // 3. Expense Relations
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
  }
}

enum SyncWorkerState { idle, syncing, success, warning, error }

