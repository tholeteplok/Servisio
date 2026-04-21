import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/stats_provider.dart';
import '../../../core/providers/pengaturan_provider.dart';

enum StatRange { today, week, month }

class PendapatanTab extends ConsumerStatefulWidget {
  final bool isPrivate;
  const PendapatanTab({super.key, required this.isPrivate});

  @override
  ConsumerState<PendapatanTab> createState() => _PendapatanTabState();
}

class _PendapatanTabState extends ConsumerState<PendapatanTab> {
  StatRange _selectedRange = StatRange.month;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRangeSelector(isDark, theme),
          const SizedBox(height: 20),
          _buildGoalProgress(settings, stats, isDark, theme),
          const SizedBox(height: 20),
          _buildSummaryCards(stats, isDark, theme),
          const SizedBox(height: 20),
          _buildPaymentBreakdown(stats, isDark, theme),
          const SizedBox(height: 20),
          _buildChartCard(stats, isDark, theme),
          const SizedBox(height: 16),
          _buildTrendInfo(stats, isDark, theme),
          const SizedBox(height: 48),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Pendapatan Bulanan',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                    Text(
                      widget.isPrivate
                          ? 'Rp ••••••'
                          : NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp',
                              decimalDigits: 0,
                            ).format(target),
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$percent%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                height: 12,
                width: MediaQuery.of(context).size.width * progress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            target > current
                ? 'Sisa Rp ${NumberFormat('#,###', 'id_ID').format(target - current)} lagi untuk mencapai target.'
                : 'Selamat! Target bulan ini sudah tercapai. 🎉',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
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
            label: '7 Hari',
            isSelected: _selectedRange == StatRange.week,
            onTap: () => setState(() => _selectedRange = StatRange.week),
            isDark: isDark,
            theme: theme,
          ),
          _RangeItem(
            label: 'Bulan Ini',
            isSelected: _selectedRange == StatRange.month,
            onTap: () => setState(() => _selectedRange = StatRange.month),
            isDark: isDark,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(TransactionStats stats, bool isDark, ThemeData theme) {
    final paymentData = _selectedRange == StatRange.today
        ? stats.paymentStatsToday
        : _selectedRange == StatRange.week
        ? stats.paymentStats7D
        : stats.paymentStats30D;

    if (paymentData.isEmpty) return const SizedBox.shrink();

    // Sort payment methods to put 'Tunai' first if exists
    final entries = paymentData.entries.toList()
      ..sort((a, b) {
        if (a.key.toLowerCase().contains('tunai')) return -1;
        if (b.key.toLowerCase().contains('tunai')) return 1;
        return 0;
      });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pelacak Arus Kas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              if (_selectedRange == StatRange.today)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Hari Ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedRange == StatRange.today
                ? 'Gunakan untuk mencocokkan uang fisik di laci.'
                : 'Ringkasan pemasukan berdasarkan metode bayar.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...entries.map((e) {
            final isCash = e.key.toLowerCase().contains('tunai');
            final isDigital =
                e.key.toLowerCase().contains('qris') ||
                e.key.toLowerCase().contains('transfer');
            final color = isCash
                ? theme.colorScheme.secondary
                : (isDigital ? AppColors.info : theme.colorScheme.primary);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCash
                            ? LucideIcons.banknote
                            : isDigital
                            ? (e.key.toLowerCase().contains('qris')
                                  ? LucideIcons.qrCode
                                  : LucideIcons.smartphone)
                            : LucideIcons.creditCard,
                        size: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            isCash ? 'Uang Fisik' : 'Pemasukan Digital',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.isPrivate
                          ? 'Rp ••••••'
                          : NumberFormat.currency(
                              symbol: 'Rp',
                              locale: 'id_ID',
                              decimalDigits: 0,
                            ).format(e.value),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(TransactionStats stats, bool isDark, ThemeData theme) {
    int revenue = _selectedRange == StatRange.today
        ? stats.todayPendapatan
        : _selectedRange == StatRange.week
        ? stats.weeklyPendapatan
        : stats.monthlyPendapatan;

    int profit = _selectedRange == StatRange.today
        ? stats.todayProfit
        : _selectedRange == StatRange.week
        ? stats.weeklyProfit
        : stats.monthlyProfit;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Pendapatan',
            value: revenue,
            isPrivate: widget.isPrivate,
            icon: LucideIcons.trendingUp,
            color: theme.colorScheme.primary,
            isDark: isDark,
            theme: theme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Estimasi Laba',
            value: profit,
            isPrivate: widget.isPrivate,
            icon: LucideIcons.coins,
            color: theme.colorScheme.secondary,
            isDark: isDark,
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(TransactionStats stats, bool isDark, ThemeData theme) {
    final trendData = _selectedRange == StatRange.today
        ? stats.hourlyTrend
        : (_selectedRange == StatRange.week
              ? stats.weeklyTrend
              : stats.dailyTrend);

    final rangeLabel = _selectedRange == StatRange.today
        ? 'Berdasarkan jam operasional'
        : (_selectedRange == StatRange.week
              ? '7 hari terakhir'
              : '30 hari terakhir');

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Pendapatan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    rangeLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.barChart3,
                      size: 10,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Chart',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 130, // Reduced from 220 (~40% reduction)
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(trendData),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.primary,
                    tooltipRoundedRadius: 10,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final data = trendData[groupIndex];
                      final labelText = _selectedRange == StatRange.today
                          ? '${data.label}:00'
                          : data.label;

                      return BarTooltipItem(
                        '$labelText\n',
                        GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: widget.isPrivate
                                ? 'Rp ••••••'
                                : NumberFormat.compactCurrency(
                                    symbol: 'Rp',
                                    locale: 'id_ID',
                                  ).format(rod.toY),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trendData[value.toInt()].label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white38 : Colors.black38,
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
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.revenue.toDouble(),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        width: _selectedRange == StatRange.week
                            ? 20 // Lebar lebih besar untuk 7 hari
                            : (_selectedRange == StatRange.today ? 4 : 6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _calculateMaxY(trendData),
                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        ),
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

  Widget _buildTrendInfo(TransactionStats stats, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.info,
              color: theme.colorScheme.primary,
              size: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Data grafik mencakup total transaksi servis dan penjualan yang telah berstatus lunas.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
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
    return max == 0 ? 100 : max * 1.25;
  }

  void _showTargetDialog(BuildContext context, WidgetRef ref, int currentTarget, ThemeData theme) {
    final controller = TextEditingController(text: currentTarget.toString());
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Atur Target Bulanan',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Target Pendapatan (Rp)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text) ?? 0;
                ref.read(settingsProvider.notifier).setMonthlyTarget(val);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Simpan',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
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
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int value;
  final bool isPrivate;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ThemeData theme;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.isPrivate,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isPrivate
                  ? 'Rp ••••••'
                  : NumberFormat.currency(
                      symbol: 'Rp',
                      locale: 'id_ID',
                      decimalDigits: 0,
                    ).format(value),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
