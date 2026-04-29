import 'package:servisio_core/domain/entities/transaction.dart';
import '../../objectbox.g.dart';

class TransactionRepository {
  final Box<Transaction> _box;
  final String? workshopId;
  TransactionRepository(this._box, [this.workshopId]);

  int save(Transaction transaction) {
    transaction.updatedAt = DateTime.now();
    // Auto-set workshopId if not set
    if (transaction.bengkelId.isEmpty && workshopId != null) {
      transaction.bengkelId = workshopId!;
    }
    return _box.put(transaction);
  }

  /// Get all transactions that are not soft-deleted
  List<Transaction> getAll({int limit = 0, int offset = 0}) {
    Condition<Transaction> cond = Transaction_.isDeleted.equals(false);
    if (workshopId != null) {
      cond = cond.and(Transaction_.bengkelId.equals(workshopId!));
    }

    final query = _box
        .query(cond)
        .order(Transaction_.createdAt, flags: Order.descending)
        .build();

    if (limit > 0) {
      query.limit = limit;
      query.offset = offset;
    }

    final results = query.find();
    query.close();
    return results;
  }

  Transaction? getByUuid(String uuid) {
    final query = _box.query(Transaction_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// ✅ FIX #4: Fetch single transaction by ObjectBox ID.
  /// Digunakan oleh undoDelete() agar restore dari data terkini di DB.
  Transaction? getById(int id) => _box.get(id);

  bool softDelete(int id) {
    final tx = _box.get(id);
    if (tx != null) {
      tx.isDeleted = true;
      tx.updatedAt = DateTime.now();
      _box.put(tx);
      return true;
    }
    return false;
  }

  List<Transaction> getByPelangganId(int pelangganId) {
    Condition<Transaction> cond = Transaction_.isDeleted
        .equals(false)
        .and(Transaction_.pelanggan.equals(pelangganId));
        
    if (workshopId != null) {
      cond = cond.and(Transaction_.bengkelId.equals(workshopId!));
    }

    final query = _box
        .query(cond)
        .order(Transaction_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Hard delete (use with caution)
  bool delete(int id) {
    return _box.remove(id);
  }
}

