import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/pelanggan_provider.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/pelanggan.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;
  late FakeSyncWorker fakeSyncWorker;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();
    final box = fakeDb.pelangganBox as FakeBox<Pelanggan>;
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

  group('PelangganList Provider Tests', () {
    test('Initial state should load all customers from repository', () {
      final box = fakeDb.pelangganBox as FakeBox<Pelanggan>;
      box.put(Pelanggan(nama: 'Customer A', telepon: '081', uuid: 'uuid-a'));
      box.put(Pelanggan(nama: 'Customer B', telepon: '082', uuid: 'uuid-b'));

      final list = container.read(pelangganListProvider);
      expect(list.length, 2);
      expect(list.any((p) => p.nama == 'Customer A'), isTrue);
    });

    test('add() should save customer to repository and reload state', () {
      final p = Pelanggan(nama: 'New Customer', telepon: '081', uuid: 'new-uuid');
      container.read(pelangganListProvider.notifier).add(p);

      final box = fakeDb.pelangganBox as FakeBox<Pelanggan>;
      expect(box.items.length, 1);
      expect(box.items.first.nama, 'New Customer');
      
      final list = container.read(pelangganListProvider);
      expect(list.length, 1);
    });

    test('remove() should soft delete and enqueue sync', () {
      final box = fakeDb.pelangganBox as FakeBox<Pelanggan>;
      final p = Pelanggan(nama: 'To Delete', telepon: '081', uuid: 'del-uuid');
      final id = box.put(p);
      p.id = id;

      container.read(pelangganListProvider.notifier).remove(id);

      expect(box.get(id)?.isDeleted, isTrue);
      expect(fakeSyncWorker.enqueuedItems.length, 1);
      expect(fakeSyncWorker.enqueuedItems.first['entityUuid'], 'del-uuid');
      
      final list = container.read(pelangganListProvider);
      expect(list.length, 0); // isDeleted items are filtered in repository.getAll()
    });

    test('updateSearch() should filter state via repository search', () {
      final box = fakeDb.pelangganBox as FakeBox<Pelanggan>;
      box.put(Pelanggan(nama: 'John Doe', telepon: '081', uuid: 'j-1'));
      box.put(Pelanggan(nama: 'Jane Doe', telepon: '082', uuid: 'j-2'));
      box.put(Pelanggan(nama: 'Bob', telepon: '083', uuid: 'b-1'));
      
      final notifier = container.read(pelangganListProvider.notifier);
      
      // We need to mock the search behavior in FakeBox since it doesn't support complex queries by default
      box.onQueryCreated = (q) {
        // Simple mock search
        q.mockResults = box.getAll().where((p) => p.nama.contains('Doe')).toList();
      };

      notifier.updateSearch('Doe');
      
      final state = container.read(pelangganListProvider);
      expect(state.length, 2);
      expect(state.every((p) => p.nama.contains('Doe')), isTrue);
    });
  });
}
