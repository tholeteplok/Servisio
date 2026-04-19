import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/data/repositories/master_repositories.dart';
import 'package:servislog_core/domain/entities/vehicle.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<Vehicle> fakeBox;
  late VehicleRepository repository;

  setUp(() {
    fakeBox = FakeBox<Vehicle>();
    repository = VehicleRepository(fakeBox);
    
    fakeBox.onQueryCreated = (q) {
      q.mockResults = fakeBox.getAll().where((e) => !e.isDeleted).toList();
    };
  });

  group('VehicleRepository Tests', () {
    test('save() should add vehicle', () {
      final v = Vehicle(model: 'Vario', plate: 'B 1234 ABC', uuid: 'v-1');
      repository.save(v);
      
      expect(fakeBox.items.length, 1);
      expect(fakeBox.items.first.plate, 'B 1234 ABC');
    });

    test('getByUuid() should return matching vehicle', () {
      final v = Vehicle(model: 'Beat', plate: 'P 123', uuid: 'uuid-1');
      repository.save(v);
      
      fakeBox.onQueryCreated = (q) => q.mockResults = [v];
      
      final result = repository.getByUuid('uuid-1');
      expect(result, isNotNull);
      expect(result!.plate, 'P 123');
    });

    test('softDelete() should mark as deleted', () {
      final v = Vehicle(model: 'Beat', plate: 'P 123', uuid: 'v-1');
      repository.save(v);
      
      repository.softDelete(v.id);
      expect(fakeBox.get(v.id)!.isDeleted, isTrue);
    });
  });
}
