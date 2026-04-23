import '../../objectbox.g.dart';
import '../../domain/entities/expense_category.dart';

class ExpenseCategoryRepository {
  final Box<ExpenseCategory> _box;

  ExpenseCategoryRepository(this._box);

  /// Ambil semua kategori milik bengkel (default + kustom).
  List<ExpenseCategory> getAll(String bengkelId) {
    final query = _box
        .query(ExpenseCategory_.bengkelId.equals(bengkelId))
        .order(ExpenseCategory_.isDefault, flags: Order.descending)
        .order(ExpenseCategory_.name)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Simpan atau update kategori.
  int save(ExpenseCategory category) => _box.put(category);

  /// Hapus kategori (hanya yang bukan default).
  bool delete(int id) {
    final cat = _box.get(id);
    if (cat == null || cat.isDefault) return false;
    _box.remove(id);
    return true;
  }

  /// Cek apakah logicKey sudah ada untuk bengkel ini.
  bool existsByLogicKey(String logicKey, String bengkelId) {
    final query = _box
        .query(ExpenseCategory_.logicKey
            .equals(logicKey)
            .and(ExpenseCategory_.bengkelId.equals(bengkelId)))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  /// Seed kategori default jika belum ada data untuk bengkel ini.
  void seedDefaults(String bengkelId) {
    final existing = getAll(bengkelId);
    if (existing.isNotEmpty) return;

    final defaults = ExpenseCategory.defaultCategories(bengkelId);
    _box.putMany(defaults);
  }
}
