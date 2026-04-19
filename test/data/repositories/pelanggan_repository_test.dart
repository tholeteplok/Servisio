import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/data/repositories/pelanggan_repository.dart';
import 'package:servislog_core/domain/entities/pelanggan.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<Pelanggan> fakeBox;
  late PelangganRepository repository;

  setUp(() {
    fakeBox = FakeBox<Pelanggan>();
    repository = PelangganRepository(fakeBox);
    
    // Default: queries return all items for simple equality checks
    // We don't need complex predicates for PelangganRepository simple methods
    fakeBox.onQueryCreated = (q) {
       // Simple implementation for equals(false) on isDeleted
       q.mockResults = fakeBox.getAll().where((e) => !e.isDeleted).toList();
    };
  });

  group('PelangganRepository Tests', () {
    test('save() should add item and set updatedAt', () {
      final p = Pelanggan(nama: 'Budi', telepon: '0812', uuid: 'p-1');
      repository.save(p);
      
      expect(fakeBox.items.length, 1);
      expect(fakeBox.items.first.nama, 'Budi');
      expect(fakeBox.items.first.updatedAt, isNotNull);
    });

    test('getAll() should return non-deleted items', () {
      repository.save(Pelanggan(nama: 'A', uuid: 'a', telepon: '1'));
      repository.save(Pelanggan(nama: 'B', uuid: 'b', telepon: '2'));
      
      final pC = Pelanggan(nama: 'C', uuid: 'c', telepon: '3');
      repository.save(pC);
      repository.softDelete(pC.id);
      
      final results = repository.getAll();
      expect(results.length, 2);
      expect(results.any((e) => e.nama == 'C'), isFalse);
    });

    test('getByUuid() should return matching item', () {
      final p = Pelanggan(nama: 'Budi', uuid: 'budi-uuid', telepon: '0812');
      repository.save(p);
      
      // Override mockResults for specific query
      fakeBox.onQueryCreated = (q) => q.mockResults = [p];
      
      final result = repository.getByUuid('budi-uuid');
      expect(result, isNotNull);
      expect(result!.nama, 'Budi');
    });

    test('softDelete() should mark as deleted', () {
      final p = Pelanggan(nama: 'Budi', uuid: 'p-1', telepon: '0812');
      repository.save(p);
      
      final success = repository.softDelete(p.id);
      expect(success, isTrue);
      expect(fakeBox.get(p.id)!.isDeleted, isTrue);
    });
    
    // Note: search() is not tested here due to ObjectBox native lib limitations for complex OR/AND conditions in unit tests
  });
}
