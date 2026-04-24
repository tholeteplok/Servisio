import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/stats_provider.dart';
import '../../../core/providers/pengaturan_provider.dart';

enum StatRange { today, week, month }

class RingkasanTab extends ConsumerStatefulWidget {
  final bool isPrivate;
  const RingkasanTab({super.key, required this.isPrivate});

  @override
  ConsumerState<RingkasanTab> createState() => _RingkasanTabState();
}

class _RingkasanTabState extends ConsumerState<RingkasanTab> {
  StatRange _selectedRange = StatRange.month;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(statsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRangeSelector(isDark, theme),
            const SizedBox(height: 24),
            
            // 1. Laba Bersih (Top)
            _buildMainProfitCard(stats, isDark, theme),
            const SizedBox(height: 24),

            // 2. Chart (Combined Income vs Expense)
            _buildCombinedChart(stats, isDark, theme),
            const SizedBox(height: 24),

            // 3. Cards (Pemasukan, Pengeluaran, Hutang)
            _buildThe3Cards(stats, isDark, theme),
            const SizedBox(height: 24),

            // 4. Target Pendapatan (Bottom)
            _buildGoalProgress(settings, stats, isDark, theme),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMainProfitCard(TransactionStats stats, bool isDark, ThemeData theme) {
    int revenue = _selectedRange == StatRange.today
        ? stats.todayPendapatan
        : _selectedRange == StatRange.week
        ? stats.weeklyPendapatan
        : stats.monthlyPendapatan;

    int expense = _selectedRange == StatRange.today
        ? stats.todayExpense
        : _selectedRange == StatRange.week
        ? stats.weeklyExpense
        : stats.monthlyExpense;

    int netProfit = revenue - expense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Estimasi Laba Bersih',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              widget.isPrivate
                  ? 'Rp ••••••'
                  : NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp',
                      decimalDigits: 0,
                    ).format(netProfit),
              style: GoogleFonts.manrope(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  netProfit >= 0 ? SolarIconsOutline.roundArrowUp : SolarIconsOutline.roundArrowDown,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  netProfit >= 0 ? 'Profit Stabil' : 'Defisit Kas',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedChart(TransactionStats stats, bool isDark, ThemeData theme) {
    final trendData = _selectedRange == StatRange.today
        ? stats.hourlyTrend
        : (_selectedRange == StatRange.week
              ? stats.weeklyTrend
              : stats.dailyTrend);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tren Bisnis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  _buildChartLegend('Masuk', theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  _buildChartLegend('Keluar', AppColors.error),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(trendData),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
                    tooltipRoundedRadius: 12,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final data = trendData[groupIndex];
                      final isRevenue = rodIndex == 0;
                      return BarTooltipItem(
                        '${data.label}\n',
                        GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        children: [
                          TextSpan(
                            text: NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp').format(rod.toY),
                            style: TextStyle(
                              color: isRevenue ? theme.colorScheme.primary : AppColors.error,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= trendData.length) return const SizedBox();
                        
                        // Optimize label density
                        if (_selectedRange == StatRange.today) {
                          if (value % 4 != 0) return const SizedBox();
                        } else if (_selectedRange == StatRange.month) {
                          if (value % 5 != 0) return const SizedBox();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            trendData[value.toInt()].label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: trendData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.revenue.toDouble(),
                        color: theme.colorScheme.primary,
                        width: _selectedRange == StatRange.today ? 6 : 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: e.value.expense.toDouble(),
                        color: AppColors.error.withValues(alpha: 0.8),
                        width: _selectedRange == StatRange.today ? 6 : 8,
                        borderRadius: BorderRadius.circular(4),
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

  Widget _buildThe3Cards(TransactionStats stats, bool isDark, ThemeData theme) {
    // Income data
    final revenue = _selectedRange == StatRange.today
        ? stats.todayPendapatan
        : _selectedRange == StatRange.week
            ? stats.weeklyPendapatan
            : stats.monthlyPendapatan;
    final payStats = _selectedRange == StatRange.today
        ? stats.paymentStatsToday
        : _selectedRange == StatRange.week
            ? stats.paymentStats7D
            : stats.paymentStats30D;

    // Expense data
    final expense = _selectedRange == StatRange.today
        ? stats.todayExpense
        : _selectedRange == StatRange.week
            ? stats.weeklyExpense
            : stats.monthlyExpense;
    final expOps = _selectedRange == StatRange.today
        ? stats.todayExpenseOperasional
        : _selectedRange == StatRange.week
            ? stats.weeklyExpenseOperasional
            : stats.monthlyExpenseOperasional;
    final expDebt = _selectedRange == StatRange.today
        ? stats.todayExpenseDebtPaid
        : _selectedRange == StatRange.week
            ? stats.weeklyExpenseDebtPaid
            : stats.monthlyExpenseDebtPaid;

    return Column(
      children: [
        _ExpandableStatCard(
          title: 'Total Pemasukan',
          value: revenue,
          icon: SolarIconsOutline.walletMoney,
          color: theme.colorScheme.primary,
          isPrivate: widget.isPrivate,
          expandItems: payStats.entries
              .where((e) => e.value > 0)
              .map((e) => _ExpandItem(
                    label: e.key,
                    value: e.value,
                    icon: _paymentIcon(e.key),
                  ))
              .toList(),
          emptyExpandLabel: 'Belum ada transaksi',
        ),
        const SizedBox(height: 12),
        _ExpandableStatCard(
          title: 'Total Pengeluaran',
          value: expense,
          icon: SolarIconsOutline.billList,
          color: AppColors.error,
          isPrivate: widget.isPrivate,
          expandItems: [
            _ExpandItem(
              label: 'Operasional',
              value: expOps,
              icon: SolarIconsOutline.settings,
            ),
            _ExpandItem(
              label: 'Cicilan Hutang',
              value: expDebt,
              icon: SolarIconsOutline.hourglass,
            ),
          ],
          emptyExpandLabel: 'Belum ada pengeluaran',
        ),
        const SizedBox(height: 12),
        // Static card – hutang outstanding
        _buildStatTile(
          title: 'Hutang Supplier',
          value: stats.totalDebt,
          icon: SolarIconsOutline.hourglass,
          color: Colors.orange,
          theme: theme,
          isPrivate: widget.isPrivate,
          subtitle: 'Sisa kewajiban yang belum lunas',
        ),
      ],
    );
  }

  IconData _paymentIcon(String method) {
    switch (method.toUpperCase()) {
      case 'QRIS': return SolarIconsOutline.qrCode;
      case 'TRANSFER': return SolarIconsOutline.cardTransfer;
      default: return SolarIconsOutline.banknote2;
    }
  }

  Widget _buildStatTile({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required bool isPrivate,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            isPrivate ? 'Rp •••' : NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp').format(value),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(
    SettingsState settings,
    TransactionStats stats,
    bool isDark,
    ThemeData theme,
  ) {
    final target = settings.monthlyTarget;
    final current = stats.monthlyPendapatan;
    final progress = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);
    final percent = (progress * 100).ceil();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Pendapatan Bulanan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => _showTargetDialog(context, ref, target, theme),
                icon: const Icon(LucideIcons.pencil, size: 14),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isPrivate
                    ? 'Rp ••••••'
                    : NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp',
                        decimalDigits: 0,
                      ).format(target),
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
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
            label: 'Hari Ini',
            isSelected: _selectedRange == StatRange.today,
            onTap: () => setState(() => _selectedRange = StatRange.today),
            isDark: isDark,
            theme: theme,
          ),
          _RangeItem(
            label: 'Mingguan',
            isSelected: _selectedRange == StatRange.week,
            onTap: () => setState(() => _selectedRange = StatRange.week),
            isDark: isDark,
            theme: theme,
          ),
          _RangeItem(
            label: 'Bulanan',
            isSelected: _selectedRange == StatRange.month,
            onTap: () => setState(() => _selectedRange = StatRange.month),
            isDark: isDark,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  double _calculateMaxY(List<TrendData> data) {
    double max = 100000;
    for (var d in data) {
      if (d.revenue > max) max = d.revenue.toDouble();
      if (d.expense > max) max = d.expense.toDouble();
    }
    return max * 1.2;
  }

  void _showTargetDialog(BuildContext context, WidgetRef ref, int current, ThemeData theme) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Target Bulanan'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            hintText: 'Contoh: 50000000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              ref.read(settingsProvider.notifier).setMonthlyTarget(val);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
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
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Data model for expandable items
// =============================================================================

class _ExpandItem {
  final String label;
  final int value;
  final IconData icon;
  const _ExpandItem({required this.label, required this.value, required this.icon});
}

// =============================================================================
// Expandable Stat Card
// =============================================================================

class _ExpandableStatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool isPrivate;
  final List<_ExpandItem> expandItems;
  final String emptyExpandLabel;

  const _ExpandableStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isPrivate,
    required this.expandItems,
    required this.emptyExpandLabel,
  });

  @override
  State<_ExpandableStatCard> createState() => _ExpandableStatCardState();
}

class _ExpandableStatCardState extends State<_ExpandableStatCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final fmtCompact = NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp');

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _expanded ? widget.color.withValues(alpha: 0.25) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        widget.isPrivate ? 'Rp ...' : fmtCompact.format(widget.value),
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                RotationTransition(
                  turns: _rotate,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(SolarIconsOutline.altArrowDown, size: 14, color: widget.color),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        children: [
                          Divider(color: theme.colorScheme.outlineVariant, height: 1),
                          const SizedBox(height: 12),
                          if (widget.expandItems.isEmpty)
                            Text(
                              widget.emptyExpandLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            )
                          else
                            ...widget.expandItems.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Icon(item.icon, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                    const SizedBox(width: 10),
                                    Text(
                                      item.label,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    const Spacer(),
                                    Text(
                                      widget.isPrivate ? 'Rp ...' : fmt.format(item.value),
                                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
