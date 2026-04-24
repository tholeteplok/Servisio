import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_worker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'objectbox_provider.dart';
import 'system_providers.dart';
import 'pengaturan_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Sync State Models
// ─────────────────────────────────────────────────────────────────────────────

class SyncStatusState {
  final SyncWorkerState state;
  final DateTime? lastSyncedAt;

  SyncStatusState({required this.state, this.lastSyncedAt});

  SyncStatusState copyWith({
    SyncWorkerState? state,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatusState(
      state: state ?? this.state,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🕹️ Sync Notifiers
// ─────────────────────────────────────────────────────────────────────────────

class SyncStatusNotifier extends StateNotifier<SyncStatusState> {
  final Ref ref;
  SyncStatusNotifier(this.ref) : super(SyncStatusState(state: SyncWorkerState.idle)) {
    // Initialize from persisted settings if available
    final lastSyncAtStr = ref.read(settingsProvider).lastSyncAt;
    if (lastSyncAtStr != null) {
      state = state.copyWith(lastSyncedAt: DateTime.tryParse(lastSyncAtStr));
    }
  }

  Future<void> setState(SyncWorkerState newState) async {
    final now = DateTime.now();
    
    // If successful, persist the time
    if (newState == SyncWorkerState.success) {
      await ref.read(settingsProvider.notifier).updateLastSyncTime();
    }

    state = state.copyWith(
      state: newState,
      lastSyncedAt: newState == SyncWorkerState.success ? now : state.lastSyncedAt,
    );
  }

  void retryFailed() {
    ref.read(syncWorkerProvider)?.retryFailedItems();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatusState>((ref) {
  return SyncStatusNotifier(ref);
});

final syncQueueSummaryProvider = Provider<Map<String, int>>((ref) {
  final worker = ref.watch(syncWorkerProvider);
  if (worker == null) return {'pending': 0, 'synced': 0, 'failed': 0, 'syncing': 0, 'total': 0};
  
  // Refresh when status changes
  ref.watch(syncStatusProvider);
  
  return worker.getQueueSummary();
});


final syncWorkerProvider = Provider<SyncWorker?>((ref) {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null || profile.bengkelId.isEmpty) return null;

  final db = ref.watch(dbProvider);
  final syncService = ref.watch(firestoreSyncServiceProvider);
  final deviceService = ref.watch(deviceSessionServiceProvider);
  final sessionManager = ref.watch(sessionManagerProvider);

  // Read settings once; the worker will be recreated if profile changes
  final settings = ref.read(settingsProvider);

  final worker = SyncWorker(
    db: db,
    syncService: syncService,
    deviceService: deviceService,
    sessionManager: sessionManager,
    bengkelId: profile.bengkelId,
    userId: FirebaseAuth.instance.currentUser?.uid,
    syncWifiOnly: settings.syncWifiOnly,
    onStateChanged: (state) {
      if (ref.exists(syncStatusProvider)) {
        ref.read(syncStatusProvider.notifier).setState(state);
      }
    },
  );

  worker.start();

  ref.onDispose(() {
    worker.dispose();
  });

  return worker;
});
