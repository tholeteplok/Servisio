import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/providers/stats_provider.dart';

class PemasukanTab extends ConsumerStatefulWidget {
  const PemasukanTab({super.key});

  @override
  ConsumerState<PemasukanTab> createState() => _PemasukanTabState();
}

class _PemasukanTabState extends ConsumerState<PemasukanTab> {
  int _selectedSegment = 0; // 0 for Layanan, 1 for Barang

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Selection Header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Performa Bisnis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    _buildSegmentSelector(theme, isDark),
                  ],
                ),
                const SizedBox(height: 16),
                _buildQuickStats(stats, theme, isDark),
              ],
            ),
          ),
        ),

        // ── Ranking Title ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Icon(
                  _selectedSegment == 0 ? SolarIconsOutline.settings : SolarIconsOutline.box,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedSegment == 0 ? 'Layanan Terlaris' : 'Barang Terpopuler',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Performance List ──
        _selectedSegment == 0
            ? _buildSliverList(stats.topServices, theme, SolarIconsOutline.settings, 'layanan', isDark)
            : _buildSliverList(stats.topProducts, theme, SolarIconsOutline.box, 'barang', isDark),
        
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildSegmentSelector(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton('Layanan', 0, theme, isDark),
          _buildSegmentButton('Barang', 1, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, int index, ThemeData theme, bool isDark) {
    final isSelected = _selectedSegment == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSegment = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white : theme.colorScheme.primary) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected && !isDark ? [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isSelected 
                ? (isDark ? Colors.black : Colors.white) 
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(TransactionStats stats, ThemeData theme, bool isDark) {
    final totalSales = _selectedSegment == 0 
        ? stats.topServices.fold<int>(0, (sum, item) => sum + item.count)
        : stats.topProducts.fold<int>(0, (sum, item) => sum + item.count);
    
    final totalRev = _selectedSegment == 0
        ? stats.topServices.fold<double>(0, (sum, item) => sum + item.revenue)
        : stats.topProducts.fold<double>(0, (sum, item) => sum + item.revenue);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volume Transaksi',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '$totalSales Unit',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Estimasi Omzet',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(totalRev),
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverList(List<TopItem> items, ThemeData theme, IconData emptyIcon, String type, bool isDark) {
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'Belum ada data $type',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _buildPremiumItemCard(item, index + 1, theme, isDark);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildPremiumItemCard(TopItem item, int rank, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rank <= 3 
              ? theme.colorScheme.primary.withValues(alpha: 0.1) 
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: !isDark ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Row(
        children: [
          // Rank Indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3 
                  ? theme.colorScheme.primary.withValues(alpha: 0.1) 
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.count} Terjual',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Revenue
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(item.revenue),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Pemasukan',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

