import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/data/repositories/master_repositories.dart';
import 'package:servislog_core/domain/entities/service_master.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<ServiceMaster> fakeBox;
  late ServiceMasterRepository repository;

  setUp(() {
    fakeBox = FakeBox<ServiceMaster>();
    repository = ServiceMasterRepository(fakeBox);
    
    fakeBox.onQueryCreated = (q) {
      q.mockResults = fakeBox.getAll().where((e) => !e.isDeleted).toList();
    };
  });

  group('ServiceMasterRepository Tests', () {
    test('save() should add service', () {
      final sm = ServiceMaster(name: 'Ganti Oli', uuid: 'sm-1');
      repository.save(sm);
      
      expect(fakeBox.items.length, 1);
      expect(fakeBox.items.first.name, 'Ganti Oli');
    });

    test('getAll() should return non-deleted services', () {
      repository.save(ServiceMaster(name: 'A', uuid: 'sm-1'));
      
      final sm2 = ServiceMaster(name: 'B', uuid: 'sm-2');
      repository.save(sm2);
      repository.softDelete(sm2.id);
      
      final results = repository.getAll();
      expect(results.length, 1);
      expect(results.first.name, 'A');
    });

    test('getByUuid() should return matching service', () {
      final sm = ServiceMaster(name: 'A', uuid: 'uuid-1');
      repository.save(sm);
      
      fakeBox.onQueryCreated = (q) => q.mockResults = [sm];
      
      final result = repository.getByUuid('uuid-1');
      expect(result, isNotNull);
      expect(result!.name, 'A');
    });
  });
}
