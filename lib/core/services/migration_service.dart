import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';
import '../utils/app_logger.dart';

/// Checkpoint state untuk migrasi yang bisa di-resume.
class MigrationCheckpoint {
  final Set<String> completedCollections;
  final Map<String, int> processedCounts;

  const MigrationCheckpoint({
    this.completedCollections = const {},
    this.processedCounts = const {},
  });

  bool isCompleted(String collection) =>
      completedCollections.contains(collection);

  int processedCount(String collection) =>
      processedCounts[collection] ?? 0;
}

class MigrationService {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryption;

  MigrationService({
    FirebaseFirestore? firestore,
    EncryptionService? encryption,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryption = encryption ?? EncryptionService();

  /// Jalankan migrasi enkripsi untuk satu bengkel secara atomik dan resumable.
  /// Menggunakan checkpoint system sehingga migrasi yang terputus bisa dilanjutkan.
  Future<void> migrateToEncryption(String bengkelId) async {
    try {
      appLogger.info('Starting Atomic Migration for Bengkel: $bengkelId', context: 'MigrationService');

      final checkpoint = await _getCheckpoint(bengkelId);

      // 1. Migrate Customers
      await _migrateCollection(
        bengkelId: bengkelId,
        collection: 'customers',
        entityName: 'Customer',
        piiFields: ['name', 'phone', 'address'],
        checkpoint: checkpoint,
      );

      // 2. Migrate Transactions
      await _migrateCollection(
        bengkelId: bengkelId,
        collection: 'transactions',
        entityName: 'Transaction',
        piiFields: ['customerName', 'customerPhone', 'complaint', 'mechanicNotes', 'notes'],
        checkpoint: checkpoint,
      );

      // 3. Migrate Staff
      await _migrateCollection(
        bengkelId: bengkelId,
        collection: 'staff',
        entityName: 'Staff',
        piiFields: ['name', 'phone'],
        checkpoint: checkpoint,
      );

      // Mark entire migration as complete
      await _saveCheckpoint(bengkelId, completed: true);

      appLogger.info('Migration Completed Successfully for $bengkelId', context: 'MigrationService');
    } catch (e, stack) {
      appLogger.error('Migration Error', context: 'MigrationService', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Migrasi per koleksi secara recursive dengan batch writes.
  /// Hanya memuat max 500 docs per iterasi untuk menjaga memory tetap rendah.
  /// Skip jika collection sudah ditandai selesai di checkpoint.
  Future<void> _migrateCollection({
    required String bengkelId,
    required String collection,
    required String entityName,
    required List<String> piiFields,
    required MigrationCheckpoint checkpoint,
  }) async {
    // Skip jika collection ini sudah selesai di run sebelumnya
    if (checkpoint.isCompleted(collection)) {
      appLogger.info('Skipping $entityName (already completed in checkpoint)', context: 'MigrationService');
      return;
    }

    appLogger.info('Migrating $entityName...', context: 'MigrationService');

    // Fetch hanya docs yang belum di-encrypt, max 500 per iterasi
    final snapshot = await _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection(collection)
        .where('isEncrypted', isEqualTo: false)
        .limit(500)
        .get();

    if (snapshot.docs.isEmpty) {
      // Tidak ada lagi docs yang perlu dimigrasikan — tandai selesai
      await _saveCheckpoint(bengkelId, collection: collection, isCollectionCompleted: true);
      appLogger.info('$entityName migration complete (no unencrypted docs remaining)', context: 'MigrationService');
      return;
    }

    appLogger.info('Processing ${snapshot.docs.length} $entityName docs...', context: 'MigrationService');

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final updateData = <String, dynamic>{};

      for (var field in piiFields) {
        final rawVal = data[field]?.toString() ?? '';
        if (rawVal.isNotEmpty) {
          // Defensive: skip jika field sudah ter-encrypt (edge case)
          if (rawVal.startsWith(EncryptionService.encryptionPrefix)) continue;
          updateData[field] = _encryption.encryptText(rawVal);
        }
      }

      updateData['isEncrypted'] = true;
      updateData['migratedAt'] = FieldValue.serverTimestamp();
      batch.update(doc.reference, updateData);
    }

    await batch.commit();

    // Checkpoint setelah setiap batch berhasil
    await _saveCheckpoint(bengkelId, collection: collection, batchCount: snapshot.docs.length);

    // Recursive call untuk batch berikutnya
    await _migrateCollection(
      bengkelId: bengkelId,
      collection: collection,
      entityName: entityName,
      piiFields: piiFields,
      checkpoint: checkpoint,
    );
  }

  /// Baca checkpoint dari Firestore untuk menentukan progress migrasi sebelumnya.
  Future<MigrationCheckpoint> _getCheckpoint(String bengkelId) async {
    try {
      final doc = await _firestore
          .collection('bengkel')
          .doc(bengkelId)
          .collection('_internal')
          .doc('migration_status')
          .get();

      if (!doc.exists) return const MigrationCheckpoint();

      final data = doc.data()!;
      final completed = Set<String>.from(data['completedCollections'] ?? []);
      final counts = Map<String, int>.from(data['processedCounts'] ?? {});

      return MigrationCheckpoint(
        completedCollections: completed,
        processedCounts: counts,
      );
    } catch (e) {
      appLogger.warning('Failed to read migration checkpoint', context: 'MigrationService', error: e);
      return const MigrationCheckpoint();
    }
  }

  Future<void> _saveCheckpoint(
    String bengkelId, {
    String? collection,
    int? batchCount,
    bool isCollectionCompleted = false,
    bool completed = false,
  }) async {
    final docRef = _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .collection('_internal')
        .doc('migration_status');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (completed) {
      updates['fullyCompleted'] = true;
    }

    if (collection != null) {
      if (isCollectionCompleted) {
        updates['completedCollections'] = FieldValue.arrayUnion([collection]);
      }
      if (batchCount != null) {
        updates['processedCounts.$collection'] = FieldValue.increment(batchCount);
      }
    }

    await docRef.set(updates, SetOptions(merge: true));
  }
}
