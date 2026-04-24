import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/service_master.dart';
import '../../domain/entities/vehicle.dart';
import '../../data/repositories/master_repositories.dart';
import 'objectbox_provider.dart';
import 'sync_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Staff Providers
// ─────────────────────────────────────────────────────────────────────────────

class StaffListNotifier extends StateNotifier<AsyncValue<List<Staff>>> {
  final Ref ref;
  StaffListNotifier(this.ref) : super(const AsyncLoading()) {
    _init();
  }

  void _init() {
    final repository = ref.read(staffRepositoryProvider);
    state = AsyncData(repository.getAll());
  }

  Future<void> add(Staff staff) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(staffRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      repository.save(staff);
      syncWorker?.enqueue(entityType: 'staff', entityUuid: staff.uuid);
      return repository.getAll();
    });
  }

  Future<void> updateStaff(Staff staff) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(staffRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      repository.save(staff);
      syncWorker?.enqueue(entityType: 'staff', entityUuid: staff.uuid);
      return repository.getAll();
    });
  }

  Future<void> delete(int id) async {
    final stateBefore = state.valueOrNull ?? [];
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(staffRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      final staff = repository.getById(id);
      if (staff != null && repository.softDelete(id)) {
        syncWorker?.enqueue(entityType: 'staff', entityUuid: staff.uuid);
        return repository.getAll();
      }
      return stateBefore;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service Master Providers
// ─────────────────────────────────────────────────────────────────────────────

class ServiceMasterListNotifier extends StateNotifier<AsyncValue<List<ServiceMaster>>> {
  final Ref ref;
  ServiceMasterListNotifier(this.ref) : super(const AsyncLoading()) {
    _init();
  }

  void _init() {
    final repository = ref.read(serviceMasterRepositoryProvider);
    state = AsyncData(repository.getAll());
  }

  void refresh() => _init();

  Future<void> addItem(ServiceMaster item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(serviceMasterRepositoryProvider);
      repository.save(item);
      return repository.getAll();
    });
  }

  Future<void> updateItem(ServiceMaster item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(serviceMasterRepositoryProvider);
      repository.save(item);
      return repository.getAll();
    });
  }

  Future<void> deleteItem(int id) async {
    final stateBefore = state.valueOrNull ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(serviceMasterRepositoryProvider);
      if (repository.softDelete(id)) {
        return repository.getAll();
      }
      return stateBefore;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle Providers
// ─────────────────────────────────────────────────────────────────────────────

class VehicleListNotifier extends StateNotifier<AsyncValue<List<Vehicle>>> {
  final Ref ref;
  VehicleListNotifier(this.ref) : super(const AsyncLoading()) {
    _init();
  }

  void _init() {
    final repository = ref.read(vehicleRepositoryProvider);
    state = AsyncData(repository.getAll());
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(vehicleRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      repository.save(vehicle);
      syncWorker?.enqueue(entityType: 'vehicle', entityUuid: vehicle.uuid);
      return repository.getAll();
    });
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(vehicleRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      repository.save(vehicle);
      syncWorker?.enqueue(entityType: 'vehicle', entityUuid: vehicle.uuid);
      return repository.getAll();
    });
  }

  Future<void> deleteVehicle(int id) async {
    final stateBefore = state.valueOrNull ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(vehicleRepositoryProvider);
      final syncWorker = ref.read(syncWorkerProvider);
      final vehicle = repository.getById(id);
      if (vehicle != null && repository.softDelete(id)) {
        syncWorker?.enqueue(entityType: 'vehicle', entityUuid: vehicle.uuid);
        return repository.getAll();
      }
      return stateBefore;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final db = ref.watch(dbProvider);
  return StaffRepository(Box<Staff>(db.store));
});

final staffListProvider = StateNotifierProvider<StaffListNotifier, AsyncValue<List<Staff>>>((ref) {
  return StaffListNotifier(ref);
});

final serviceMasterRepositoryProvider = Provider<ServiceMasterRepository>((ref) {
  final db = ref.watch(dbProvider);
  return ServiceMasterRepository(Box<ServiceMaster>(db.store));
});

final serviceMasterListProvider = StateNotifierProvider<ServiceMasterListNotifier, AsyncValue<List<ServiceMaster>>>((ref) {
  return ServiceMasterListNotifier(ref);
});

final filteredServiceMasterProvider = Provider.family<List<ServiceMaster>, String>((ref, query) {
  final asyncList = ref.watch(serviceMasterListProvider);
  final list = asyncList.valueOrNull ?? [];
  if (query.isEmpty) return list;
  final q = query.toLowerCase();
  return list.where((s) => s.name.toLowerCase().contains(q)).toList();
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final db = ref.watch(dbProvider);
  return VehicleRepository(Box<Vehicle>(db.store));
});

final vehicleListProvider = StateNotifierProvider<VehicleListNotifier, AsyncValue<List<Vehicle>>>((ref) {
  return VehicleListNotifier(ref);
});

final customerVehiclesProvider = Provider.family<List<Vehicle>, int>((ref, pelangganId) {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getByOwnerId(pelangganId);
});
