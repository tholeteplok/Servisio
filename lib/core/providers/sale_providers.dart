import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:objectbox/objectbox.dart'; // untuk TxMode
import '../../domain/entities/sale.dart';
import '../../data/repositories/sale_repository.dart';
import '../../domain/entities/stok_history.dart';
import 'objectbox_provider.dart';
import 'sync_provider.dart';
import '../../domain/entities/sync_queue_item.dart';

part 'sale_providers.g.dart';

@riverpod
SaleRepository saleRepository(SaleRepositoryRef ref) {
  final db = ref.watch(dbProvider);
  return SaleRepository(db.saleBox);
}

@riverpod
class SaleList extends _$SaleList {
  @override
  FutureOr<List<Sale>> build() {
    final repository = ref.watch(saleRepositoryProvider);
    return repository.getAll();
  }

  void loadSales() {
    final repository = ref.read(saleRepositoryProvider);
    state = AsyncData(repository.getAll());
  }

  Future<void> addSale(Sale sale) async {
    final repository = ref.read(saleRepositoryProvider);
    repository.save(sale);
    loadSales();
  }

  Future<void> addSales(List<Sale> sales) async {
    final repository = ref.read(saleRepositoryProvider);
    for (var sale in sales) {
      repository.save(sale);
    }
    loadSales();
  }

  // ── LGK-01 FIX: Validasi stok di layer provider (bukan hanya UI) ──
  // Menggunakan ObjectBox transaction agar atomic: stok tidak bisa negatif
  // bahkan jika dua device memproses Sale secara bersamaan.
  Future<void> addSaleWithFinalization(Sale sale, String paymentMethod) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(dbProvider);
      final repository = ref.read(saleRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);

      final itemsToSync = <({String type, String uuid})>[];

      db.store.runInTransaction(TxMode.write, () {
        // Guard stok jika Sale memiliki referensi stok (via stokUuid)
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

      // Enqueue SETELAH ObjectBox commit
      for (final item in itemsToSync) {
        syncWorker?.enqueue(entityType: item.type, entityUuid: item.uuid);
      }
      syncWorker?.enqueue(
        entityType: 'sale',
        entityUuid: sale.uuid,
        priority: SyncPriority.normal,
      );

      return repository.getAll();
    });
  }

  Future<void> addSalesWithFinalization(
    List<Sale> sales,
    String paymentMethod,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(dbProvider);
      final repository = ref.read(saleRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);

      final itemsToSync = <({String type, String uuid})>[];

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

      return repository.getAll();
    });
  }

  void deleteSale(int id) {
    final repository = ref.read(saleRepositoryProvider);
    final syncWorker = ref.read(syncWorkerProvider);
    
    // M-P05 FIX: Dapatkan data sebelum dihapus untuk mendapatkan UUID.
    final items = repository.getAll();
    final sale = items.cast<Sale?>().firstWhere((e) => e?.id == id, orElse: () => null);

    if (sale != null && repository.softDelete(id)) {
      syncWorker?.enqueue(entityType: 'sale', entityUuid: sale.uuid);
      loadSales();
    }
  }
}

@riverpod
List<Sale> customerSales(CustomerSalesRef ref, String customerName) {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.getByCustomerName(customerName);
}
