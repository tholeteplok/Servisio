import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'objectbox_provider.dart';
import 'sync_provider.dart';
import '../../domain/entities/pelanggan.dart';
import '../../data/repositories/pelanggan_repository.dart';

part 'pelanggan_provider.g.dart';

@riverpod
PelangganRepository pelangganRepository(PelangganRepositoryRef ref) {
  final db = ref.watch(dbProvider);
  return PelangganRepository(db.store.box<Pelanggan>());
}

@riverpod
class PelangganList extends _$PelangganList {
  @override
  List<Pelanggan> build() {
    final repository = ref.watch(pelangganRepositoryProvider);
    return repository.getAll();
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
    
    // H-P03 FIX: Dapatkan data sebelum dihapus untuk mendapatkan UUID 
    // agar sinkronisasi ke Cloud (Firestore) bisa dilakukan.
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
    final p = repository.getAll().firstWhere((element) => element.id == id);
    p.photoLocalPath = path;
    repository.save(p);
    load();
  }

  void addItem(Pelanggan p) => add(p);
}
