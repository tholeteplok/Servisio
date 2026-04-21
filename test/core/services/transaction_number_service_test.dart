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
      final today = DateFormat('yyyyMMdd').format(DateTime.now());
      
      final num1 = await service.generateTrxNumber();
      expect(num1, 'SL-$today-001');
      
      final num2 = await service.generateTrxNumber();
      expect(num2, 'SL-$today-002');
    });

    test('getCurrentCount() should return correct count without updating', () async {
      final today = DateFormat('yyyyMMdd').format(DateTime.now());
      fakeStore.box<TrxCounter>().put(TrxCounter(date: today, count: 5));
      
      final count = await service.getCurrentCount();
      expect(count, 5);
      
      // Still 5
      expect(await service.getCurrentCount(), 5);
    });

    test('resetCounter() should clear counter for a date', () async {
      fakeStore.box<TrxCounter>().put(TrxCounter(date: '20200101', count: 10));
      await service.resetCounter('20200101');
      
      final box = fakeStore.box<TrxCounter>();
      expect(box.getAll().isEmpty, isTrue);
    });
  });
}
