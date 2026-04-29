import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'objectbox_provider.dart';
import 'system_providers.dart';
import 'sync_provider.dart';
import '../services/session_manager.dart';
import '../../domain/entities/pelanggan.dart';
import '../../data/repositories/pelanggan_repository.dart';


class PelangganListNotifier extends StateNotifier<List<Pelanggan>> {
  final Ref ref;
  PelangganListNotifier(this.ref) : super([]) {
    // Listen to session changes so data reloads when workshopId becomes
    // available after async authentication on app restart.
    ref.listen<SessionManager>(sessionManagerProvider, (prev, next) {
      final prevId = prev?.activeWorkshopId;
      final nextId = next.activeWorkshopId;
      if ((prevId == null || prevId.isEmpty) &&
          (nextId != null && nextId.isNotEmpty)) {
        _init();
      }
    });
    _init();
  }

  void _init() {
    final repository = ref.read(pelangganRepositoryProvider);
    state = repository.getAll();
  }

  void load() {
    final repository = ref.read(pelangganRepositoryProvider);
    state = repository.getAll();
  }

  void add(Pelanggan pelanggan) {
    final repository = ref.read(pelangganRepositoryProvider);
    repository.save(pelanggan);
    load();
  }

  void remove(int id) {
    final repository = ref.read(pelangganRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    final pelanggan = repository.getAll().firstWhere((p) => p.id == id, orElse: () => Pelanggan(nama: '', telepon: ''));
    if (pelanggan.uuid.isNotEmpty && repository.softDelete(id)) {
      syncWorker?.enqueue(entityType: 'pelanggan', entityUuid: pelanggan.uuid);
      load();
    }
  }

  void updateSearch(String query) {
    final repository = ref.read(pelangganRepositoryProvider);
    if (query.isEmpty) {
      load();
    } else {
      state = repository.search(query);
    }
  }

  void updateItem(Pelanggan p) {
    final repository = ref.read(pelangganRepositoryProvider);
    repository.save(p);
    load();
  }

  void updatePhoto(int id, String? path) {
    final repository = ref.read(pelangganRepositoryProvider);
    final customers = repository.getAll();
    final index = customers.indexWhere((element) => element.id == id);
    if (index != -1) {
      final p = customers[index];
      p.photoLocalPath = path;
      repository.save(p);
      load();
    }
  }

  void addItem(Pelanggan p) => add(p);
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final pelangganRepositoryProvider = Provider<PelangganRepository>((ref) {
  final db = ref.watch(dbProvider);
  final session = ref.watch(sessionManagerProvider);
  return PelangganRepository(db.pelangganBox, session.activeWorkshopId);
});

final pelangganListProvider = StateNotifierProvider<PelangganListNotifier, List<Pelanggan>>((ref) {
  return PelangganListNotifier(ref);
});
