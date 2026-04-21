import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/master_providers.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/staff.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;
  late FakeSyncWorker fakeSyncWorker;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();
    final box = fakeDb.staffBox as FakeBox<Staff>;
    box.queryPredicate = (item, cond) => !item.isDeleted;

    fakeSyncWorker = FakeSyncWorker();

    container = createContainer(
      overrides: [
        dbProvider.overrideWithValue(fakeDb),
        syncWorkerProvider.overrideWithValue(fakeSyncWorker),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('StaffList Provider Tests', () {
    test('Initial state should load staff from repository', () async {
      final box = fakeDb.staffBox as FakeBox<Staff>;
      box.put(Staff(name: 'Technician 1', uuid: 't1', role: 'teknisi'));



      
      // Wait for future to complete
      final list = container.read(staffListProvider).value!;
      
      expect(list.length, 1);
      expect(list.first.name, 'Technician 1');
    });

    test('add() should update state and enqueue sync', () async {
      final staff = Staff(name: 'New Tech', uuid: 'new-t', role: 'teknisi');
      
      await container.read(staffListProvider.notifier).add(staff);
      
      final list = container.read(staffListProvider).value;
      expect(list?.any((s) => s.name == 'New Tech'), isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'new-t'), isTrue);
    });

    test('delete() should soft delete and update state', () async {
      final box = fakeDb.staffBox as FakeBox<Staff>;
      final staff = Staff(name: 'To Resign', uuid: 'r1', role: 'teknisi');
      final id = box.put(staff);
      staff.id = id;
      
      // Initialize provider
      container.read(staffListProvider);

      await container.read(staffListProvider.notifier).delete(id);
      
      final list = container.read(staffListProvider).value;
      expect(list?.any((s) => s.uuid == 'r1'), isFalse);
      expect(box.get(id)?.isDeleted, isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'r1'), isTrue);
    });
  });
}
