import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/stats_provider.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../core/providers/sale_providers.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/financial_export_helper.dart';
import '../../../core/services/session_manager.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRangeSelector(isDark, theme),
          const SizedBox(height: 20),
          _buildDateRangeSelector(theme),
          const SizedBox(height: 24),
          _buildSummaryCards(stats, isDark, theme),
          const SizedBox(height: 24),
          _buildCategoryChart(stats, isDark, theme),
          const SizedBox(height: 24),
          _buildTrendChart(stats, isDark, theme),
          const SizedBox(height: 24),
          _buildDownloadButton(theme),
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

  Widget _buildDateRangeSelector(ThemeData theme) {
    // Current date range based on selected range
    String dateRange = '';
    final now = DateTime.now();
    final format = DateFormat('d MMM yyyy', 'id_ID');
    
    if (_selectedRange == ExpenseRange.today) {
      dateRange = format.format(now);
    } else if (_selectedRange == ExpenseRange.week) {
      final start = now.subtract(const Duration(days: 7));
      dateRange = '${format.format(start)} - ${format.format(now)}';
    } else {
      final start = DateTime(now.year, now.month, 1);
      dateRange = '${format.format(start)} - ${format.format(now)}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                dateRange,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Future: Show Date Range Picker
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      'Ubah',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
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

    double avg = 0;
    if (_selectedRange == ExpenseRange.month) {
      final days = DateTime.now().day;
      avg = total / (days > 0 ? days : 1);
    } else if (_selectedRange == ExpenseRange.week) {
      avg = total / 7;
    } else {
      'Analisis Pengeluaran';
      avg = 0; 
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'TOTAL PENGELUARAN',
            value: total.toDouble(),
            icon: LucideIcons.trendingDown,
            color: AppColors.error,
            theme: theme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'RATA-RATA HARIAN',
            value: avg,
            icon: LucideIcons.calculator,
            color: AppColors.error,
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alokasi Pengeluaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Icon(LucideIcons.info, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tren Pengeluaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+12%', // Simulated or calculated trend
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(trendData),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.onSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberFormat.compactCurrency(symbol: 'Rp', locale: 'id_ID').format(rod.toY),
                        GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      );
                    },
                  ),
                ),
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
                              trendData[value.toInt()].label.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9, 
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                  final isToday = e.key == trendData.length - 1; // Assuming last item is today
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.revenue.toDouble(),
                        color: isToday 
                            ? AppColors.error 
                            : AppColors.error.withValues(alpha: 0.3),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _calculateMaxY(trendData),
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 MAR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant)),
              Text('12 MAR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant)),
              Text('26 MAR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(ThemeData theme) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _handleExport(context, ref),
        icon: const Icon(SolarIconsOutline.download, size: 18),
        label: const Text('Unduh Laporan'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final transactionsAsync = ref.read(transactionListProvider);
    final salesAsync = ref.read(saleListProvider);
    final bengkelId = ref.read(bengkelIdProvider);
    
    if (bengkelId == null) return;
    
    final expensesAsync = ref.read(expenseListProvider(bengkelId));
    final sessionManager = ref.read(sessionManagerProvider);

    // Ensure all data is loaded
    if (transactionsAsync is! AsyncData || 
        salesAsync is! AsyncData || 
        expensesAsync is! AsyncData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon tunggu, data sedang dimuat...')),
      );
      return;
    }

    try {
      final workshop = sessionManager.availableWorkshops.firstWhere(
        (w) => w.id == bengkelId,
        orElse: () => const WorkshopInfo(id: '', name: 'Bengkel', ownerId: ''),
      );

      await FinancialExportHelper.generateFinancialReport(
        transactions: transactionsAsync.value ?? [],
        sales: salesAsync.value ?? [],
        expenses: expensesAsync.value ?? [],
        bengkelName: workshop.name,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor: $e')),
        );
      }
    }
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}

