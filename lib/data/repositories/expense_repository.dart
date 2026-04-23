import '../../objectbox.g.dart';
import '../../domain/entities/expense.dart';

class ExpenseRepository {
  final Box<Expense> _box;

  ExpenseRepository(this._box);

  /// Simpan atau update pengeluaran. Returns ObjectBox ID.
  int save(Expense expense) {
    expense.updatedAt = DateTime.now();
    return _box.put(expense);
  }

  /// Simpan banyak sekaligus.
  List<int> saveMany(List<Expense> expenses) {
    for (final e in expenses) {
      e.updatedAt = DateTime.now();
    }
    return _box.putMany(expenses);
  }

  /// Ambil semua pengeluaran aktif untuk bengkel, diurutkan terbaru.
  List<Expense> getAll(String bengkelId) {
    final query = _box
        .query(Expense_.isDeleted
            .equals(false)
            .and(Expense_.bengkelId.equals(bengkelId)))
        .order(Expense_.date, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Ambil berdasarkan ID ObjectBox.
  Expense? getById(int id) => _box.get(id);

  /// Ambil berdasarkan UUID (untuk sync).
  Expense? getByUuid(String uuid) {
    final query = _box.query(Expense_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Ambil pengeluaran berdasarkan bulan & tahun.
  List<Expense> getByMonth(String bengkelId, int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    final query = _box
        .query(Expense_.isDeleted
            .equals(false)
            .and(Expense_.bengkelId.equals(bengkelId))
            .and(Expense_.date.between(
                start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)))
        .order(Expense_.date, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Ambil pengeluaran berdasarkan kategori.
  List<Expense> getByCategory(String bengkelId, String categoryKey) {
    final query = _box
        .query(Expense_.isDeleted
            .equals(false)
            .and(Expense_.bengkelId.equals(bengkelId))
            .and(Expense_.category.equals(categoryKey)))
        .order(Expense_.date, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Soft delete (data tetap ada, hanya ditandai terhapus).
  bool softDelete(int id) {
    final expense = _box.get(id);
    if (expense == null) return false;
    expense.isDeleted = true;
    expense.updatedAt = DateTime.now();
    _box.put(expense);
    return true;
  }

  /// Total pengeluaran bulan ini.
  int totalThisMonth(String bengkelId) {
    final now = DateTime.now();
    final expenses = getByMonth(bengkelId, now.year, now.month);
    return expenses.fold(0, (sum, e) => sum + e.amount);
  }

  /// Ambil semua record pembayaran (cicilan) untuk sebuah hutang induk.
  List<Expense> getPaymentsForDebt(int parentExpenseId) {
    final query = _box
        .query(Expense_.parentExpense
            .equals(parentExpenseId)
            .and(Expense_.isDeleted.equals(false)))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Ambil semua hutang untuk supplier tertentu.
  List<Expense> getDebtsBySupplier(String bengkelId, int supplierId) {
    final query = _box
        .query(Expense_.bengkelId
            .equals(bengkelId)
            .and(Expense_.supplier.equals(supplierId))
            .and(Expense_.debtStatus.notNull())
            .and(Expense_.isDeleted.equals(false)))
        .build();
    final results = query.find();
    query.close();
    return results;
  }
}
