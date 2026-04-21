import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/transaction_number_service.dart';
import 'package:servisio_core/domain/entities/trx_counter.dart';
import 'package:intl/intl.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeStore fakeStore;
  late FakeObjectBoxProvider fakeDb;
  late TrxNumberService service;

  setUp(() {
    fakeStore = FakeStore();
    fakeDb = FakeObjectBoxProvider(fakeStore);
    service = TrxNumberService(fakeDb);
  });

  group('TrxNumberService Tests', () {
    test('generateTrxNumber() should increment and format correctly', () async {
      final today = DateFormat('yyMMdd').format(DateTime.now());
      
      final num1 = await service.generateTrxNumber(category: 'SERVICE', prefix: 'SVC');
      expect(num1, 'SVC-$today-001');
      
      final num2 = await service.generateTrxNumber(category: 'SERVICE', prefix: 'SVC');
      expect(num2, 'SVC-$today-002');

      final num3 = await service.generateTrxNumber(category: 'SALE', prefix: 'SLS');
      expect(num3, 'SLS-$today-001');
    });

    test('getCurrentCount() should return correct count without updating', () async {
      const key = 'SERVICE-260421';
      fakeStore.box<TrxCounter>().put(TrxCounter(count: 5, key: key));
      
      final count = await service.getCurrentCount(key);
      expect(count, 5);
      
      // Still 5
      expect(await service.getCurrentCount(key), 5);
    });

    test('resetCounter() should clear counter for a key', () async {
      const key = 'SERVICE-20200101';
      fakeStore.box<TrxCounter>().put(TrxCounter(count: 10, key: key));
      await service.resetCounter(key);
      
      final box = fakeStore.box<TrxCounter>();
      expect(box.getAll().isEmpty, isTrue);
    });
  });
}
