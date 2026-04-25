import '../../objectbox.g.dart';
import '../../domain/entities/supplier.dart';

class SupplierRepository {
  final Box<Supplier> _box;

  SupplierRepository(this._box);

  int save(Supplier supplier) {
    supplier.updatedAt = DateTime.now();
    return _box.put(supplier);
  }

  List<Supplier> getAll(String bengkelId) {
    final query = _box
        .query(Supplier_.bengkelId.equals(bengkelId))
        .order(Supplier_.nama)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  Supplier? getById(int id) => _box.get(id);

  bool delete(int id) => _box.remove(id);
}

