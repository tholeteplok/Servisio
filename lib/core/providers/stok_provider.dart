import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/stok_history.dart';
import '../../data/repositories/stok_repository.dart';
import '../../data/repositories/stok_history_repository.dart';
import 'objectbox_provider.dart';
import 'sync_provider.dart';

part 'stok_provider.g.dart';

@riverpod
StokRepository stokRepository(StokRepositoryRef ref) {
  final db = ref.watch(dbProvider);
  return StokRepository(db.stokBox);
}

@riverpod
StokHistoryRepository stokHistoryRepository(StokHistoryRepositoryRef ref) {
  final db = ref.watch(dbProvider);
  return StokHistoryRepository(db.stokHistoryBox);
}

@riverpod
class StokList extends _$StokList {
  @override
  List<Stok> build() {
    final repository = ref.watch(stokRepositoryProvider);
    return repository.getAll();
  }

  void loadStok() {
    final repository = ref.read(stokRepositoryProvider);
    state = repository.getAll();
  }

  Future<void> addItem(Stok stok) async {
    final repository = ref.read(stokRepositoryProvider);
    final historyRepository = ref.read(stokHistoryRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    final id = await repository.save(stok);
    stok.id = id;
    final history = StokHistory(
      stokUuid: stok.uuid,
      type: 'INITIAL',
      quantityChange: stok.jumlah,
      previousQuantity: 0,
      newQuantity: stok.jumlah,
      note: 'Stok awal ditambahkan',
    );
    historyRepository.save(history);

    syncWorker?.enqueue(entityType: 'stok', entityUuid: stok.uuid);
    syncWorker?.enqueue(entityType: 'stok_history', entityUuid: history.uuid);

    loadStok();
  }

  Future<void> updateItem(Stok stok) async {
    final repository = ref.read(stokRepositoryProvider);
    final historyRepository = ref.read(stokHistoryRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    final oldItem = repository.getByUuid(stok.uuid);
    final previousQty = oldItem?.jumlah ?? 0;

    await repository.save(stok);
    syncWorker?.enqueue(entityType: 'stok', entityUuid: stok.uuid);

    if (stok.jumlah != previousQty) {
      final history = StokHistory(
        stokUuid: stok.uuid,
        type: 'MANUAL_ADJUSTMENT',
        quantityChange: stok.jumlah - previousQty,
        previousQuantity: previousQty,
        newQuantity: stok.jumlah,
        note: 'Penyesuaian manual',
      );
      historyRepository.save(history);
      syncWorker?.enqueue(entityType: 'stok_history', entityUuid: history.uuid);
    }
    loadStok();
  }

  Future<void> restock(String uuid, int amount, String? note) async {
    final repository = ref.read(stokRepositoryProvider);
    final historyRepository = ref.read(stokHistoryRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    final item = repository.getByUuid(uuid);
    if (item != null) {
      final oldQty = item.jumlah;
      item.jumlah += amount;
      await repository.save(item);
      syncWorker?.enqueue(entityType: 'stok', entityUuid: item.uuid);

      final history = StokHistory(
        stokUuid: uuid,
        type: 'RESTOCK',
        quantityChange: amount,
        previousQuantity: oldQty,
        newQuantity: item.jumlah,
        note: note ?? 'Restock manual',
      );
      historyRepository.save(history);
      syncWorker?.enqueue(entityType: 'stok_history', entityUuid: history.uuid);

      loadStok();
    }
  }

  void deleteStok(int id) {
    final repository = ref.read(stokRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    // M-P02 FIX: Dapatkan data sebelum dihapus untuk mendapatkan UUID.
    // Gunakan softDelete agar sinkronisasi ke Cloud bisa dilakukan.
    final items = repository.getAll();
    final item = items.cast<Stok?>().firstWhere((e) => e?.id == id, orElse: () => null);
    
    if (item != null && repository.softDelete(id)) {
      syncWorker?.enqueue(entityType: 'stok', entityUuid: item.uuid);
      loadStok();
    }
  }

  void deleteItem(int id) => deleteStok(id);

  void search(String query) {
    final repository = ref.read(stokRepositoryProvider);
    if (query.isEmpty) {
      loadStok();
    } else {
      state = repository.search(query);
    }
  }
}

enum StokSort { none, lowToHigh, highToLow }

@riverpod
class StokSortNotifier extends _$StokSortNotifier {
  @override
  StokSort build() => StokSort.none;

  void setSort(StokSort sort) => state = sort;
}

@riverpod
List<Stok> sortedStok(SortedStokRef ref) {
  final list = ref.watch(stokListProvider);
  final sort = ref.watch(stokSortNotifierProvider);

  if (sort == StokSort.none) return list;

  final sortedList = List<Stok>.from(list);
  if (sort == StokSort.lowToHigh) {
    sortedList.sort((a, b) => a.jumlah.compareTo(b.jumlah));
  } else {
    sortedList.sort((a, b) => b.jumlah.compareTo(a.jumlah));
  }
  return sortedList;
}

@riverpod
List<StokHistory> stokHistory(StokHistoryRef ref, String stokUuid) {
  final repository = ref.watch(stokHistoryRepositoryProvider);
  return repository.getAllForStok(stokUuid);
}
