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
import '../sync/sync_telemetry.dart';
import 'encryption_service.dart';

import '../utils/app_logger.dart';

/// Full-featured Firestore sync service for CRUD operations with collision handling.
class FirestoreSyncService {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryption;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    EncryptionService? encryption,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryption = encryption!;

  // ===== IDEMPOTENCY HELPERS =====

  /// Generate a unique key for the entity version.
  String _getIdempotencyKey(dynamic entity) {
    // some entities might not have updatedAt yet or it's null
    final ts = entity.updatedAt?.millisecondsSinceEpoch ?? 0;
    return "${entity.uuid}_$ts";
  }

  /// Check if an operation is already completed in Firestore.
  Future<bool> _isAlreadyCompleted(String bengkelId, String key) async {
    try {
      final doc = await _firestore
          .collection('bengkel')
          .doc(bengkelId)
          .collection('_operations')
          .doc(key)
          .get();
      return doc.exists && doc.data()?['status'] == 'completed';
    } catch (e) {
      return false;
    }
  }

  /// Mark the operation as completed in the given batch.
  void _markCompleted(WriteBatch batch, String bengkelId, String key) {
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('_operations')
        .doc(key);
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
    
    final txRef = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('transactions')
        .doc(tx.uuid);

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
      String bengkelId, String uuid) async {
    final doc = await _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('transactions')
        .doc(uuid)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  /// Listen to real-time transaction changes for a bengkel.
  Stream<List<Map<String, dynamic>>> listenTransactions(String bengkelId) {
    return _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('transactions')
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
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('customers')
        .doc(p.uuid);

    batch.set(ref, {
      'uuid': p.uuid,
      'bengkelId': bengkelId, // Add this
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
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('inventory')
        .doc(s.uuid);

    batch.set(ref, {
      'uuid': s.uuid,
      'bengkelId': bengkelId, // Add this
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
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('staff')
        .doc(s.uuid);

    batch.set(ref, {
      'uuid': s.uuid,
      'bengkelId': bengkelId, // Add this
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
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('vehicles')
        .doc(v.uuid);

    batch.set(ref, {
      'uuid': v.uuid,
      'bengkelId': bengkelId, // Add this
      'model': v.model,
      'type': v.type,
      'plate': v.plate,
      'color': v.color,
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

  // ===== STOCK HISTORY =====

  /// Push a StokHistory record to Firestore.
  Future<void> pushStokHistory(String bengkelId, StokHistory sh) async {
    final key = _getIdempotencyKey(sh);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('inventory_history')
        .doc(sh.uuid);

    batch.set(ref, {
      'uuid': sh.uuid,
      'bengkelId': bengkelId,
      'stokUuid': sh.stokUuid,
      'type': sh.type,
      'quantityChange': sh.quantityChange,
      'previousQuantity': sh.previousQuantity,
      'newQuantity': sh.newQuantity,
      'note': sh.note,
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
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('service_master')
        .doc(sm.uuid);

    batch.set(ref, {
      'uuid': sm.uuid,
      'name': _encryption.encryptText(sm.name), // ← FIX: enkripsi name
      'basePrice': sm.basePrice,
      'category': sm.category,
      'createdAt': Timestamp.fromDate(sm.createdAt), // ← FIX: pake Timestamp
      'updatedAt': Timestamp.fromDate(sm.updatedAt), // ← FIX: pake Timestamp
      'isDeleted': sm.isDeleted,
      'bengkelId': bengkelId,
    }, SetOptions(merge: true));

    _markCompleted(batch, bengkelId, key);
    await batch.commit();
  }

  // ===== SALE =====

  Future<void> pushSale(String bengkelId, Sale s) async {
    final key = _getIdempotencyKey(s);
    if (await _isAlreadyCompleted(bengkelId, key)) return;

    final batch = _firestore.batch();
    final ref = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('sales')
        .doc(s.uuid);

    batch.set(ref, {
      'uuid': s.uuid,
      'trxNumber': s.trxNumber,
      'itemName': s.itemName,
      'quantity': s.quantity,
      'totalPrice': s.totalPrice,
      'costPrice': s.costPrice,
      'totalProfit': s.totalProfit,
      'paymentMethod': s.paymentMethod,
      'customerName': _encryption.encryptText(s.customerName ?? ''),
      'stokUuid': s.stokUuid,
      'transactionId': s.transactionId,
      'createdAt': Timestamp.fromDate(s.createdAt), // ← FIX: Timestamp
      'updatedAt': Timestamp.fromDate(s.updatedAt ?? s.createdAt), // ← FIX
      'isDeleted': s.isDeleted,
      'bengkelId': bengkelId,
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
    String bengkelId,
    String collectionName,
    Map<String, dynamic> Function(Map<String, dynamic>) mapper, {
    int limit = _batchSize,
    bool decryptItems = false,
  }) async {
    final List<Map<String, dynamic>> allData = [];
    Query query = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection(collectionName);

    if (collectionName == 'transactions') {
      query = query.where('isDeleted', isEqualTo: false);
    }

    query = query.limit(limit);
    DocumentSnapshot? lastDocument;
    bool hasMore = true;

    while (hasMore) {
      Query currentQuery = query;
      if (lastDocument != null) {
        currentQuery = currentQuery.startAfterDocument(lastDocument);
      }

      final snapshot = await currentQuery.get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }

      lastDocument = snapshot.docs.last;

      if (decryptItems && collectionName == 'transactions') {
        final List<Future<void>> itemFetchers = [];
        final failedItems = <String, dynamic>{};
        final List<Map<String, dynamic>> currentBatch = [];

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final mappedData = mapper(data);
          final List<Map<String, dynamic>> items = [];
          mappedData['items'] = items;
          currentBatch.add(mappedData);

          itemFetchers.add(
            doc.reference.collection('items').get().then((itemSnap) {
              for (var itemDoc in itemSnap.docs) {
                try {
                  final itemData = itemDoc.data();
                  items.add(decryptTransactionItem(itemData));
                } catch (e) {
                  failedItems[doc.id] = e;
                  appLogger.error('Failed to decrypt item for ${doc.id}', error: e);
                }
              }
            }).catchError((e) {
              failedItems[doc.id] = e;
              appLogger.error('Failed to fetch items for ${doc.id}', error: e);
            })
          );
        }
        
        if (itemFetchers.isNotEmpty) {
          await Future.wait(itemFetchers, eagerError: false);
        }
        
        if (failedItems.isNotEmpty) {
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

    return allData;
  }

  // ===== BULK OPERATIONS =====

  /// Initial sync — pull all data for a bengkel with pagination and chunking (used after first login).
  Future<Map<String, List<Map<String, dynamic>>>> pullAllData(
      String bengkelId) async {
    try {
      final results = <String, List<Map<String, dynamic>>>{};

      // 1. Process each collection sequentially or concurrently
      final futures = [
        _pullCollectionWithPagination(bengkelId, 'transactions', decryptTransaction, decryptItems: true),
        _pullCollectionWithPagination(bengkelId, 'customers', decryptCustomer),
        _pullCollectionWithPagination(bengkelId, 'inventory', (d) => d), // Maps to 'Stok'
        _pullCollectionWithPagination(bengkelId, 'staff', decryptStaff),
        _pullCollectionWithPagination(bengkelId, 'vehicles', decryptVehicle),
        _pullCollectionWithPagination(bengkelId, 'inventory_history', (d) => d), // Maps to 'StokHistory'
        _pullCollectionWithPagination(bengkelId, 'service_master', decryptServiceMaster),
        _pullCollectionWithPagination(bengkelId, 'sales', decryptSale),
      ];

      final fetchedResults = await Future.wait(futures);

      results['transactions'] = fetchedResults[0];
      results['customers'] = fetchedResults[1];
      results['inventory'] = fetchedResults[2];
      results['staff'] = fetchedResults[3];
      results['vehicles'] = fetchedResults[4];
      results['stok_history'] = fetchedResults[5];
      results['service_master'] = fetchedResults[6];
      results['sales'] = fetchedResults[7];

      return results;
    } catch (e) {
      appLogger.error('Pull All Data Error', error: e);
      rethrow;
    }
  }

  // ===== MASTER KEY SYNC =====

  /// Store the wrapped master key in Firestore for other devices to sync.
  Future<void> uploadMasterKey(String bengkelId, String wrappedKey) async {
    final secretRef = _firestore.collection('bengkel').doc(bengkelId).collection('secrets').doc('masterKey');
    
    await secretRef.set({
      'value': wrappedKey,
      'updatedAt': FieldValue.serverTimestamp(),
      'version': 'v1',
    });

    // Record audit event
    SyncTelemetry().log(SyncEvent(
      type: 'security_key_uploaded',
      metadata: {'bengkelId': bengkelId},
      level: TelemetryLevel.warning,
      timestamp: DateTime.now(),
    ));
  }

  /// Download the wrapped master key from Firestore.
  Future<String?> downloadMasterKey(String bengkelId) async {
    final bengkelRef = _firestore.collection('bengkel').doc(bengkelId);
    
    // 1. Try new location first
    final secretDoc = await bengkelRef.collection('secrets').doc('masterKey').get();
    if (secretDoc.exists) {
      // Record audit event for access
      SyncTelemetry().log(SyncEvent(
        type: 'security_key_downloaded',
        metadata: {'bengkelId': bengkelId, 'source': 'secrets_sub'},
        level: TelemetryLevel.info,
        timestamp: DateTime.now(),
      ));
      return secretDoc.data()?['value'] as String?;
    }

    // 2. Fallback to legacy root location
    final doc = await bengkelRef.get();
    if (!doc.exists) return null;
    
    final legacyKey = doc.data()?['masterKey'] as String?;
    if (legacyKey != null) {
      SyncTelemetry().log(SyncEvent(
        type: 'security_key_downloaded',
        metadata: {'bengkelId': bengkelId, 'source': 'legacy_root'},
        level: TelemetryLevel.warning,
        timestamp: DateTime.now(),
      ));
    }
    return legacyKey;
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



