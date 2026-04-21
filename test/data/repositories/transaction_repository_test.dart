import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/data/repositories/transaction_repository.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<Transaction> fakeBox;
  late TransactionRepository repository;

  setUp(() {
    fakeBox = FakeBox<Transaction>();
    repository = TransactionRepository(fakeBox);
    
    fakeBox.onQueryCreated = (q) {
      // Default filtering for isDeleted
      q.mockResults = fakeBox.getAll().where((e) => !e.isDeleted).toList();
    };
  });

  group('TransactionRepository Tests', () {
    test('save() should add transaction and set updatedAt', () {
      final tx = Transaction(
        customerName: 'Budi',
        customerPhone: '0812',
        vehicleModel: 'Honda Beat',
        vehiclePlate: 'B 1234 ABC',
        uuid: 'tx-1',
      );
      tx.totalAmount = 100000;
      tx.bengkelId = 'b-1';
      repository.save(tx);
      
      expect(fakeBox.items.length, 1);
      expect(fakeBox.items.first.totalAmount, 100000);
      expect(fakeBox.items.first.updatedAt, isNotNull);
    });

    test('getAll() should return non-deleted transactions', () {
      repository.save(Transaction(customerName: 'A', customerPhone: '1', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-1'));
      repository.save(Transaction(customerName: 'B', customerPhone: '2', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-2'));
      
      final tx3 = Transaction(customerName: 'C', customerPhone: '3', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-3');
      repository.save(tx3);
      repository.softDelete(tx3.id);
      
      final results = repository.getAll();
      expect(results.length, 2);
      expect(results.any((e) => e.uuid == 'tx-3'), isFalse);
    });

    test('getByUuid() should return matching transaction', () {
      final tx = Transaction(customerName: 'Budi', customerPhone: '1', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-unique');
      repository.save(tx);
      
      fakeBox.onQueryCreated = (q) => q.mockResults = [tx];
      
      final result = repository.getByUuid('tx-unique');
      expect(result, isNotNull);
      expect(result!.uuid, 'tx-unique');
    });

    test('softDelete() should mark as deleted', () {
      final tx = Transaction(customerName: 'Budi', customerPhone: '1', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-1');
      repository.save(tx);
      
      final success = repository.softDelete(tx.id);
      expect(success, isTrue);
      expect(fakeBox.get(tx.id)!.isDeleted, isTrue);
    });
    
    test('getById() should return entity from box', () {
      final tx = Transaction(customerName: 'Budi', customerPhone: '1', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-1');
      final id = repository.save(tx);
      
      final result = repository.getById(id);
      expect(result, isNotNull);
      expect(result!.id, id);
    });

    test('delete() should perform hard delete', () {
      final tx = Transaction(customerName: 'Budi', customerPhone: '1', vehicleModel: 'M', vehiclePlate: 'P', uuid: 'tx-1');
      final id = repository.save(tx);
      
      repository.delete(id);
      expect(fakeBox.get(id), isNull);
    });
  });
}
