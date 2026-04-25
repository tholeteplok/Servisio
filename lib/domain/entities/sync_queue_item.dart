import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

/// Priority levels for sync operations.
enum SyncPriority {
  critical(0), // Transaction baru, payment → sync ASAP
  normal(1), // Update stok, customer info
  background(2); // Analytics, logs

  final int code;
  const SyncPriority(this.code);
}

/// Sync status tracking.
enum SyncStatus {
  localOnly(0),
  syncing(1),
  synced(2),
  failed(3);

  final int code;
  const SyncStatus(this.code);

  static SyncStatus fromCode(int code) {
    return SyncStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SyncStatus.localOnly,
    );
  }
}

/// ObjectBox entity for the sync queue.
@Entity()
class SyncQueueItem {
  @Id()
  int id = 0;

  @Unique()
  String uuid;

  String entityType; // 'transaction', 'pelanggan', 'stok', 'staff'
  String entityUuid; // UUID of the entity to sync
  int priority; // 0: critical, 1: normal, 2: background
  DateTime createdAt;
  DateTime? syncedAt;
  DateTime? lastRetryAt;
  int retryCount;
  String status; // pending, syncing, synced, failed

  SyncQueueItem({
    String? uuid,
    required this.entityType,
    required this.entityUuid,
    required this.priority,
    DateTime? createdAt,
    this.lastRetryAt,
    this.retryCount = 0,
    this.status = 'pending',
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();
}

