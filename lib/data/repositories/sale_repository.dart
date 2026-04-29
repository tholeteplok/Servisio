import '../../objectbox.g.dart';
import '../../domain/entities/sale.dart';

class SaleRepository {
  final Box<Sale> _box;
  final String? workshopId;

  SaleRepository(this._box, [this.workshopId]);

  List<Sale> getAll({int limit = 0, int offset = 0}) {
    Condition<Sale> cond = Sale_.isDeleted.equals(false);
    if (workshopId != null) {
      cond = cond.and(Sale_.bengkelId.equals(workshopId!));
    }

    final query = _box
        .query(cond)
        .order(Sale_.createdAt, flags: Order.descending)
        .build();

    if (limit > 0) {
      query.limit = limit;
      query.offset = offset;
    }

    final results = query.find();
    query.close();
    return results;
  }

  List<Sale> getByCustomerName(String name) {
    name = name.toLowerCase().trim();
    Condition<Sale> cond = Sale_.isDeleted
        .equals(false)
        .and(Sale_.customerName.contains(name, caseSensitive: false));
        
    if (workshopId != null) {
      cond = cond.and(Sale_.bengkelId.equals(workshopId!));
    }

    final query = _box
        .query(cond)
        .order(Sale_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  int save(Sale sale) {
    sale.updatedAt = DateTime.now();
    if (sale.bengkelId.isEmpty && workshopId != null) {
      sale.bengkelId = workshopId!;
    }
    return _box.put(sale);
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

  void delete(int id) {
    _box.remove(id);
  }
}

