/// 📚 Firestore Index Documentation
///
/// Required composite indexes for this service:
///
/// 1. transactions collection:
///    - Collection: bengkel/{bengkelId}/transactions
///    - Fields: isDeleted (ASCENDING), createdAt (DESCENDING)
///    - Query: where('isDeleted', isEqualTo: false).orderBy('createdAt', descending: true)
///
/// 2. sync_queue (if using Firestore for queue):
///    - Collection: bengkel/{bengkelId}/sync_queue
///    - Fields: status (ASCENDING), priority (ASCENDING), createdAt (ASCENDING)
///    - Query: where('status', isEqualTo: 'pending').orderBy('priority').orderBy('createdAt')
///
/// To deploy indexes:
/// 1. Run `firebase init firestore` to generate firestore.indexes.json
/// 2. Or manually create in Firebase Console:
///    - Go to Firestore → Indexes → Composite
///    - Add the above combinations
///
/// Example firestore.indexes.json:
/// ```json
/// {
///   "indexes": [
///     {
///       "collectionGroup": "transactions",
///       "queryScope": "COLLECTION",
///       "fields": [
///         { "fieldPath": "isDeleted", "order": "ASCENDING" },
///         { "fieldPath": "createdAt", "order": "DESCENDING" }
///       ]
///     }
///   ]
/// }
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/transaction.dart' as entity;
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/stok_history.dart';
import '../../domain/entities/service_master.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/expense.dart';
import '../sync/sync_telemetry.dart';
import '../utils/app_logger.dart';
import 'encryption_service.dart';

import 'session_manager.dart';

/// Full-featured Firestore sync service for CRUD operations with collision handling.
class FirestoreSyncService {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryption;
  final SessionManager? _sessionManager;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    EncryptionService? encryption,
    SessionManager? sessionManager,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryption = encryption!,
        _sessionManager = sessionManager;

  // ===== PATH HELPERS (TAHAP 3.2) =====

  /// Reference ke dokumen workshop aktif
  /// Prioritas: Nested path (users/{ownerId}/workshops/{workshopId})
  /// Fallback: Legacy path (bengkel/{workshopId}) jika ownerId tidak tersedia
  DocumentReference<Map<String, dynamic>> _workshopDoc({String? workshopId}) {
    final ownerId = _sessionManager?.activeWorkshopOwnerId;
    final effectiveWorkshopId = workshopId ?? _sessionManager?.activeWorkshopId;

    // Jika ownerId tidak tersedia, gunakan legacy path
    if (ownerId == null || ownerId.isEmpty) {
      if (effectiveWorkshopId == null || effectiveWorkshopId.isEmpty) {
        throw StateError('FirestoreSyncService: workshopId belum tersedia');
      }
      appLogger.info(
        'Using legacy path for workshop: $effectiveWorkshopId (ownerId not available)',
        context: 'FirestoreSyncService',
      );
      return _legacyWorkshopDoc(effectiveWorkshopId);
    }

    if (effectiveWorkshopId == null) {
      throw StateError('FirestoreSyncService: workshopId belum tersedia');
    }

    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('workshops')
        .doc(effectiveWorkshopId);
  }

  /// Map internal key to its respective decryptor.
  Map<String, dynamic> Function(Map<String, dynamic>) _getDecryptorForKey(String key) {
    switch (key) {
      case 'transactions': return decryptTransaction;
      case 'customers': return decryptCustomer;
      case 'staff': return decryptStaff;
      case 'vehicles': return decryptVehicle;
      case 'sales': return decryptSale;
      case 'service_master': return decryptServiceMaster;
      default: return (d) => d; // No decryption for others
    }
  }

  /// Reference ke koleksi dalam workshop aktif
  CollectionReference<Map<String, dynamic>> _workshopCollection(String name, {String? workshopId}) {
    // TAHAP 3.2 FIX: Gunakan mapping nama koleksi yang peka terhadap jalur (Legacy vs Nested)
    final ownerId = _sessionManager?.activeWorkshopOwnerId;
    final isLegacy = ownerId == null || ownerId.isEmpty;
    return _workshopDoc(workshopId: workshopId).collection(_mapInternalToActualName(name, isLegacy: isLegacy));
  }

