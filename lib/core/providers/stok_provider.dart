import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/stok_history.dart';
import '../../data/repositories/stok_repository.dart';
import '../../data/repositories/stok_history_repository.dart';
import '../services/session_manager.dart';
import 'objectbox_provider.dart';
import 'system_providers.dart';
import 'sync_provider.dart';
import 'transaction_providers.dart';
import 'supplier_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stok Notifiers
// ─────────────────────────────────────────────────────────────────────────────

class StokListNotifier extends StateNotifier<List<Stok>> {
  final Ref ref;
  StokListNotifier(this.ref) : super([]) {
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
    final repository = ref.read(stokRepositoryProvider);
    state = repository.getAll();
  }

  void loadStok() {
    final repository = ref.read(stokRepositoryProvider);
    state = repository.getAll();
  }

  Future<void> addItem(Stok stok) async {
    final repository = ref.read(stokRepositoryProvider);
    final historyRepository = ref.read(stokHistoryRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    final id = repository.save(stok);
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

    repository.save(stok);
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
      repository.save(item);
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

enum StokSort { none, lowToHigh, highToLow, supplier }

class StokSortNotifier extends StateNotifier<StokSort> {
  StokSortNotifier() : super(StokSort.none);
  void setSort(StokSort sort) => state = sort;
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final stokRepositoryProvider = Provider<StokRepository>((ref) {
  final db = ref.watch(dbProvider);
  final session = ref.watch(sessionManagerProvider);
  return StokRepository(db.stokBox, session.activeWorkshopId);
});

final stokHistoryRepositoryProvider = Provider<StokHistoryRepository>((ref) {
  final db = ref.watch(dbProvider);
  return StokHistoryRepository(db.stokHistoryBox);
});

final stokListProvider = StateNotifierProvider<StokListNotifier, List<Stok>>((ref) {
  return StokListNotifier(ref);
});

final stokSortNotifierProvider = StateNotifierProvider<StokSortNotifier, StokSort>((ref) {
  return StokSortNotifier();
});

final sortedStokProvider = Provider<List<Stok>>((ref) {
  final list = ref.watch(stokListProvider);
  final sort = ref.watch(stokSortNotifierProvider);

  if (sort == StokSort.none) return list;

  final sortedList = List<Stok>.from(list);
  if (sort == StokSort.lowToHigh) {
    sortedList.sort((a, b) => a.jumlah.compareTo(b.jumlah));
  } else if (sort == StokSort.highToLow) {
    sortedList.sort((a, b) => b.jumlah.compareTo(a.jumlah));
  } else if (sort == StokSort.supplier) {
    sortedList.sort((a, b) {
      final sA = a.supplierName ?? '';
      final sB = b.supplierName ?? '';
      if (sA.isEmpty && sB.isNotEmpty) return 1;
      if (sA.isNotEmpty && sB.isEmpty) return -1;
      return sA.compareTo(sB);
    });
  }
  return sortedList;
});

final stokHistoryProvider = Provider.family<List<StokHistory>, String>((ref, stokUuid) {
  final repository = ref.watch(stokHistoryRepositoryProvider);
  return repository.getAllForStok(stokUuid);
});

final supplierBestSellingProvider = Provider<Map<String, Stok?>>((ref) {
  final transactionsAsync = ref.watch(transactionListProvider);
  final transactions = transactionsAsync.valueOrNull ?? [];
  final stokList = ref.watch(stokListProvider);
  
  if (transactions.isEmpty || stokList.isEmpty) return {};

  final supplierSalesCount = <String, Map<String, int>>{}; // supplier -> {stokUuid -> count}

  for (final tx in transactions) {
    if (tx.isDeleted) continue;
    for (final item in tx.items) {
      if (item.isService) continue;
      final stok = item.stok.target;
      if (stok != null) {
        final supplier = stok.supplierName ?? '';
        if (supplier.isEmpty) continue;
        
        supplierSalesCount.putIfAbsent(supplier, () => {});
        supplierSalesCount[supplier]![stok.uuid] = (supplierSalesCount[supplier]![stok.uuid] ?? 0) + item.quantity;
      }
    }
  }

  final result = <String, Stok?>{};
  for (final supplier in supplierSalesCount.keys) {
    final sales = supplierSalesCount[supplier]!;
    if (sales.isEmpty) continue;
    
    String? bestStokUuid;
    int maxQty = -1;
    
    sales.forEach((uuid, qty) {
      if (qty > maxQty) {
        maxQty = qty;
        bestStokUuid = uuid;
      }
    });

    if (bestStokUuid != null) {
      try {
        result[supplier] = stokList.firstWhere((s) => s.uuid == bestStokUuid);
      } catch (_) {
      }
    }
  }
  
  return result;
});

/// Provider for merged unique supplier names (from Supplier entities + Stok history)
final uniqueSuppliersProvider = Provider<List<String>>((ref) {
  // Source 1: Supplier entities
  final supplierEntities = ref.watch(supplierListProvider);
  final entityNames = supplierEntities.map((e) => e.nama.trim()).toSet();

  // Source 2: Stok history
  final stokRepository = ref.watch(stokRepositoryProvider);
  final historicalNames = stokRepository.getUniqueSuppliers().map((e) => e.trim()).toSet();

  // Merge and sort
  final merged = entityNames.union(historicalNames).toList();
  merged.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return merged;
});

