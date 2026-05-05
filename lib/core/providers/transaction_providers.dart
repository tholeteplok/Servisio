import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../objectbox.g.dart';
import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/entities/stok_history.dart';
import '../../domain/entities/sync_queue_item.dart';
import '../services/session_manager.dart';
import 'objectbox_provider.dart';
import 'system_providers.dart';
import 'sync_provider.dart';
import '../services/transaction_number_service.dart';
import '../../domain/services/unit_of_work.dart';
import '../../domain/services/invoice_number_generator.dart';
import '../../domain/entities/invoice.dart';
import 'pelanggan_provider.dart';
import 'master_providers.dart';
import 'stok_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Notifiers
// ─────────────────────────────────────────────────────────────────────────────

class TransactionListNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  final Ref ref;
  Transaction? _lastDeleted;
  Transaction? get lastDeleted => _lastDeleted;

  TransactionListNotifier(this.ref) : super(const AsyncLoading()) {
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
    final repository = ref.read(transactionRepositoryProvider);
    state = AsyncData(repository.getAll());
  }

  void _syncPaginated() {
    if (ref.exists(paginatedTransactionListProvider)) {
      ref.read(paginatedTransactionListProvider.notifier).refresh();
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      final trxService = ref.read(trxNumberServiceProvider);

      // Generate nomor transaksi jika kosong
      if (transaction.trxNumber.isEmpty) {
        transaction.trxNumber = await trxService.generateTrxNumber(
          category: 'SERVICE',
          prefix: 'SVC',
        );
      }

      transaction.calculateTotals();
      repository.save(transaction);
      syncWorker?.enqueue(entityType: 'transaction', entityUuid: transaction.uuid, priority: SyncPriority.critical);

      // Enqueue related entities agar pelanggan & vehicle juga ter-push ke Firestore
      final pelanggan = transaction.pelanggan.target;
      if (pelanggan != null && pelanggan.uuid.isNotEmpty) {
        syncWorker?.enqueue(entityType: 'pelanggan', entityUuid: pelanggan.uuid);
      }
      final vehicle = transaction.vehicle.target;
      if (vehicle != null && vehicle.uuid.isNotEmpty) {
        syncWorker?.enqueue(entityType: 'vehicle', entityUuid: vehicle.uuid);
      }

      // Refresh related providers to ensure UI reflects new data
      ref.read(pelangganListProvider.notifier).load();
      ref.invalidate(vehicleListProvider);
      ref.read(stokListProvider.notifier).loadStok();

      return repository.getAll();
    });
    _syncPaginated();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      transaction.calculateTotals();
      repository.save(transaction);
      syncWorker?.enqueue(entityType: 'transaction', entityUuid: transaction.uuid, priority: SyncPriority.normal);

      // Refresh related providers to ensure UI reflects new data
      ref.read(pelangganListProvider.notifier).load();
      ref.invalidate(vehicleListProvider);
      ref.read(stokListProvider.notifier).loadStok();

      return repository.getAll();
    });
    _syncPaginated();
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
      repository.save(transaction);
      syncWorker?.enqueue(entityType: 'transaction', entityUuid: transaction.uuid, priority: SyncPriority.normal);
      return repository.getAll();
    });
    _syncPaginated();
  }

  Future<void> updateTransactionStatus(Transaction transaction, ServiceStatus newStatus) async {
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
      repository.save(transaction);
      syncWorker?.enqueue(entityType: 'transaction', entityUuid: transaction.uuid, priority: SyncPriority.critical);
      return repository.getAll();
    });
    _syncPaginated();
  }

  Future<void> finalizeTransaction(Transaction transaction, String paymentMethod) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(dbProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      final invoiceGen = ref.read(invoiceNumberGeneratorProvider);
      final itemsToSync = <({String type, String uuid})>[];

      // 1. Generate Invoice Number (Atomic & Unique)
      final invNumber = await invoiceGen.generate(category: 'SERVICE');

      db.store.runInTransaction(TxMode.write, () {
        for (var item in transaction.items) {
          if (!item.isService && item.stok.target != null) {
            final stok = db.stokBox.get(item.stok.target!.id);
            if (stok != null) {
              if (stok.jumlah < item.quantity) {
                throw Exception('Gagal: Stok "${stok.nama}" tidak mencukupi (${stok.jumlah} tersedia).');
              }
              final oldQty = stok.jumlah;
              stok.jumlah -= item.quantity;
              stok.updatedAt = DateTime.now();
              stok.version++;
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
              itemsToSync.add((type: 'stok', uuid: stok.uuid));
              itemsToSync.add((type: 'stok_history', uuid: history.uuid));
            }
          }
        }

        // 2. Buat Invoice Record untuk Audit & Print
        final invoice = Invoice(
          invoiceNumber: invNumber,
          transactionUuid: transaction.uuid,
          category: 'SERVICE',
        );
        db.invoiceBox.put(invoice);
        itemsToSync.add((type: 'invoice', uuid: invoice.uuid));

        // 3. Update Transaction Status
        transaction.serviceStatus = ServiceStatus.lunas;
        transaction.paymentMethod = paymentMethod;
        transaction.endTime ??= DateTime.now();
        transaction.updatedAt = DateTime.now();
        transaction.version++;
        transaction.calculateTotals();
        db.transactionBox.put(transaction);
      });

      for (final item in itemsToSync) {
        syncWorker?.enqueue(entityType: item.type, entityUuid: item.uuid);
      }
      syncWorker?.enqueue(entityType: 'transaction', entityUuid: transaction.uuid, priority: SyncPriority.critical);
      return ref.read(transactionRepositoryProvider).getAll();
    });
    _syncPaginated();
  }

  Future<void> deleteTransaction(int id, String uuid) async {
    final stateBefore = state.valueOrNull ?? [];
    _lastDeleted = stateBefore.firstWhere((t) => t.id == id, orElse: () => stateBefore.first);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      if (repository.softDelete(id)) {
        syncWorker?.enqueue(entityType: 'transaction', entityUuid: uuid, priority: SyncPriority.normal);
        return repository.getAll();
      }
      return stateBefore;
    });
    _syncPaginated();
  }

  Future<void> undoDelete() async {
    final tx = _lastDeleted;
    if (tx == null) return;
    _lastDeleted = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(transactionRepositoryProvider);
      tx.isDeleted = false;
      tx.updatedAt = DateTime.now();
      repository.save(tx);
      return repository.getAll();
    });
    _syncPaginated();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paginated Transaction Notifier
