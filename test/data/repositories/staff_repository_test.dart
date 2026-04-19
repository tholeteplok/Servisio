import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/data/repositories/master_repositories.dart';
import 'package:servislog_core/domain/entities/staff.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeBox<Staff> fakeBox;
  late StaffRepository repository;

  setUp(() {
    fakeBox = FakeBox<Staff>();
    repository = StaffRepository(fakeBox);
    
    fakeBox.onQueryCreated = (q) {
      q.mockResults = fakeBox.getAll().where((e) => !e.isDeleted).toList();
    };
  });

  group('StaffRepository Tests', () {
    test('save() should add staff', () {
      final s = Staff(name: 'Andi', role: 'mekanik', uuid: 's-1');
      repository.save(s);
      
      expect(fakeBox.items.length, 1);
      expect(fakeBox.items.first.name, 'Andi');
    });

    test('getAll() should return non-deleted staff', () {
      repository.save(Staff(name: 'A', role: 'admin', uuid: 's-1'));
      
      final sB = Staff(name: 'B', role: 'mekanik', uuid: 's-2');
      repository.save(sB);
      repository.softDelete(sB.id);
      
      final results = repository.getAll();
      expect(results.length, 1);
      expect(results.first.name, 'A');
    });

    test('getByUuid() should return matching staff', () {
      final s = Staff(name: 'Andi', role: 'mekanik', uuid: 'uuid-1');
      repository.save(s);
      
      fakeBox.onQueryCreated = (q) => q.mockResults = [s];
      
      final result = repository.getByUuid('uuid-1');
      expect(result, isNotNull);
      expect(result!.name, 'Andi');
    });
  });
}
