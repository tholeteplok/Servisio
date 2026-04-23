import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/stats_provider.dart';
import '../widgets/expense_category_chart.dart';

enum ExpenseRange { today, week, month }

class PengeluaranTab extends ConsumerStatefulWidget {
  const PengeluaranTab({super.key});

  @override
  ConsumerState<PengeluaranTab> createState() => _PengeluaranTabState();
}

class _PengeluaranTabState extends ConsumerState<PengeluaranTab> {
  ExpenseRange _selectedRange = ExpenseRange.month;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRangeSelector(isDark, theme),
          const SizedBox(height: 20),
          _buildSummaryCards(stats, isDark, theme),
          const SizedBox(height: 20),
          _buildCategoryChart(stats, isDark, theme),
          const SizedBox(height: 20),
          _buildTrendChart(stats, isDark, theme),
          const SizedBox(height: 20),
          _buildCategoryList(stats, isDark, theme),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _RangeItem(
            label: AppStrings.stats.today,
            isSelected: _selectedRange == ExpenseRange.today,
            onTap: () => setState(() => _selectedRange = ExpenseRange.today),
            isDark: isDark,
            theme: theme,
          ),
          _RangeItem(
            label: AppStrings.stats.week,
            isSelected: _selectedRange == ExpenseRange.week,
            onTap: () => setState(() => _selectedRange = ExpenseRange.week),
            isDark: isDark,
            theme: theme,
          ),
          _RangeItem(
            label: AppStrings.stats.month,
            isSelected: _selectedRange == ExpenseRange.month,
            onTap: () => setState(() => _selectedRange = ExpenseRange.month),
            isDark: isDark,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(TransactionStats stats, bool isDark, ThemeData theme) {
    int total = _selectedRange == ExpenseRange.today
        ? stats.todayExpense
        : (_selectedRange == ExpenseRange.week
            ? stats.weeklyExpense
            : stats.monthlyExpense);

    String secondaryTitle = AppStrings.stats.dailyAvgExpense;
    double avg = 0;
    if (_selectedRange == ExpenseRange.month) {
      final days = DateTime.now().day;
      avg = total / (days > 0 ? days : 1);
    } else if (_selectedRange == ExpenseRange.week) {
      avg = total / 7;
    } else {
      secondaryTitle = AppStrings.stats.yesterdayExpense;
      avg = 0; 
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: AppStrings.stats.totalExpense,
            value: total.toDouble(),
            icon: LucideIcons.trendingDown,
            color: Colors.redAccent,
            theme: theme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: secondaryTitle,
            value: avg,
            icon: LucideIcons.calculator,
            color: Colors.orangeAccent,
            theme: theme,
            isCurrency: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChart(TransactionStats stats, bool isDark, ThemeData theme) {
    final data = _selectedRange == ExpenseRange.today
        ? stats.expenseByCategoryToday
        : (_selectedRange == ExpenseRange.week
            ? stats.expenseByCategory7D
            : stats.expenseByCategory30D);

    if (data.isEmpty) {
      return _buildEmptyState(theme, AppStrings.stats.noExpenseData);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.stats.expenseAllocation,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: ExpenseCategoryChart(data: data),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(TransactionStats stats, bool isDark, ThemeData theme) {
    if (_selectedRange == ExpenseRange.today) return const SizedBox.shrink();

    final trendData = stats.expenseTrendWeekly;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.stats.expenseTrend,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(trendData),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trendData[value.toInt()].label,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: trendData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.revenue.toDouble(),
                        color: Colors.redAccent.withValues(alpha: 0.7),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(TransactionStats stats, bool isDark, ThemeData theme) {
    final data = _selectedRange == ExpenseRange.today
        ? stats.expenseByCategoryToday
        : (_selectedRange == ExpenseRange.week
            ? stats.expenseByCategory7D
            : stats.expenseByCategory30D);

    if (data.isEmpty) return const SizedBox.shrink();

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.stats.expenseDetailPerCategory,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedEntries.map((e) => _CategoryItem(
              label: e.key,
              amount: e.value,
              theme: theme,
            )),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.receipt, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY(List<TrendData> trend) {
    if (trend.isEmpty) return 100;
    double max = 0;
    for (var d in trend) {
      if (d.revenue > max) max = d.revenue.toDouble();
    }
    return max == 0 ? 100 : max * 1.2;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final bool isCurrency;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              NumberFormat.currency(
                symbol: 'Rp',
                locale: 'id_ID',
                decimalDigits: 0,
              ).format(value),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String label;
  final int amount;
  final ThemeData theme;

  const _CategoryItem({
    required this.label,
    required this.amount,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            NumberFormat.currency(
              symbol: 'Rp',
              locale: 'id_ID',
              decimalDigits: 0,
            ).format(amount),
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final ThemeData theme;

  const _RangeItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}
