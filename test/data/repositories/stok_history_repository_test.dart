import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/data/repositories/stok_history_repository.dart';
import 'package:servislog_core/domain/entities/stok_history.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<StokHistory> fakeBox;
  late StokHistoryRepository repository;

  setUp(() {
    fakeBox = FakeBox<StokHistory>();
    repository = StokHistoryRepository(fakeBox);
  });

  group('StokHistoryRepository Tests', () {
    test('save() should add history', () {
      final h = StokHistory(
        stokUuid: 's1', 
        type: 'INITIAL', 
        quantityChange: 10, 
        previousQuantity: 0,
        newQuantity: 10,
        uuid: 'h-1',
      );
      repository.save(h);
      expect(fakeBox.items.length, 1);
    });

    test('getAllForStok() should return matching history', () {
      final h1 = StokHistory(
        stokUuid: 's1', 
        type: 'SALE',
        quantityChange: -1,
        previousQuantity: 10,
        newQuantity: 9,
        uuid: 'h-1',
      );
      final h2 = StokHistory(
        stokUuid: 's2', 
        type: 'RESTOCK',
        quantityChange: 5,
        previousQuantity: 0,
        newQuantity: 5,
        uuid: 'h-2',
      );
      repository.save(h1);
      repository.save(h2);
      
      fakeBox.onQueryCreated = (q) => q.mockResults = [h1];
      
      final results = repository.getAllForStok('s1');
      expect(results.length, 1);
      expect(results.first.stokUuid, 's1');
    });
  });
}
