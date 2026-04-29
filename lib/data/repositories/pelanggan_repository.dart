import '../../domain/entities/pelanggan.dart';
import '../../objectbox.g.dart';

class PelangganRepository {
  final Box<Pelanggan> _box;
  final String? workshopId;

  PelangganRepository(this._box, [this.workshopId]);

  List<Pelanggan> getAll() {
    Condition<Pelanggan> cond = Pelanggan_.isDeleted.equals(false);
    if (workshopId != null) {
      cond = cond.and(Pelanggan_.bengkelId.equals(workshopId!));
    }
    final query = _box.query(cond).build();
    final results = query.find();
    query.close();
    return results;
  }

  Pelanggan? getByUuid(String uuid) {
    final query = _box.query(Pelanggan_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  int save(Pelanggan pelanggan) {
    pelanggan.updatedAt = DateTime.now();
    if (pelanggan.bengkelId.isEmpty && workshopId != null) {
      pelanggan.bengkelId = workshopId!;
    }
    return _box.put(pelanggan);
  }

  bool softDelete(int id) {
    final p = _box.get(id);
    if (p != null) {
      p.isDeleted = true;
      p.updatedAt = DateTime.now();
      _box.put(p);
      return true;
    }
    return false;
  }

  bool remove(int id) => _box.remove(id);

  List<Pelanggan> search(String query) {
    Condition<Pelanggan> cond = (Pelanggan_.nama
                .contains(query, caseSensitive: false)
                .or(Pelanggan_.telepon.contains(query)))
            .and(Pelanggan_.isDeleted.equals(false));

    if (workshopId != null) {
      cond = cond.and(Pelanggan_.bengkelId.equals(workshopId!));
    }

    final q = _box.query(cond).build();
    final results = q.find();
    q.close();
    return results;
  }
}

