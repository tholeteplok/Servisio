import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../domain/entities/expense.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_summary_card.dart';
import '../expense/expense_detail_screen.dart';

class ExpenseHistoryTab extends ConsumerStatefulWidget {
  const ExpenseHistoryTab({super.key});

  @override
  ConsumerState<ExpenseHistoryTab> createState() =>
      _ExpenseHistoryTabState();
}

class _ExpenseHistoryTabState extends ConsumerState<ExpenseHistoryTab> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bengkelId = ref.watch(settingsProvider).bengkelId;
    final categories = ref.watch(expenseCategoryListProvider(bengkelId));

    final expensesAsync = ref.watch(expenseListProvider(bengkelId));
    final total = ref.watch(totalExpenseThisMonthProvider(bengkelId));
    final avgDaily = ref.watch(avgDailyExpenseProvider(bengkelId));
    final count = ref.watch(expenseCountThisMonthProvider(bengkelId));
    final monthlyExpenses = ref.watch(
      expenseByMonthProvider(
        (bengkelId: bengkelId, year: _selectedYear, month: _selectedMonth),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(expenseListProvider(bengkelId)),
      color: theme.colorScheme.primary,
      displacement: 100,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Summary card
          SliverToBoxAdapter(
            child: ExpenseSummaryCard(
              totalAmount: total,
              transactionCount: count,
              avgDailyAmount: avgDaily,
              currentMonth: _selectedMonth,
              currentYear: _selectedYear,
            ),
          ),

          // Month selector
          SliverToBoxAdapter(
            child: _MonthSelector(
              selectedMonth: _selectedMonth,
              selectedYear: _selectedYear,
              onChanged: (month, year) =>
                  setState(() {
                    _selectedMonth = month;
                    _selectedYear = year;
                  }),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // List
          expensesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Gagal memuat data: $e',
                    style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
            data: (_) {
              if (monthlyExpenses.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyExpenseState(
                    bengkelId: bengkelId,
                    onAdded: () =>
                        ref.invalidate(expenseListProvider(bengkelId)),
                  ),
                );
              }

              // Group by date
              final grouped = _groupByDate(monthlyExpenses);
              final dates = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return SliverPadding(
                padding: const EdgeInsets.only(top: 0, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final date = dates[i];
                      final items = grouped[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 20, bottom: 12, left: 24),
                            child: Text(
                              date,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          ...items.map(
                            (exp) => _ExpenseCardWrapper(
                              expense: exp,
                              categories: categories,
                              bengkelId: bengkelId,
                              onRefresh: () => ref
                                  .invalidate(
                                    expenseListProvider(bengkelId),
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                    childCount: dates.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, List<Expense>> _groupByDate(List<Expense> expenses) {
    final result = <String, List<Expense>>{};
    for (final e in expenses) {
      final key = _formatDateKey(e.date);
      result.putIfAbsent(key, () => []).add(e);
    }
    return result;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hari ini';
    if (d == today.subtract(const Duration(days: 1))) return 'Kemarin';
    // Format: "Senin, 21 Apr"
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final void Function(int month, int year) onChanged;

  const _MonthSelector({
    required this.selectedMonth,
    required this.selectedYear,
    required this.onChanged,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 6, // last 6 months
        itemBuilder: (ctx, i) {
          // i=0 is current month, i=5 is 5 months ago
          var month = now.month - i;
          var year = now.year;
          while (month <= 0) {
            month += 12;
            year--;
          }
          final label = _months[month - 1];
          final isSelected =
              month == selectedMonth && year == selectedYear;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(month, year),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline
                            .withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  i == 0 ? 'Bulan ini' : label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseCardWrapper extends ConsumerWidget {
  final Expense expense;
  final List categories;
  final String bengkelId;
  final VoidCallback onRefresh;

  const _ExpenseCardWrapper({
    required this.expense,
    required this.categories,
    required this.bengkelId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpenseCard(
        expense: expense,
        categories: List.from(categories),
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expense: expense),
            ),
          );
          if (result == true) onRefresh();
        },
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Hapus Pengeluaran?',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Hapus'),
                ),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            await ref
                .read(expenseListProvider(bengkelId).notifier)
                .deleteExpense(expense.id);
            onRefresh();
          }
        },
    );
  }
}

class _EmptyExpenseState extends StatelessWidget {
  final String bengkelId;
  final VoidCallback onAdded;

  const _EmptyExpenseState({required this.bengkelId, required this.onAdded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              SolarIconsOutline.billList,
              size: 72,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada pengeluaran',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Catat pengeluaran dengan scan nota\natau input manual',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

