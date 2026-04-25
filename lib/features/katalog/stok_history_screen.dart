import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/stok_provider.dart';
import '../../domain/entities/stok.dart';
import '../../core/widgets/atelier_header.dart';
import '../../domain/entities/stok_history.dart';

class StokHistoryScreen extends ConsumerWidget {
  final Stok stok;
  const StokHistoryScreen({super.key, required this.stok});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(stokHistoryProvider(stok.uuid));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAtelierHeaderSub(
            title: AppStrings.catalog.headerHistory,
            subtitle: AppStrings.catalog.subheaderHistory(stok.nama),
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: _buildItemHeader(context, stok),
          ),
          if (historyAsync.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(theme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final log = historyAsync[historyAsync.length - 1 - index];
                    return _buildHistoryCard(context, theme, log);
                  },
                  childCount: historyAsync.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemHeader(BuildContext context, Stok item) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.nama,
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (item.sku != null)
            Text(
              '${AppStrings.catalog.labelSkuShort}: ${item.sku}',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat(context, AppStrings.catalog.labelStockCurrent, '${item.jumlah} ${AppStrings.catalog.unitPcs}'),
              _buildHeaderStat(context, AppStrings.catalog.labelCategoryCaps, item.kategori),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    ThemeData theme,
    StokHistory log,
  ) {
    final bool isAddition = log.quantityChange > 0;
    final color = isAddition ? theme.colorScheme.primary : theme.colorScheme.error;
    final icon = isAddition
        ? SolarIconsOutline.addSquare
        : SolarIconsOutline.minusSquare;

    String typeText = log.type;
    switch (log.type) {
      case 'INITIAL':
        typeText = AppStrings.catalog.historyInitial;
        break;
      case 'RESTOCK':
        typeText = AppStrings.catalog.historyRestock;
        break;
      case 'SALE':
        typeText = AppStrings.catalog.historySale;
        break;
      case 'MANUAL_ADJUSTMENT':
        typeText = AppStrings.catalog.historyAdjustment;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            typeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: color,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'dd MMM yyyy, HH:mm',
                            ).format(log.createdAt),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(icon, size: 20, color: color),
                          const SizedBox(width: 8),
                          Text(
                            '${isAddition ? '+' : ''}${log.quantityChange} ${AppStrings.catalog.unitPcs}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${log.previousQuantity} → ${log.newQuantity}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (log.note != null && log.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          log.note!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            SolarIconsOutline.history,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.catalog.emptyHistory,
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

