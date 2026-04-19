import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servislog_core/core/providers/sale_providers.dart';
import 'package:servislog_core/core/providers/objectbox_provider.dart';
import 'package:servislog_core/core/providers/sync_provider.dart';
import 'package:servislog_core/domain/entities/sale.dart';
import 'package:servislog_core/domain/entities/stok.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;
  late FakeSyncWorker fakeSyncWorker;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();
    fakeSyncWorker = FakeSyncWorker();

    container = createContainer(
      overrides: [
        dbProvider.overrideWithValue(fakeDb),
        syncWorkerProvider.overrideWithValue(fakeSyncWorker),
      ],
    );
  });

  group('SaleList Provider Tests', () {
    test('addSale() should save sale and refresh state', () async {
      final sale = Sale(
        itemName: 'Busi NGK',
        quantity: 1,
        totalPrice: 25000,
        uuid: 'sale-1',
      );
      
      await container.read(saleListProvider.notifier).addSale(sale);
      
      expect(fakeDb.saleBox.getAll().length, 1);
      final saved = (fakeDb.saleBox as FakeBox<Sale>).items.first;
      expect(saved.itemName, 'Busi NGK');
    });

    test('addSaleWithFinalization() should update stock and save sale', () async {
      // Setup stock
      final stockBox = fakeDb.stokBox as FakeBox<Stok>;
      final stock = Stok(nama: 'Oli MPX2', jumlah: 10, uuid: 'stok-1');
      stockBox.put(stock);
      
      final sale = Sale(
        itemName: 'Oli MPX2',
        quantity: 2,
        totalPrice: 100000,
        stokUuid: 'stok-1',
        uuid: 'sale-1',
      );
      
      await container.read(saleListProvider.notifier).addSaleWithFinalization(sale, 'Tunai');
      
      // Check stock reduced
      final updatedStok = stockBox.getAll().firstWhere((s) => s.uuid == 'stok-1');
      expect(updatedStok.jumlah, 8);
      
      // Check sale saved with payment method
      final savedSale = (fakeDb.saleBox as FakeBox<Sale>).items.first;
      expect(savedSale.paymentMethod, 'Tunai');
      
      // Check sync enqueued for sale, stok, and history
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityType'] == 'sale' && e['entityUuid'] == 'sale-1'), isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityType'] == 'stok' && e['entityUuid'] == 'stok-1'), isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityType'] == 'stok_history'), isTrue);
    });

    test('addSaleWithFinalization() should throw if stock insufficient', () async {
      final stockBox = fakeDb.stokBox as FakeBox<Stok>;
      final stock = Stok(nama: 'Oli', jumlah: 1, uuid: 'stok-1');
      stockBox.put(stock);
      
      final sale = Sale(
        itemName: 'Oli',
        quantity: 5,
        totalPrice: 250000,
        stokUuid: 'stok-1',
        uuid: 'sale-fail',
      );
      
      await container.read(saleListProvider.notifier).addSaleWithFinalization(sale, 'Tunai');
      
      final state = container.read(saleListProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('tidak mencukupi'));
    });

    test('deleteSale() should soft delete and enqueue sync', () async {
      final saleBox = fakeDb.saleBox as FakeBox<Sale>;
      final sale = Sale(itemName: 'Test', quantity: 1, totalPrice: 100, uuid: 'sale-del');
      saleBox.put(sale);
      
      container.read(saleListProvider.notifier).deleteSale(sale.id);
      
      expect(saleBox.get(sale.id)?.isDeleted, isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'sale-del'), isTrue);
    });
  });
}
