import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/data/repositories/stok_repository.dart';
import 'package:servislog_core/domain/entities/stok.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<Stok> fakeStokBox;
  late StokRepository repository;

  setUp(() {
    fakeStokBox = FakeBox<Stok>();
    repository = StokRepository(fakeStokBox);

    // Default: queries return nothing (no duplicate)
    fakeStokBox.onQueryCreated = (q) {
      q.mockResults = [];
    };
  });

  group('StokRepository Tests', () {
    test('save() should add new item and set updatedAt', () {
      final stok = Stok(
        nama: 'Oli MPX2',
        hargaBeli: 45000,
        hargaJual: 55000,
        jumlah: 10,
        uuid: 'stok-1',
      );

      final id = repository.save(stok);
      expect(id, 1);
      expect(fakeStokBox.items.length, 1);
      expect(fakeStokBox.items.first.nama, 'Oli MPX2');
      expect(fakeStokBox.items.first.updatedAt, isNotNull);
    });

    test('save() should throw exception if SKU duplicate', () {
      final existing = Stok(nama: 'Barang A', uuid: 'a', sku: 'SKU123');
      // Success first
      repository.save(existing);
      
      final duplicate = Stok(nama: 'Barang B', uuid: 'b', sku: 'SKU123');
      
      // Mock query to find existing
      fakeStokBox.onQueryCreated = (q) => q.mockResults = [existing];
      
      expect(() => repository.save(duplicate), throwsException);
    });

    test('save() should reject negative stock', () {
      final stok = Stok(nama: 'Test', jumlah: -1);
      expect(() => repository.save(stok), throwsA(predicate((e) => e.toString().contains('tidak boleh negatif'))));
    });

    test('save() should reject harga jual < harga beli', () {
      final stok = Stok(
        nama: 'Test', 
        hargaBeli: 10000, 
        hargaJual: 8000, 
        jumlah: 1,
      );
      expect(() => repository.save(stok), throwsA(predicate((e) => e.toString().contains('lebih rendah dari modal'))));
    });

    test('save() should allow harga jual == harga beli', () {
      final stok = Stok(
        nama: 'Test', 
        hargaBeli: 10000, 
        hargaJual: 10000, 
        jumlah: 1,
      );
      final id = repository.save(stok);
      expect(id, isPositive);
    });

    test('save() should throw exception if Name duplicate (Case-insensitive)', () {
      final existing = Stok(nama: 'Pertamax', uuid: 'a');
      repository.save(existing);
      
      final duplicate = Stok(nama: '  pertamax  ', uuid: 'b');

      // Mock query to find existing
      fakeStokBox.onQueryCreated = (q) => q.mockResults = [existing];
      
      expect(() => repository.save(duplicate), throwsException);
    });

    test('getAll() should only return non-deleted items', () {
      repository.save(Stok(nama: 'A', uuid: 'a'));
      repository.save(Stok(nama: 'B', uuid: 'b'));
      
      final itemC = Stok(nama: 'C', uuid: 'c');
      repository.save(itemC);
      repository.softDelete(itemC.id);
      
      // Mock getAll() filtering logic since FakeBox doesn't do it automatically for complex queries
      fakeStokBox.onQueryCreated = (q) {
        q.mockResults = fakeStokBox.getAll().where((e) => !e.isDeleted).toList();
      };
      
      final results = repository.getAll();
      expect(results.length, 2);
      expect(results.any((e) => e.nama == 'C'), isFalse);
    });

    /*
    test('search() should filter by name or SKU', () {
      final itemA = Stok(nama: 'Ban Luar', uuid: 'a', sku: 'BAN01');
      final itemB = Stok(nama: 'Oli Mesin', uuid: 'b', sku: 'OLI01');
      repository.save(itemA);
      repository.save(itemB);
      
      // Mock search query output
      fakeStokBox.onQueryCreated = (q) {
        q.mockResults = [itemA];
      };
      expect(repository.search('Ban').length, 1);
    });
    */

    test('getLowStockItems() should return items with jumlah <= minStok', () {
      final itemLow = Stok(nama: 'B', uuid: 'b', jumlah: 3, minStok: 5);
      repository.save(Stok(nama: 'A', uuid: 'a', jumlah: 10, minStok: 5));
      repository.save(itemLow);
      
      fakeStokBox.onQueryCreated = (q) {
        q.mockResults = [itemLow];
      };
      
      final results = repository.getLowStockItems();
      expect(results.length, 1);
      expect(results.first.nama, 'B');
    });
  });
}
