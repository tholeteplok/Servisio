import '../../domain/entities/stok_history.dart';
import '../../objectbox.g.dart';

class StokHistoryRepository {
  final Box<StokHistory> _box;

  StokHistoryRepository(this._box);

  int save(StokHistory history) {
    return _box.put(history);
  }

  List<StokHistory> getAllForStok(String stokUuid) {
    final query = _box
        .query(StokHistory_.stokUuid.equals(stokUuid))
        .order(StokHistory_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  List<StokHistory> getAll() {
    return _box.getAll();
  }
}