// ─────────────────────────────────────────────────────────────────────────────

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

class PaginatedTransactionListNotifier extends StateNotifier<PaginatedTransactionState> {
  final Ref ref;
  static const int _pageSize = 30;
  int? _lastDeletedId;

  PaginatedTransactionListNotifier(this.ref) : super(const PaginatedTransactionState()) {
    // Listen to session changes so data reloads when workshopId becomes
    // available after async authentication on app restart.
    ref.listen<SessionManager>(sessionManagerProvider, (prev, next) {
      final prevId = prev?.activeWorkshopId;
      final nextId = next.activeWorkshopId;
      if ((prevId == null || prevId.isEmpty) &&
          (nextId != null && nextId.isNotEmpty)) {
        Future.microtask(() => refresh());
      }
    });
    Future.microtask(() => refresh());
  }

  Future<void> _loadPage(int page, {bool isRefresh = false}) async {
    try {
      final repository = ref.read(transactionRepositoryProvider);
      if (!isRefresh && state.isLoadingMore) return;
      if (!isRefresh && !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true);
      final results = repository.getAll(limit: _pageSize, offset: page * _pageSize);
      final isLastPage = results.length < _pageSize;
      final newItems = isRefresh ? results : [...state.items, ...results];
      state = state.copyWith(items: newItems, isLoadingMore: false, hasMore: !isLastPage, currentPage: page, isInitialLoading: false);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, isInitialLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    await _loadPage(state.currentPage + 1);
  }

  Future<void> refresh() async {
    state = state.copyWith(isInitialLoading: true);
    await _loadPage(0, isRefresh: true);
  }

  Future<void> deleteTransaction(int id, String uuid) async {
    final stateBefore = state;
    if (!state.items.any((t) => t.id == id)) return;
    _lastDeletedId = id;
    state = state.copyWith(items: state.items.where((t) => t.id != id).toList());
    final repository = ref.read(transactionRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    if (repository.softDelete(id)) {
      syncWorker?.enqueue(entityType: 'transaction', entityUuid: uuid, priority: SyncPriority.normal);
    } else {
      state = stateBefore;
    }
  }

  Future<void> undoDelete() async {
    final id = _lastDeletedId;
    if (id == null) return;
    _lastDeletedId = null;
    final repository = ref.read(transactionRepositoryProvider);
    final tx = repository.getById(id);
    if (tx == null) return;
    tx.isDeleted = false;
    tx.updatedAt = DateTime.now();
    repository.save(tx);
    await refresh();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(dbProvider);
  final session = ref.watch(sessionManagerProvider);
  return TransactionRepository(db.transactionBox, session.activeWorkshopId);
});

final transactionListProvider = StateNotifierProvider<TransactionListNotifier, AsyncValue<List<Transaction>>>((ref) {
  return TransactionListNotifier(ref);
});

final paginatedTransactionListProvider = StateNotifierProvider<PaginatedTransactionListNotifier, PaginatedTransactionState>((ref) {
  return PaginatedTransactionListNotifier(ref);
});

final customerTransactionsProvider = Provider.family<List<Transaction>, int>((ref, pelangganId) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getByPelangganId(pelangganId);
});

final unitOfWorkProvider = Provider<UnitOfWork>((ref) {
  final db = ref.watch(dbProvider);
  return ObjectBoxUnitOfWork(db.store);
});

final invoiceNumberGeneratorProvider = Provider<InvoiceNumberGenerator>((ref) {
  final db = ref.watch(dbProvider);
  return InvoiceNumberGenerator(db.store);
});

