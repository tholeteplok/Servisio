import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/data/repositories/sale_repository.dart';
import 'package:servisio_core/domain/entities/sale.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<Sale> fakeBox;
  late SaleRepository repository;

  setUp(() {
    fakeBox = FakeBox<Sale>();
    repository = SaleRepository(fakeBox);
    
    fakeBox.onQueryCreated = (q) {
      q.mockResults = fakeBox.getAll().where((e) => !e.isDeleted).toList();
    };
  });

  group('SaleRepository Tests', () {
    test('save() should add sale', () {
      final s = Sale(customerName: 'Budi', itemName: 'Oli', quantity: 1, totalPrice: 50000, uuid: 's-1');
      repository.save(s);
      expect(fakeBox.items.length, 1);
    });

    test('getAll() should return non-deleted sales', () {
      repository.save(Sale(customerName: 'A', itemName: 'Barang A', quantity: 1, totalPrice: 10, uuid: 's-1'));
      final s2 = Sale(customerName: 'B', itemName: 'Barang B', quantity: 1, totalPrice: 20, uuid: 's-2');
      repository.save(s2);
      repository.softDelete(s2.id);
      
      final results = repository.getAll();
      expect(results.length, 1);
      expect(results.first.customerName, 'A');
    });

    test('getByCustomerName() should return matching sales', () {
      final s = Sale(customerName: 'Andi Kusuma', itemName: 'Barang C', quantity: 1, totalPrice: 100, uuid: 's-1');
      repository.save(s);
      
      fakeBox.onQueryCreated = (q) => q.mockResults = [s];
      
      final results = repository.getByCustomerName('Andi');
      expect(results.length, 1);
      expect(results.first.customerName, contains('Andi'));
    });
  });
}