  /// Map internal keys to actual Firestore collection names.
  /// Memastikan konsistensi antara nama di kode (English) dan di DB (Indonesian/English mix).
  String _mapInternalToActualName(String key, {bool isLegacy = false}) {
    if (isLegacy) {
      const mapping = {
        'transactions': 'transaksi',
        'customers': 'pelanggan',
        'inventory': 'stok',
        'staff': 'staf',
        'vehicles': 'kendaraan',
        'sales': 'penjualan',
        'expenses': 'pengeluaran',
      };
      return mapping[key] ?? key;
    }
    // Nested path defaults to English as per user structure
    return key;
  }

  /// Returns possible collection names for a given internal key.
  /// Used for discovery during restoration.
  List<String> _getCollectionCandidates(String key) {
    switch (key) {
      case 'transactions': return ['transactions', 'transaksi'];
      case 'customers': return ['customers', 'pelanggan'];
      case 'inventory': return ['inventory', 'stok'];
      case 'staff': return ['staff', 'staf'];
      case 'vehicles': return ['vehicles', 'kendaraan'];
      case 'sales': return ['sales', 'penjualan'];
      case 'expenses': return ['expenses', 'pengeluaran'];
      case 'inventory_history': return ['inventory_history', 'stok_history'];
      case 'service_master': return ['service_master'];
      default: return [key];
    }
  }

  DocumentReference<Map<String, dynamic>> _legacyWorkshopDoc(String workshopId) {
    return _firestore.collection('bengkel').doc(workshopId);
  }

  // ===== IDEMPOTENCY HELPERS =====

  /// Generate a unique key for the entity version.
  String _getIdempotencyKey(dynamic entity) {
    // some entities might not have updatedAt yet or it's null
    final ts = entity.updatedAt?.millisecondsSinceEpoch ?? 
               entity.createdAt?.millisecondsSinceEpoch ?? 0;
    return "${entity.uuid}_$ts";
  }

  /// Check if an operation is already completed in Firestore.
  Future<bool> _isAlreadyCompleted(String workshopId, String key) async {
    try {
      final doc = await _workshopCollection('_operations', workshopId: workshopId)
          .doc(key)
          .get();
      return doc.exists && doc.data()?['status'] == 'completed';
    } catch (e) {
      return false;
    }
  }

