import '../../domain/entities/transaction.dart';
import 'sync_service.dart';

class LocalSyncService implements SyncService {
  @override
  Future<void> syncAll() async {
    // STEP 3: No-Op (Hanya lokal)
    // Silently skip sync in local mode to avoid terminal noise
  }

  @override
  Future<void> uploadTransaction(Transaction transaction) async {
    // STEP 3: Menandai sebagai lokal saja
  }

  @override
  Future<void> deleteFromCloud(String uuid) async {
    // STEP 3: No-Op
  }

  @override
  Future<void> updateSyncStatus(String uuid, int status) async {
    // STEP 3: No-Op
  }
}

