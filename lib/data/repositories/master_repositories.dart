import '../../domain/entities/vehicle.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/service_master.dart';
import '../../objectbox.g.dart';

class VehicleRepository {
  final Box<Vehicle> _box;
  VehicleRepository(this._box);

  int save(Vehicle vehicle) {
    vehicle.updatedAt = DateTime.now();
    return _box.put(vehicle);
  }

  List<Vehicle> getAll() {
    final query = _box.query(Vehicle_.isDeleted.equals(false)).build();
    final results = query.find();
    query.close();
    return results;
  }

  Vehicle? getById(int id) {
    return _box.get(id);
  }

  Vehicle? getByPlate(String plate) {
    final query = _box.query(Vehicle_.plate.equals(plate).and(Vehicle_.isDeleted.equals(false))).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Vehicle? getByUuid(String uuid) {
    final query = _box.query(Vehicle_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  bool softDelete(int id) {
    final v = _box.get(id);
    if (v != null) {
      v.isDeleted = true;
      v.updatedAt = DateTime.now();
      _box.put(v);
      return true;
    }
    return false;
  }

  List<Vehicle> getByOwnerId(int ownerId) {
    final query = _box
        .query(
          Vehicle_.isDeleted.equals(false).and(Vehicle_.owner.equals(ownerId)),
        )
        .build();
    final results = query.find();
    query.close();
    return results;
  }
}

class StaffRepository {
  final Box<Staff> _box;
  StaffRepository(this._box);

  int save(Staff staff) {
    staff.updatedAt = DateTime.now();
    return _box.put(staff);
  }

  List<Staff> getAll() {
    final query = _box.query(Staff_.isDeleted.equals(false)).build();
    final results = query.find();
    query.close();
    return results;
  }

  Staff? getById(int id) {
    return _box.get(id);
  }

  Staff? getByUuid(String uuid) {
    final query = _box.query(Staff_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  bool softDelete(int id) {
    final s = _box.get(id);
    if (s != null) {
      s.isDeleted = true;
      s.updatedAt = DateTime.now();
      _box.put(s);
      return true;
    }
    return false;
  }
}

class ServiceMasterRepository {
  final Box<ServiceMaster> _box;
  ServiceMasterRepository(this._box);

  int save(ServiceMaster service) {
    service.updatedAt = DateTime.now();
    return _box.put(service);
  }

  List<ServiceMaster> getAll() {
    final query = _box.query(ServiceMaster_.isDeleted.equals(false)).build();
    final results = query.find();
    query.close();
    return results;
  }

  ServiceMaster? getByUuid(String uuid) {
    final query = _box.query(ServiceMaster_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  bool softDelete(int id) {
    final sm = _box.get(id);
    if (sm != null) {
      sm.isDeleted = true;
      sm.updatedAt = DateTime.now();
      _box.put(sm);
      return true;
    }
    return false;
  }
}