  /// Mark the operation as completed in the given batch.
  void _markCompleted(WriteBatch batch, String workshopId, String key) {
    final ref = _workshopCollection('_operations', workshopId: workshopId).doc(key);
    batch.set(ref, {
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== TRANSACTIONS =====

  /// Push a Transaction to Firestore under /bengkel/{id}/transactions/{uuid}.
  /// Also pushes all TransactionItems as a sub-collection for full recovery.
  Future<void> pushTransaction(String bengkelId, entity.Transaction tx) async {
    final key = _getIdempotencyKey(tx);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    
    final txRef = _workshopCollection('transactions', workshopId: bengkelId).doc(tx.uuid);

    batch.set(txRef, {
      'uuid': tx.uuid,
      'bengkelId': bengkelId,
      'trxNumber': tx.trxNumber,
      'customerName': _encryption.encryptText(tx.customerName),
      'customerPhone': _encryption.encryptText(tx.customerPhone),
      'vehicleModel': tx.vehicleModel,
      'vehiclePlate': tx.vehiclePlate,
      'totalAmount': tx.totalAmount,
      'partsCost': tx.partsCost,
      'laborCost': tx.laborCost,
      'totalRevenue': tx.totalRevenue,
      'totalHpp': tx.totalHpp,
      'totalMechanicBonus': tx.totalMechanicBonus,
      'totalProfit': tx.totalProfit,
      'status': tx.status,
      'statusValue': tx.statusValue,
      'paymentMethod': tx.paymentMethod,
      'complaint': _encryption.encryptText(tx.complaint ?? ''),
      'mechanicNotes': _encryption.encryptText(tx.mechanicNotes ?? ''),
      'mechanicName': tx.mechanicName,
      'notes': _encryption.encryptText(tx.notes ?? ''),
      'odometer': tx.odometer,
      'recommendationTimeMonth': tx.recommendationTimeMonth,
      'recommendationKm': tx.recommendationKm,
      'photoCloudUrl': tx.photoCloudUrl,
      'isDeleted': tx.isDeleted,
      'deletedBy': tx.deletedBy,
      'deletedAt': tx.deletedAt != null
          ? Timestamp.fromDate(tx.deletedAt!)
          : null,
      'createdAt': Timestamp.fromDate(tx.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'startTime': tx.startTime != null
          ? Timestamp.fromDate(tx.startTime!)
          : null,
      'endTime':
          tx.endTime != null ? Timestamp.fromDate(tx.endTime!) : null,
      'lastReminderSentAt': tx.lastReminderSentAt != null
          ? Timestamp.fromDate(tx.lastReminderSentAt!)
          : null,
      'customerUuid': tx.pelanggan.target?.uuid,
      'vehicleUuid': tx.vehicle.target?.uuid,
      'mechanicUuid': tx.mechanic.target?.uuid,
      'syncStatus': 2, // synced
    }, SetOptions(merge: true));

    // Push Items as sub-collection
    for (var item in tx.items) {
      final itemRef = txRef.collection('items').doc(item.uuid);
      batch.set(itemRef, {
        'uuid': item.uuid,
        'name': _encryption.encryptText(item.name),
        'price': item.price,
        'costPrice': item.costPrice,
        'quantity': item.quantity,
        'subtotal': item.subtotal,
        'isDeleted': item.isDeleted,
        'isService': item.isService,
        'notes': _encryption.encryptText(item.notes ?? ''),
        'mechanicBonus': item.mechanicBonus,
        'createdAt': Timestamp.fromDate(item.createdAt),
        'updatedAt': Timestamp.fromDate(item.updatedAt),
      }, SetOptions(merge: true));
    }

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  /// Pull a single Transaction from Firestore.
  Future<Map<String, dynamic>?> pullTransaction(
      String workshopId, String uuid) async {
    final doc = await _workshopCollection('transactions', workshopId: workshopId)
        .doc(uuid)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  /// Listen to real-time transaction changes for a bengkel.
  Stream<List<Map<String, dynamic>>> listenTransactions(String workshopId) {
    return _workshopCollection('transactions', workshopId: workshopId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ===== CUSTOMERS =====

  /// Push a Pelanggan to Firestore.
  Future<void> pushPelanggan(String bengkelId, Pelanggan p) async {
    final key = _getIdempotencyKey(p);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('customers', workshopId: bengkelId).doc(p.uuid);

    batch.set(ref, {
      'uuid': p.uuid,
      'bengkelId': bengkelId, 
      'name': _encryption.encryptText(p.nama),
      'phone': _encryption.encryptText(p.telepon),
      'address': _encryption.encryptText(p.alamat),
      'createdAt': Timestamp.fromDate(p.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== INVENTORY =====

  /// Push a Stok item to Firestore.
  Future<void> pushStok(String bengkelId, Stok s) async {
    final key = _getIdempotencyKey(s);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('inventory', workshopId: bengkelId).doc(s.uuid);

    batch.set(ref, {
      'uuid': s.uuid,
      'bengkelId': bengkelId, 
      'nama': s.nama,
      'kategori': s.kategori,
      'hargaBeli': s.hargaBeli,
      'hargaJual': s.hargaJual,
      'jumlah': s.jumlah,
      'minStok': s.minStok,
      'unit': 'Unit',
      'createdAt': Timestamp.fromDate(s.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== STAFF =====

  /// Push a Staff record to Firestore.
  Future<void> pushStaff(String bengkelId, Staff s) async {
    final key = _getIdempotencyKey(s);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('staff', workshopId: bengkelId).doc(s.uuid);

    batch.set(ref, {
      'uuid': s.uuid,
      'bengkelId': bengkelId, 
      'name': _encryption.encryptText(s.name),
      'phone': _encryption.encryptText(s.phoneNumber ?? ''),
      'role': s.role,
      'createdAt': Timestamp.fromDate(s.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== VEHICLES =====

  /// Push a Vehicle record to Firestore.
  Future<void> pushVehicle(String bengkelId, Vehicle v) async {
    final key = _getIdempotencyKey(v);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('vehicles', workshopId: bengkelId).doc(v.uuid);

    batch.set(ref, {
      'uuid': v.uuid,
      'bengkelId': bengkelId, 
      'model': v.model,
      'type': v.type,
      'plate': v.plate,
      'year': v.year,
      'vin': _encryption.encryptText(v.vin ?? ''),
      'ownerUuid': v.owner.target?.uuid,
      'isDeleted': v.isDeleted,
      'createdAt': Timestamp.fromDate(v.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== STOK HISTORY =====

  /// Push a StokHistory record to Firestore.
  Future<void> pushStokHistory(String bengkelId, StokHistory sh) async {
    final key = _getIdempotencyKey(sh);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('inventory_history', workshopId: bengkelId).doc(sh.uuid);

    batch.set(ref, {
      'uuid': sh.uuid,
      'bengkelId': bengkelId,
      'stokUuid': sh.stokUuid,
      'type': sh.type,
      'quantityChange': sh.quantityChange,
      'previousQuantity': sh.previousQuantity,
      'newQuantity': sh.newQuantity,
      'createdAt': Timestamp.fromDate(sh.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== SERVICE MASTER =====

  Future<void> pushServiceMaster(String bengkelId, ServiceMaster sm) async {
    final key = _getIdempotencyKey(sm);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('service_master', workshopId: bengkelId).doc(sm.uuid);

    batch.set(ref, {
      'uuid': sm.uuid,
      'name': _encryption.encryptText(sm.name),
      'basePrice': sm.basePrice,
      'category': sm.category,
      'createdAt': Timestamp.fromDate(sm.createdAt),
      'isDeleted': sm.isDeleted,
      'bengkelId': bengkelId,
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== SALES =====

  Future<void> pushSale(String bengkelId, Sale s) async {
    final key = _getIdempotencyKey(s);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('sales', workshopId: bengkelId).doc(s.uuid);

    batch.set(ref, {
      'uuid': s.uuid,
      'itemName': s.itemName,
      'quantity': s.quantity,
      'totalPrice': s.totalPrice,
      'costPrice': s.costPrice,
      'totalProfit': s.totalProfit,
      'stokUuid': s.stokUuid,
      'customerName': _encryption.encryptText(s.customerName ?? ''),
      'paymentMethod': s.paymentMethod,
      'transactionId': s.transactionId,
      'trxNumber': s.trxNumber,
      'createdAt': Timestamp.fromDate(s.createdAt),
      'updatedAt': Timestamp.fromDate(s.updatedAt ?? s.createdAt),
      'isDeleted': s.isDeleted,
      'bengkelId': bengkelId,
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== EXPENSES =====

  Future<void> pushExpense(String bengkelId, Expense e) async {
    final key = _getIdempotencyKey(e);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _workshopCollection('expenses', workshopId: bengkelId).doc(e.uuid);

    batch.set(ref, {
      'uuid': e.uuid,
      'bengkelId': bengkelId,
      'amount': e.amount,
      'category': e.category,
      'description': e.description,
      'date': Timestamp.fromDate(e.date),
      'photoPath': e.photoPath,
      'isDeleted': e.isDeleted,
      'debtStatus': e.debtStatus,
      'supplierName': e.supplierName,
      'parentExpenseUuid': e.parentExpense.target?.uuid,
      'createdAt': Timestamp.fromDate(e.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== COLLISION RESOLUTION =====

  /// Merge local and remote data — remote wins if updatedAt is newer.
  Map<String, dynamic> mergeData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localUpdated = (local['updatedAt'] as Timestamp?)?.toDate();
    final remoteUpdated = (remote['updatedAt'] as Timestamp?)?.toDate();

    if (localUpdated == null) return remote;
    if (remoteUpdated == null) return local;

    // Remote is newer → use remote
    if (remoteUpdated.isAfter(localUpdated)) {
      return remote;
    }
    // Local is newer → use local
    return local;
  }

  static const int _batchSize = 200;

  Future<List<Map<String, dynamic>>> _pullCollectionWithPagination(
    CollectionReference queryRoot,
    String collectionName,
    Map<String, dynamic> Function(Map<String, dynamic>) mapper, {
    int limit = _batchSize,
    bool decryptItems = false,
  }) async {
    final List<Map<String, dynamic>> allData = [];
    Query query = queryRoot;

    // FIX: Hanya filter isDeleted jika collection memang mendukungnya
    // dan jangan filter untuk collection yang mungkin belum memiliki field ini
    if (collectionName == 'transactions') {
      // Gunakan filter yang lebih longgar - hanya filter jika field ada
      query = query.where('isDeleted', isEqualTo: false);
    }

    query = query.limit(limit);
    DocumentSnapshot? lastDocument;
    bool hasMore = true;

    appLogger.info(
      '=== _pullCollectionWithPagination START ===\n'
      '  Collection: $collectionName\n'
      '  Path: ${queryRoot.path}',
      context: 'FirestoreSyncService',
    );

    try {
      while (hasMore) {
        Query currentQuery = query;
        if (lastDocument != null) {
          currentQuery = currentQuery.startAfterDocument(lastDocument);
        }

        final snapshot = await currentQuery.get();
        
        appLogger.info(
          'Collection $collectionName: fetched ${snapshot.docs.length} documents',
          context: 'FirestoreSyncService',
        );

        if (collectionName == 'expenses') {
          appLogger.info('RAW EXPENSES PAYLOAD: ${snapshot.docs.length} documents retrieved from Firestore.', context: 'FirestoreSyncService');
        }
        
        if (snapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        lastDocument = snapshot.docs.last;

        if (decryptItems && collectionName == 'transactions') {
          final failedItems = <String, dynamic>{};
          final List<Map<String, dynamic>> currentBatch = [];

          // FIX: Process in small chunks to avoid overwhelming the system (and avoid freezes)
          const chunkSize = 15;
          for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
            final end = (i + chunkSize < snapshot.docs.length) ? i + chunkSize : snapshot.docs.length;
            final chunk = snapshot.docs.sublist(i, end);
            final List<Future<void>> chunkFetchers = [];

            for (var doc in chunk) {
              final data = doc.data() as Map<String, dynamic>;
              final mappedData = mapper(data);
              final List<Map<String, dynamic>> items = [];
              mappedData['items'] = items;
              currentBatch.add(mappedData);

              chunkFetchers.add(
                doc.reference.collection('items').get().then((itemSnap) {
                  for (var itemDoc in itemSnap.docs) {
                    try {
                      final itemData = itemDoc.data();
                      items.add(decryptTransactionItem(itemData));
                    } catch (e) {
                      failedItems[doc.id] = e;
                    }
                  }
                }).catchError((e) {
                  failedItems[doc.id] = e;
                })
              );
            }
            
            if (chunkFetchers.isNotEmpty) {
              await Future.wait(chunkFetchers, eagerError: false);
            }
          }
          
          if (failedItems.isNotEmpty) {
            appLogger.warning('Failed to fetch items for ${failedItems.length} transactions', context: 'FirestoreSyncService');
            SyncTelemetry().log(SyncEvent(
              type: 'partial_sync_failure',
              metadata: {'failedCount': failedItems.length},
              level: TelemetryLevel.warning,
              timestamp: DateTime.now(),
            ));
          }
          allData.addAll(currentBatch);
        } else {
          allData.addAll(snapshot.docs.map((doc) => mapper(doc.data() as Map<String, dynamic>)));
        }

        if (snapshot.docs.length < limit) {
          hasMore = false;
        }
      }
    } catch (e) {
      appLogger.error(
        'Error pulling collection $collectionName from ${queryRoot.path}',
        error: e,
      );
      rethrow;
    }

    appLogger.info(
      '=== _pullCollectionWithPagination END ===\n'
      '  Collection: $collectionName\n'
      '  Total documents: ${allData.length}',
      context: 'FirestoreSyncService',
    );

    return allData;
  }

  // ===== BULK OPERATIONS =====

  /// Initial sync — pull all data for a bengkel with pagination and chunking (used after first login).
  /// FIX: Mendukung fallback ke legacy path jika ownerId tidak tersedia
  Future<Map<String, List<Map<String, dynamic>>>> pullAllData(
      String bengkelId) async {
    appLogger.info('=== pullAllData STARTED ===', context: 'FirestoreSyncService');
    appLogger.info('Input bengkelId: $bengkelId', context: 'FirestoreSyncService');
    
    final activeWsId = _sessionManager?.activeWorkshopId ?? bengkelId;
    final ownerId = _sessionManager?.activeWorkshopOwnerId;
    
    appLogger.info(
      'SessionManager state: activeWorkshopId=$activeWsId, ownerId=$ownerId',
      context: 'FirestoreSyncService',
    );
    
    // FIX: Jika ownerId null, gunakan legacy path sebagai fallback
    final useLegacyPath = ownerId == null || ownerId.isEmpty;
    
    if (activeWsId.isEmpty) {
      throw StateError(
        'pullAllData: workshopId belum tersedia. '
        'Pastikan bengkelId valid atau SessionManager sudah diinisialisasi.',
      );
    }

    // Log warning jika menggunakan legacy path
    if (useLegacyPath) {
      appLogger.warning(
        'pullAllData: ownerId tidak tersedia, menggunakan legacy path: bengkel/$activeWsId',
        context: 'FirestoreSyncService',
      );
    } else {
      appLogger.info('Pulling all data for path: users/$ownerId/workshops/$activeWsId', context: 'FirestoreSyncService');
    }
    
    try {
      final results = <String, List<Map<String, dynamic>>>{};

      // 1. Discovery: Check primary nested location first (hanya jika ownerId tersedia)
      bool useLegacyFallback = useLegacyPath;
      DocumentReference<Map<String, dynamic>>? primaryRoot;
      DocumentReference<Map<String, dynamic>> legacyRoot = _legacyWorkshopDoc(activeWsId);
      
      appLogger.info('Discovery phase: checking paths...', context: 'FirestoreSyncService');
      
      if (!useLegacyPath) {
        try {
          primaryRoot = _workshopDoc();
          appLogger.info('Checking primary path: ${primaryRoot.path}', context: 'FirestoreSyncService');
          final doc = await primaryRoot.get();
          
          if (!doc.exists) {
            appLogger.info('Primary workshop doc missing, checking legacy path...', context: 'FirestoreSyncService');
            final legacyDoc = await legacyRoot.get();
            if (legacyDoc.exists) {
              useLegacyFallback = true;
              appLogger.info('Legacy workshop data detected for ID: $activeWsId', context: 'FirestoreSyncService');
            }
          } else {
            // LGK-06 FIX: Cek beberapa sub-koleksi, bukan hanya transactions.
            // Bengkel baru mungkin belum punya transaksi tapi sudah punya
            // pelanggan, staff, atau inventory.
            final discoveryCollections = ['transactions', 'customers', 'staff', 'inventory'];
            bool primaryHasData = false;

            for (final col in discoveryCollections) {
              final snap = await primaryRoot.collection(col).limit(1).get();
              if (snap.docs.isNotEmpty) {
                primaryHasData = true;
                appLogger.info('Primary path has data in "$col"', context: 'FirestoreSyncService');
                break;
              }
            }

            if (!primaryHasData) {
              appLogger.info('Primary path empty across all collections, checking legacy...', context: 'FirestoreSyncService');
              for (final col in discoveryCollections) {
                final snap = await legacyRoot.collection(col).limit(1).get();
                if (snap.docs.isNotEmpty) {
                  useLegacyFallback = true;
                  appLogger.info('Data found in legacy path "$col", using legacy for restore', context: 'FirestoreSyncService');
                  break;
                }
              }
            }
          }
        } catch (e) {
          appLogger.warning('Discovery phase error, defaulting to legacy path', error: e);
          useLegacyFallback = true;
        }
      } else {
        // Check if legacy path has data
        appLogger.info('Checking legacy path: ${legacyRoot.path}', context: 'FirestoreSyncService');
        final legacyDoc = await legacyRoot.get();
        appLogger.info('Legacy doc exists: ${legacyDoc.exists}', context: 'FirestoreSyncService');
      }

      // Gunakan legacy root jika ownerId null atau discovery menemukan data legacy
      final effectiveRoot = useLegacyFallback ? legacyRoot : (primaryRoot ?? _workshopDoc());
      
      appLogger.info(
        '=== USING PATH FOR RESTORE: ${effectiveRoot.path} ===',
        context: 'FirestoreSyncService',
      );

      // 2. Process each collection with name discovery
      appLogger.info('Starting to pull collections with name discovery...', context: 'FirestoreSyncService');
      
      final keysToPull = [
        'transactions', 'customers', 'inventory', 'staff', 
        'vehicles', 'inventory_history', 'service_master', 'sales', 'expenses'
      ];

      for (final key in keysToPull) {
        final candidates = _getCollectionCandidates(key);
        appLogger.info('Discovery for $key: candidates=$candidates', context: 'FirestoreSyncService');
        
        for (final colName in candidates) {
          final decryptor = _getDecryptorForKey(key);
          final hasItems = key == 'transactions';
          final colRef = effectiveRoot.collection(colName);

          final data = await _pullCollectionWithPagination(
            colRef, 
            key, 
            decryptor, 
            decryptItems: hasItems
          );

          if (data.isNotEmpty) {
            appLogger.info('Found data in $colName for $key (${data.length} docs)', context: 'FirestoreSyncService');
            results[key] = data;
            break; // Stop discovery for this key
          }
        }
        
        // Ensure result key exists even if empty
        results[key] ??= [];
      }

      appLogger.info(
        '=== pullAllData COMPLETE ===\n'
        '  transactions=${results['transactions']?.length ?? 0}\n'
        '  customers=${results['customers']?.length ?? 0}\n'
        '  inventory=${results['inventory']?.length ?? 0}\n'
        '  staff=${results['staff']?.length ?? 0}\n'
        '  vehicles=${results['vehicles']?.length ?? 0}\n'
        '  inventory_history=${results['inventory_history']?.length ?? 0}\n'
        '  service_master=${results['service_master']?.length ?? 0}\n'
        '  sales=${results['sales']?.length ?? 0}\n'
        '  expenses=${results['expenses']?.length ?? 0}',
        context: 'FirestoreSyncService',
      );

      return results;
    } catch (e) {
      appLogger.error('Pull All Data Error', error: e);
      rethrow;
    }
  }

  // ===== MASTER KEY SYNC =====

  /// Store the wrapped master key in Firestore for other devices to sync.
  Future<void> uploadMasterKey(String workshopId, String wrappedKey) async {
    final secretRef = _workshopCollection('secrets', workshopId: workshopId).doc('masterKey');
    
    await secretRef.set({
      'value': wrappedKey,
      'updatedAt': FieldValue.serverTimestamp(),
      'version': 'v1',
    });

    // Record audit event
    SyncTelemetry().log(SyncEvent(
      type: 'security_key_uploaded',
      metadata: {'workshopId': _sessionManager?.activeWorkshopId},
      level: TelemetryLevel.warning,
      timestamp: DateTime.now(),
    ));
  }

  /// Download the wrapped master key from Firestore.
  Future<String?> downloadMasterKey(String workshopId) async {
    final bengkelRef = _workshopDoc(workshopId: workshopId);
    
    // 1. Try new location first
    final secretDoc = await _workshopCollection('secrets', workshopId: workshopId).doc('masterKey').get();
    if (secretDoc.exists) {
      // Record audit event for access
      SyncTelemetry().log(SyncEvent(
        type: 'security_key_downloaded',
        metadata: {'workshopId': _sessionManager?.activeWorkshopId, 'source': 'secrets_sub'},
        level: TelemetryLevel.info,
        timestamp: DateTime.now(),
      ));
      return secretDoc.data()?['value'] as String?;
    }

    // 2. Fallback to nested root (if key moved but doc moved too)
    final doc = await bengkelRef.get();
    if (doc.exists) {
      final nestedLegacyKey = doc.data()?['masterKey'] as String?;
      if (nestedLegacyKey != null) return nestedLegacyKey;
    }
    
    // 3. Final Fallback: Check top-level registry doc (Legacy Phase 2)
    final legacyDoc = await _legacyWorkshopDoc(_sessionManager?.activeWorkshopId ?? '').get();
    if (legacyDoc.exists) {
      final legacyKey = legacyDoc.data()?['masterKey'] as String? 
          ?? legacyDoc.data()?['master_key'] as String?; // check both formats
      if (legacyKey != null) {
        SyncTelemetry().log(SyncEvent(
          type: 'security_key_downloaded',
          metadata: {'workshopId': _sessionManager?.activeWorkshopId, 'source': 'legacy_registry'},
          level: TelemetryLevel.info,
          timestamp: DateTime.now(),
        ));
        return legacyKey;
      }
    }

    return null;
  }

  // ===== DECRYPTION HELPERS =====

  /// Decrypt a transaction map from Firestore.
  Map<String, dynamic> decryptTransaction(Map<String, dynamic> data) {
    return {
      ...data,
      'customerName': _encryption.decryptText(data['customerName'] ?? '').displayValue,
      'customerPhone': _encryption.decryptText(data['customerPhone'] ?? '').displayValue,
      'complaint': _encryption.decryptText(data['complaint'] ?? '').displayValue,
      'mechanicNotes': _encryption.decryptText(data['mechanicNotes'] ?? '').displayValue,
      'notes': _encryption.decryptText(data['notes'] ?? '').displayValue,
    };
  }

  /// Decrypt a transaction item map from Firestore.
  Map<String, dynamic> decryptTransactionItem(Map<String, dynamic> data) {
    return {
      ...data,
      'name': _encryption.decryptText(data['name'] ?? '').displayValue,
      'notes': _encryption.decryptText(data['notes'] ?? '').displayValue,
    };
  }

  /// Decrypt a customer map from Firestore.
  Map<String, dynamic> decryptCustomer(Map<String, dynamic> data) {
    return {
      ...data,
      'name': _encryption.decryptText(data['name'] ?? '').displayValue,
      'phone': _encryption.decryptText(data['phone'] ?? '').displayValue,
      'address': _encryption.decryptText(data['address'] ?? '').displayValue,
    };
  }

  /// Decrypt a staff map from Firestore.
  Map<String, dynamic> decryptStaff(Map<String, dynamic> data) {
    return {
      ...data,
      'name': _encryption.decryptText(data['name'] ?? '').displayValue,
      'phone': _encryption.decryptText(data['phone'] ?? '').displayValue,
    };
  }

  /// Decrypt a vehicle map from Firestore.
  Map<String, dynamic> decryptVehicle(Map<String, dynamic> data) {
    return {
      ...data,
      'vin': _encryption.decryptText(data['vin'] ?? '').displayValue,
    };
  }

  /// Decrypt a sale map from Firestore.
  Map<String, dynamic> decryptSale(Map<String, dynamic> data) {
    return {
      ...data,
      'customerName': _encryption.decryptText(data['customerName'] ?? '').displayValue,
    };
  }

  /// Decrypt a service master map from Firestore.
  Map<String, dynamic> decryptServiceMaster(Map<String, dynamic> data) {
    return {
      ...data,
      'name': _encryption.decryptText(data['name'] ?? '').displayValue,
    };
  }
}



