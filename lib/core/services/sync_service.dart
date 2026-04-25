import '../../domain/entities/transaction.dart';

abstract class SyncService {
  /// Melakukan sinkronisasi data dari lokal ke cloud dan sebaliknya.
  Future<void> syncAll();

  /// Mengunggah satu transaksi ke cloud.
  Future<void> uploadTransaction(Transaction transaction);

  /// Menghapus transaksi dari cloud.
  Future<void> deleteFromCloud(String uuid);

  /// Menandai status sinkronisasi di database lokal.
  Future<void> updateSyncStatus(String uuid, int status);
}

