import '../../domain/entities/pelanggan.dart';
import '../../objectbox.g.dart';

class PelangganRepository {
  final Box<Pelanggan> _box;

  PelangganRepository(this._box);

  List<Pelanggan> getAll() {
    final query = _box.query(Pelanggan_.isDeleted.equals(false)).build();
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
    final q = _box
        .query(
          (Pelanggan_.nama
                  .contains(query, caseSensitive: false)
                  .or(Pelanggan_.telepon.contains(query)))
              .and(Pelanggan_.isDeleted.equals(false)),
        )
        .build();
    final results = q.find();
    q.close();
    return results;
  }
}

