import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/master_providers.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/vehicle.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;
  late FakeSyncWorker fakeSyncWorker;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();
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

  group('VehicleList Provider Tests', () {
    test('Initial state should load vehicles from repository', () async {
      final box = fakeDb.vehicleBox;
      final v = Vehicle(model: 'Vario 150', plate: 'B 1234 ABC', uuid: 'v1');
      v.owner.targetId = 1;
      box.put(v);

      final list = container.read(vehicleListProvider).value!;
      
      expect(list.length, 1);
      expect(list.first.model, 'Vario 150');
    });

    test('addVehicle() should update state and enqueue sync', () async {
      final vehicle = Vehicle(model: 'Beat', plate: 'B 5555 XYZ', uuid: 'beat-1');
      vehicle.owner.targetId = 1;
      
      await container.read(vehicleListProvider.notifier).addVehicle(vehicle);
      
      final list = container.read(vehicleListProvider).value;
      expect(list?.any((v) => v.model == 'Beat'), isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'beat-1'), isTrue);
    });

    test('customerVehicles provider should filter correctly', () {
      final box = fakeDb.vehicleBox;
      
      final v1 = Vehicle(model: 'V1', plate: 'P1', uuid: 'v1');
      v1.owner.targetId = 1;
      
      final v2 = Vehicle(model: 'V2', plate: 'P2', uuid: 'v2');
      v2.owner.targetId = 2;
      
      final v3 = Vehicle(model: 'V3', plate: 'P3', uuid: 'v3');
      v3.owner.targetId = 1;
      
      box.putMany([v1, v2, v3]);
      
      // Set query predicate for filtering
      (box as FakeBox<Vehicle>).queryPredicate = (item, condition) {
        return item.owner.targetId == 1;
      };

      final list = container.read(customerVehiclesProvider(1));
      expect(list.length, 2);
      expect(list.every((v) => v.owner.targetId == 1), isTrue);
    });
  });
}
