import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../objectbox.g.dart';
import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/entities/stok_history.dart';
import '../../domain/entities/sync_queue_item.dart';
import 'objectbox_provider.dart';
import 'sync_provider.dart';


part 'transaction_providers.g.dart';

@riverpod
TransactionRepository transactionRepository(TransactionRepositoryRef ref) {
  final db = ref.watch(dbProvider);
  return TransactionRepository(db.transactionBox);
}

@riverpod
class TransactionList extends _$TransactionList {
  @override
  FutureOr<List<Transaction>> build() async {
    final repository = ref.watch(transactionRepositoryProvider);
    return repository.getAll();
  }

  // ─── FIX [KRITIS]: Semua mutasi dibungkus AsyncValue.guard ───────────────

  // ── LGK-02 HELPER: Sinkronisasi PaginatedTransactionList setelah setiap mutasi ──
  void _syncPaginated() {
    ref.invalidate(paginatedTransactionListProvider);
  }

  Future<void> addTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      transaction.calculateTotals();
      await repository.save(transaction);
      syncWorker?.enqueue(
        entityType: 'transaction',
        entityUuid: transaction.uuid,
        priority: SyncPriority.critical,
      );
      return repository.getAll();
    });
    _syncPaginated(); // LGK-02: keep HomeScreen in sync
  }

  Future<void> updateTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      transaction.calculateTotals();
      await repository.save(transaction);
      syncWorker?.enqueue(
        entityType: 'transaction',
        entityUuid: transaction.uuid,
        priority: SyncPriority.normal,
      );
      return repository.getAll();
    });
    _syncPaginated(); // LGK-02
  }

  Future<void> promoteTransactionStatus(Transaction transaction) async {
    if (transaction.serviceStatus == ServiceStatus.selesai) return;

    if (transaction.serviceStatus == ServiceStatus.antri) {
      transaction.serviceStatus = ServiceStatus.dikerjakan;
      transaction.startTime = DateTime.now();
    } else if (transaction.serviceStatus == ServiceStatus.dikerjakan) {
      transaction.serviceStatus = ServiceStatus.selesai;
      transaction.endTime = DateTime.now();
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      await repository.save(transaction);
      syncWorker?.enqueue(
        entityType: 'transaction',
        entityUuid: transaction.uuid,
        priority: SyncPriority.normal,
      );
      return repository.getAll();
    });
    _syncPaginated(); // LGK-02
  }

  Future<void> updateTransactionStatus(
    Transaction transaction,
    ServiceStatus newStatus,
  ) async {
    transaction.serviceStatus = newStatus;

    if (newStatus == ServiceStatus.dikerjakan) {
      transaction.startTime ??= DateTime.now();
    } else if (newStatus == ServiceStatus.selesai) {
      transaction.endTime ??= DateTime.now();
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      transaction.calculateTotals();
      await repository.save(transaction);
      syncWorker?.enqueue(
        entityType: 'transaction',
        entityUuid: transaction.uuid,
        priority: SyncPriority.critical,
      );
      return repository.getAll();
    });
    _syncPaginated(); // LGK-02
  }

  Future<void> finalizeTransaction(
    Transaction transaction,
    String paymentMethod,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(dbProvider);
      final syncWorker = ref.read(syncWorkerProvider);

      // Kumpulkan item yang perlu di-enqueue setelah transaction selesai.
      // FIX [PERINGATAN]: enqueue() TIDAK boleh dipanggil di dalam
      // runInTransaction karena akan menulis ke syncQueueBox secara nested.
      final itemsToSync = <({String type, String uuid})>[];

      db.store.runInTransaction(TxMode.write, () {
        for (var item in transaction.items) {
          if (!item.isService && item.stok.target != null) {
            final stok = db.stokBox.get(item.stok.target!.id);
            if (stok != null) {
              // 🛡️ K-5: Optimistic/Pragmatic Check
              if (stok.jumlah < item.quantity) {
                throw Exception(
                  'Gagal: Stok "${stok.nama}" tidak mencukupi (${stok.jumlah} tersedia).',
                );
              }

              final oldQty = stok.jumlah;
              stok.jumlah -= item.quantity;
              stok.updatedAt = DateTime.now();
              stok.version++; // 🛡️ Increment version for sync conflict detection

              db.stokBox.put(stok);

              final history = StokHistory(
                stokUuid: stok.uuid,
                type: 'SALE_FROM_SERVICE',
                quantityChange: -item.quantity,
                previousQuantity: oldQty,
                newQuantity: stok.jumlah,
                note: 'Otomatis dari transaksi ${transaction.trxNumber}',
              );
              db.stokHistoryBox.put(history);

              // Catat untuk di-enqueue setelah transaction commit
              itemsToSync.add((type: 'stok', uuid: stok.uuid));
              itemsToSync.add((type: 'stok_history', uuid: history.uuid));
            }
          }
        }

        // Update transaction status dan version
        transaction.serviceStatus = ServiceStatus.lunas;
        transaction.paymentMethod = paymentMethod;
        transaction.endTime ??= DateTime.now();
        transaction.updatedAt = DateTime.now();
        transaction.version++; // 🛡️ Increment version
        transaction.calculateTotals();

        db.transactionBox.put(transaction);
      });

      // Enqueue SETELAH transaction ObjectBox commit
      for (final item in itemsToSync) {
        syncWorker?.enqueue(entityType: item.type, entityUuid: item.uuid);
      }
      syncWorker?.enqueue(
        entityType: 'transaction',
        entityUuid: transaction.uuid,
        priority: SyncPriority.critical,
      );

      final repository = ref.read(transactionRepositoryProvider);
      return repository.getAll();
    });
    _syncPaginated(); // LGK-02
  }

  Future<void> deleteTransaction(int id, String uuid) async {
    final stateBefore = state.valueOrNull ?? [];
    _lastDeleted = stateBefore.firstWhere(
      (t) => t.id == id,
      orElse: () => stateBefore.first,
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      if (repository.softDelete(id)) {
        syncWorker?.enqueue(
          entityType: 'transaction',
          entityUuid: uuid,
          priority: SyncPriority.normal,
        );
        return repository.getAll();
      }
      return stateBefore;
    });
    _syncPaginated(); // LGK-02
  }

  // ── Undo Support ─────────────────────────────────────────────
  Transaction? _lastDeleted;
  Transaction? get lastDeleted => _lastDeleted;

  Future<void> undoDelete() async {
    final tx = _lastDeleted;
    if (tx == null) return;
    _lastDeleted = null;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      tx.isDeleted = false;
      tx.updatedAt = DateTime.now();
      await repository.save(tx);
      return repository.getAll();
    });
    _syncPaginated(); // LGK-02
  }
}

