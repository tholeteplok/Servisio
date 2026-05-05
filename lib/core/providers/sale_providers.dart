import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';
import '../../domain/entities/sale.dart';
import '../../data/repositories/sale_repository.dart';
import '../../domain/entities/stok_history.dart';
import 'system_providers.dart';
import 'objectbox_provider.dart';
import 'sync_provider.dart';
import '../../domain/entities/sync_queue_item.dart';
import '../services/transaction_number_service.dart';
import 'stok_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notifiers
// ─────────────────────────────────────────────────────────────────────────────

class SaleListNotifier extends StateNotifier<AsyncValue<List<Sale>>> {
  final Ref ref;

  SaleListNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final repository = ref.read(saleRepositoryProvider);
    state = AsyncValue.data(repository.getAll());
  }

  void loadSales() {
    final repository = ref.read(saleRepositoryProvider);
    state = AsyncValue.data(repository.getAll());
  }

  Future<void> addSale(Sale sale) async {
    final repository = ref.read(saleRepositoryProvider);
    final trxService = ref.read(trxNumberServiceProvider);

    if (sale.trxNumber.isEmpty) {
      sale.trxNumber = await trxService.generateTrxNumber(
        category: 'SALE',
        prefix: 'SLS',
      );
    }

    repository.save(sale);
    loadSales();
  }

  Future<void> addSales(List<Sale> sales) async {
    final repository = ref.read(saleRepositoryProvider);
    final trxService = ref.read(trxNumberServiceProvider);

    for (var sale in sales) {
      if (sale.trxNumber.isEmpty) {
        sale.trxNumber = await trxService.generateTrxNumber(
          category: 'SALE',
          prefix: 'SLS',
        );
      }
      repository.save(sale);
    }
    loadSales();
  }

  Future<void> addSaleWithFinalization(Sale sale, String paymentMethod) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(dbProvider);
      final repository = ref.read(saleRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      final trxService = ref.read(trxNumberServiceProvider);

      final itemsToSync = <({String type, String uuid})>[];

      if (sale.trxNumber.isEmpty) {
        sale.trxNumber = await trxService.generateTrxNumber(
          category: 'SALE',
          prefix: 'SLS',
        );
      }

      db.store.runInTransaction(TxMode.write, () {
        if (sale.stokUuid != null) {
          final stokList = db.stokBox
              .getAll()
              .where((s) => s.uuid == sale.stokUuid)
              .toList();
          if (stokList.isNotEmpty) {
            final stok = stokList.first;
            if (stok.jumlah < sale.quantity) {
              throw Exception(
                'Stok "${stok.nama}" tidak mencukupi (${stok.jumlah} tersedia, diminta ${sale.quantity}).',
              );
            }
            final oldQty = stok.jumlah;
            stok.jumlah -= sale.quantity;
            stok.updatedAt = DateTime.now();
            stok.version++;
            db.stokBox.put(stok);

            final history = StokHistory(
              stokUuid: stok.uuid,
              type: 'DIRECT_SALE',
              quantityChange: -sale.quantity,
              previousQuantity: oldQty,
              newQuantity: stok.jumlah,
              note: 'Penjualan langsung: ${sale.itemName}',
            );
            db.stokHistoryBox.put(history);

            itemsToSync.add((type: 'stok', uuid: stok.uuid));
            itemsToSync.add((type: 'stok_history', uuid: history.uuid));
          }
        }

        sale.paymentMethod = paymentMethod;
        repository.save(sale); 
      });

      for (final item in itemsToSync) {
        syncWorker?.enqueue(entityType: item.type, entityUuid: item.uuid);
      }
      syncWorker?.enqueue(
        entityType: 'sale',
        entityUuid: sale.uuid,
        priority: SyncPriority.normal,
      );

      // Refresh stok list to reflect changes in quantity
      ref.read(stokListProvider.notifier).loadStok();

      return repository.getAll();
    });
  }

  Future<void> addSalesWithFinalization(
    List<Sale> sales,
    String paymentMethod,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(dbProvider);
      final repository = ref.read(saleRepositoryProvider);
      final trxService = ref.read(trxNumberServiceProvider);
      final syncWorker = ref.read(syncWorkerProvider);

      final itemsToSync = <({String type, String uuid})>[];

      for (final sale in sales) {
        if (sale.trxNumber.isEmpty) {
          sale.trxNumber = await trxService.generateTrxNumber(
            category: 'SALE',
            prefix: 'SLS',
          );
        }
      }

      db.store.runInTransaction(TxMode.write, () {
        for (final sale in sales) {
          if (sale.stokUuid != null) {
            final stokList = db.stokBox
                .getAll()
                .where((s) => s.uuid == sale.stokUuid)
                .toList();
            if (stokList.isNotEmpty) {
              final stok = stokList.first;
              if (stok.jumlah < sale.quantity) {
                throw Exception(
                  'Stok "${stok.nama}" tidak mencukupi (${stok.jumlah} tersedia, diminta ${sale.quantity}).',
                );
              }
              final oldQty = stok.jumlah;
              stok.jumlah -= sale.quantity;
              stok.updatedAt = DateTime.now();
              stok.version++;
              db.stokBox.put(stok);

              final history = StokHistory(
                stokUuid: stok.uuid,
                type: 'DIRECT_SALE',
                quantityChange: -sale.quantity,
                previousQuantity: oldQty,
                newQuantity: stok.jumlah,
                note: 'Penjualan langsung: ${sale.itemName}',
              );
              db.stokHistoryBox.put(history);

              itemsToSync.add((type: 'stok', uuid: stok.uuid));
              itemsToSync.add((type: 'stok_history', uuid: history.uuid));
            }
          }

          sale.paymentMethod = paymentMethod;
          repository.save(sale);
        }
      });

      for (final item in itemsToSync) {
        syncWorker?.enqueue(entityType: item.type, entityUuid: item.uuid);
      }
      for (final sale in sales) {
        syncWorker?.enqueue(
          entityType: 'sale',
          entityUuid: sale.uuid,
          priority: SyncPriority.normal,
        );
      }
      
      // Refresh stok list to reflect changes in quantity
      ref.read(stokListProvider.notifier).loadStok();

      return repository.getAll();
    });
  }

  void deleteSale(int id) {
    final repository = ref.read(saleRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    final items = repository.getAll();
    final sale = items.cast<Sale?>().firstWhere((e) => e?.id == id, orElse: () => null);

    if (sale != null && repository.softDelete(id)) {
      syncWorker?.enqueue(entityType: 'sale', entityUuid: sale.uuid);
      loadSales();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final db = ref.watch(dbProvider);
  final session = ref.watch(sessionManagerProvider);
  return SaleRepository(db.saleBox, session.activeWorkshopId);
});

final saleListProvider = StateNotifierProvider<SaleListNotifier, AsyncValue<List<Sale>>>((ref) {
  return SaleListNotifier(ref);
});

final customerSalesProvider = Provider.family<List<Sale>, String>((ref, customerName) {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getByCustomerName(customerName);
});

