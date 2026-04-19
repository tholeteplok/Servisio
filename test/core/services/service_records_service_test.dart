import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servislog_core/core/providers/master_providers.dart';
import 'package:servislog_core/core/providers/objectbox_provider.dart';
import 'package:servislog_core/domain/entities/service_master.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();

    container = createContainer(
      overrides: [
        dbProvider.overrideWithValue(fakeDb),
      ],
    );
  });

  group('ServiceMasterList Provider Tests', () {
    test('addItem() should save to database', () async {
      final item = ServiceMaster(
        name: 'Service Ringan',
        basePrice: 50000,
        category: 'Maintenance',
      );
      
      await container.read(serviceMasterListProvider.notifier).addItem(item);
      
      expect(fakeDb.serviceMasterBox.getAll().length, 1);
      expect(fakeDb.serviceMasterBox.getAll().first.name, 'Service Ringan');
    });

    test('updateItem() should update existing item', () async {
      final box = fakeDb.serviceMasterBox as FakeBox<ServiceMaster>;
      final item = ServiceMaster(name: 'Old', basePrice: 100);
      box.put(item);
      
      final updated = ServiceMaster(name: 'New', basePrice: 200)..id = item.id;
      await container.read(serviceMasterListProvider.notifier).updateItem(updated);
      
      expect(box.get(item.id)?.name, 'New');
    });

    test('deleteItem() should soft delete', () async {
      final box = fakeDb.serviceMasterBox as FakeBox<ServiceMaster>;
      final item = ServiceMaster(name: 'To Delete', basePrice: 0);
      box.put(item);
      
      await container.read(serviceMasterListProvider.notifier).deleteItem(item.id);
      
      expect(box.get(item.id)?.isDeleted, isTrue);
    });

    test('filteredServiceMaster should filter items by name', () async {
      final box = fakeDb.serviceMasterBox as FakeBox<ServiceMaster>;
      box.put(ServiceMaster(name: 'Ganti Oli', basePrice: 0));
      box.put(ServiceMaster(name: 'Ganti Ban', basePrice: 0));
      box.put(ServiceMaster(name: 'Cuci Motor', basePrice: 0));
      
      await container.read(serviceMasterListProvider.future); // Wait init

      final filtered = container.read(filteredServiceMasterProvider('Ganti'));
      expect(filtered.length, 2);
      expect(filtered.any((s) => s.name == 'Ganti Oli'), isTrue);
      expect(filtered.any((s) => s.name == 'Ganti Ban'), isTrue);
      
      final single = container.read(filteredServiceMasterProvider('Cuci'));
      expect(single.length, 1);
      expect(single.first.name, 'Cuci Motor');
    });
  });
}