// ─────────────────────────────────────────────────────────────
// PAGINATED TRANSACTION LIST (Phase 2 — Performance)
// Digunakan oleh HomeScreen untuk load-more / infinite scroll.
// ─────────────────────────────────────────────────────────────

/// State model untuk halaman transaksi yang dipaginasi.
class PaginatedTransactionState {
  final List<Transaction> items;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final bool isInitialLoading;

  const PaginatedTransactionState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.isInitialLoading = true,
  });

  PaginatedTransactionState copyWith({
    List<Transaction>? items,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    bool? isInitialLoading,
  }) {
    return PaginatedTransactionState(
      items: items ?? this.items,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    );
  }
}

@riverpod
class PaginatedTransactionList extends _$PaginatedTransactionList {
  static const int _pageSize = 30;

  @override
  PaginatedTransactionState build() {
    // Load halaman pertama dengan aman setelah build pertama selesai
    Future.microtask(() => refresh());
    return const PaginatedTransactionState();
  }

  Future<void> _loadPage(int page, {bool isRefresh = false}) async {
    try {
      final repository = ref.read(transactionRepositoryProvider);

      if (!isRefresh && state.isLoadingMore) return;
      if (!isRefresh && !state.hasMore) return;

      state = state.copyWith(isLoadingMore: true);

      final results = repository.getAll(
        limit: _pageSize,
        offset: page * _pageSize,
      );

      final isLastPage = results.length < _pageSize;
      final newItems = isRefresh ? results : [...state.items, ...results];

      state = state.copyWith(
        items: newItems,
        isLoadingMore: false,
        hasMore: !isLastPage,
        currentPage: page,
        isInitialLoading: false,
      );
    } catch (e) {
      // Pastikan state tidak nyangkut di loading jika error
      state = state.copyWith(
        isLoadingMore: false,
        isInitialLoading: false,
      );
    }
  }

  /// Load next page (dipanggil saat user scroll ke bawah)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    await _loadPage(state.currentPage + 1);
  }

  /// Refresh dari awal (dipanggil saat pull-to-refresh atau setelah mutasi)
  Future<void> refresh() async {
    state = state.copyWith(isInitialLoading: true);
    await _loadPage(0, isRefresh: true);
  }

  // ── DELETE & UNDO (Phase 4 — UX) ───────────────────────────
  // ✅ FIX #4: Simpan ID saja, bukan objek in-memory, agar undoDelete()
  // selalu me-restore data terkini dari DB (bukan snapshot stale).
  int? _lastDeletedId;

  Future<void> deleteTransaction(int id, String uuid) async {
    final stateBefore = state;
    final trxIndex = state.items.indexWhere((t) => t.id == id);
    if (trxIndex == -1) return;

    _lastDeletedId = id;

    // Fast UI update: filter out deleted item
    state = state.copyWith(
      items: state.items.where((t) => t.id != id).toList(),
    );

    // Sync to DB
    final repository = ref.read(transactionRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);

    if (repository.softDelete(id)) {
      syncWorker?.enqueue(
        entityType: 'transaction',
        entityUuid: uuid,
        priority: SyncPriority.normal,
      );
    } else {
      // Rollback if DB failed
      state = stateBefore;
    }
  }

  Future<void> undoDelete() async {
    final id = _lastDeletedId;
    if (id == null) return;
    _lastDeletedId = null;

    // ✅ FIX #4: Fetch dari DB untuk memastikan data terkini (bukan in-memory stale)
    final repository = ref.read(transactionRepositoryProvider);
    final tx = repository.getById(id);
    if (tx == null) return; // sudah benar-benar dihapus, tidak bisa undo

    tx.isDeleted = false;
    tx.updatedAt = DateTime.now();
    await repository.save(tx);

    await refresh();
  }
}

@riverpod
List<Transaction> customerTransactions(
  CustomerTransactionsRef ref,
  int pelangganId,
) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getByPelangganId(pelangganId);
}

// DIHAPUS: stokHistoryRepository — provider ini kini ada di stok_provider.dart.
// Gunakan: import 'stok_provider.dart'; dan ref.watch(stokHistoryRepositoryProvider)
