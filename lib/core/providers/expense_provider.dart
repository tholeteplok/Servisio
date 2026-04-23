import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/expense_category_repository.dart';
import 'objectbox_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers: Repository
// ─────────────────────────────────────────────────────────────────────────────

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(dbProvider);
  return ExpenseRepository(db.expenseBox);
});

final expenseCategoryRepositoryProvider =
    Provider<ExpenseCategoryRepository>((ref) {
  final db = ref.watch(dbProvider);
  return ExpenseCategoryRepository(db.expenseCategoryBox);
});

// ─────────────────────────────────────────────────────────────────────────────
// Providers: Category
// ─────────────────────────────────────────────────────────────────────────────

/// Daftar semua kategori pengeluaran (default + kustom) untuk bengkel aktif.
final expenseCategoryListProvider =
    Provider.family<List<ExpenseCategory>, String>((ref, bengkelId) {
  final repo = ref.watch(expenseCategoryRepositoryProvider);
  // Seed jika belum ada data
  repo.seedDefaults(bengkelId);
  return repo.getAll(bengkelId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Notifier: Expense List
// ─────────────────────────────────────────────────────────────────────────────

class ExpenseListNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final ExpenseRepository _repo;
  final String bengkelId;

  ExpenseListNotifier(this._repo, this.bengkelId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() {
    try {
      final expenses = _repo.getAll(bengkelId);
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addExpense(Expense expense) async {
    _repo.save(expense);
    _load();
  }

  Future<void> updateExpense(Expense expense) async {
    _repo.save(expense);
    _load();
  }

  Future<bool> deleteExpense(int id) async {
    final result = _repo.softDelete(id);
    if (result) _load();
    return result;
  }

  void refresh() => _load();
}

final expenseListProvider = StateNotifierProvider.family<ExpenseListNotifier,
    AsyncValue<List<Expense>>, String>((ref, bengkelId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return ExpenseListNotifier(repo, bengkelId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Providers: Filtered & Reactive
// ─────────────────────────────────────────────────────────────────────────────

/// Pengeluaran berdasarkan bulan & tahun tertentu.
/// Menjadi reaktif karena mengamati [expenseListProvider].
final expenseByMonthProvider = Provider.family<List<Expense>,
    ({String bengkelId, int year, int month})>((ref, params) {
  final allExpensesAsync = ref.watch(expenseListProvider(params.bengkelId));

  return allExpensesAsync.maybeWhen(
    data: (expenses) => expenses.where((e) {
      return e.date.year == params.year &&
          e.date.month == params.month &&
          !e.isDeleted;
    }).toList(),
    orElse: () => [],
  );
});

/// Total pengeluaran bulan ini (rupiah).
/// Menjadi reaktif karena mengamati [expenseByMonthProvider].
final totalExpenseThisMonthProvider =
    Provider.family<int, String>((ref, bengkelId) {
  final now = DateTime.now();
  final expenses = ref.watch(
    expenseByMonthProvider(
      (bengkelId: bengkelId, year: now.year, month: now.month),
    ),
  );
  return expenses.fold(0, (sum, e) => sum + e.amount);
});

/// Total pengeluaran untuk bulan/tahun tertentu.
final totalExpenseByMonthProvider = Provider.family<int,
    ({String bengkelId, int year, int month})>((ref, params) {
  final expenses = ref.watch(expenseByMonthProvider(params));
  return expenses.fold(0, (sum, e) => sum + e.amount);
});

/// Rata-rata pengeluaran harian bulan ini.
final avgDailyExpenseProvider =
    Provider.family<double, String>((ref, bengkelId) {
  final now = DateTime.now();
  final total = ref.watch(totalExpenseThisMonthProvider(bengkelId));
  final daysElapsed = now.day;
  if (daysElapsed == 0) return 0;
  return total / daysElapsed;
});

/// Jumlah transaksi pengeluaran bulan ini.
final expenseCountThisMonthProvider =
    Provider.family<int, String>((ref, bengkelId) {
  final now = DateTime.now();
  final expenses = ref.watch(
    expenseByMonthProvider(
      (bengkelId: bengkelId, year: now.year, month: now.month),
    ),
  );
  return expenses.length;
});
