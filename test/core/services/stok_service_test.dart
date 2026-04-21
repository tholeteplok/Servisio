import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/stok_provider.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/stok.dart';
import 'package:servisio_core/domain/entities/stok_history.dart';
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

    // Default: queries return items that are not deleted
    final box = fakeDb.stokBox as FakeBox<Stok>;
    box.onQueryCreated = (q) {
      q.mockResults = box.items.where((s) => !s.isDeleted).toList();
    };
  });

  tearDown(() {
    container.dispose();
  });

  group('StokList Provider Tests', () {
    test('addItem() should save stok and initial history', () async {
        final stok = Stok(
          nama: 'Oli MPX2',
          jumlah: 10,
          sku: '123',
          uuid: 'stok-1',
          kategori: 'Oli',
        );
       
       await container.read(stokListProvider.notifier).addItem(stok);
       
       expect(fakeDb.stokBox.getAll().length, 1);
       expect(fakeDb.stokHistoryBox.getAll().length, 1);
       
       final history = (fakeDb.stokHistoryBox as FakeBox<StokHistory>).items.first;
       expect(history.type, 'INITIAL');
       expect(history.stokUuid, 'stok-1');
       
       expect(fakeSyncWorker.enqueuedItems.length, 2); // 1 stok, 1 history
    });

    test('addItem() should throw if jumlah is negative', () async {
       final stok = Stok(
         nama: 'Negative Stok',
         jumlah: -5,
         uuid: 'stok-neg',
       );
       
       await expectLater(
         container.read(stokListProvider.notifier).addItem(stok),
         throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('tidak boleh negatif'))),
       );
    });

    test('addItem() should throw if hargaJual < hargaBeli', () async {
       final stok = Stok(
         nama: 'Rugi Item',
         jumlah: 10,
         hargaBeli: 1000,
         hargaJual: 500,
         uuid: 'stok-rugi',
       );
       
       await expectLater(
         container.read(stokListProvider.notifier).addItem(stok),
         throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('lebih rendah dari modal'))),
       );
    });

    test('restock() should increment amount and add history', () async {
       final box = fakeDb.stokBox as FakeBox<Stok>;
       final stok = Stok(nama: 'Oli', jumlah: 5, uuid: 'stok-1');
       box.put(stok);
       
       await container.read(stokListProvider.notifier).restock('stok-1', 10, 'Beli baru');
       
       final updatedStok = box.items.first;
       expect(updatedStok.jumlah, 15);
       
       final history = (fakeDb.stokHistoryBox as FakeBox<StokHistory>).items.first;
       expect(history.type, 'RESTOCK');
       expect(history.quantityChange, 10);
       expect(history.previousQuantity, 5);
       expect(history.newQuantity, 15);
    });

    test('updateItem() should record history if quantity changes', () async {
        final box = fakeDb.stokBox as FakeBox<Stok>;
        final stok = Stok(nama: 'Oli', jumlah: 5, uuid: 'stok-1');
        final id = box.put(stok);
        
        final updatedStok = Stok(nama: 'Oli XL', jumlah: 8, uuid: 'stok-1');
        updatedStok.id = id; // Ensure same ID for update
        await container.read(stokListProvider.notifier).updateItem(updatedStok);
        
        // We need to re-find the item because repository might have put a new instance
        final result = box.items.firstWhere((s) => s.uuid == 'stok-1');
        expect(result.nama, 'Oli XL');
        expect(result.jumlah, 8);
       
       final history = (fakeDb.stokHistoryBox as FakeBox<StokHistory>).items.first;
       expect(history.type, 'MANUAL_ADJUSTMENT');
       expect(history.quantityChange, 3);
    });

    test('Sorting should work correctly', () {
       final box = fakeDb.stokBox as FakeBox<Stok>;
       box.put(Stok(nama: 'A', jumlah: 50, uuid: 'a'));
       box.put(Stok(nama: 'B', jumlah: 10, uuid: 'b'));
       box.put(Stok(nama: 'C', jumlah: 30, uuid: 'c'));
       
       container.read(stokListProvider); // Trigger build
       
       // Sort Low to High
       container.read(stokSortNotifierProvider.notifier).setSort(StokSort.lowToHigh);
       final lowToHigh = container.read(sortedStokProvider);
       expect(lowToHigh[0].nama, 'B');
       expect(lowToHigh[1].nama, 'C');
       expect(lowToHigh[2].nama, 'A');
       
       // Sort High to Low
       container.read(stokSortNotifierProvider.notifier).setSort(StokSort.highToLow);
       final highToLow = container.read(sortedStokProvider);
       expect(highToLow[0].nama, 'A');
       expect(highToLow[1].nama, 'C');
       expect(highToLow[2].nama, 'B');
    });
  });
}
