import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/history_provider.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../home/transaction_detail_screen.dart';
import '../../main/responsive_layout_builder.dart';

/// Tab transaksi dari HistoryScreen yang dipindah ke sini
/// agar HistoryScreen bisa menjadi shell TabBar yang bersih.
class TransactionHistoryTab extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final void Function() onFilterTap;

  const TransactionHistoryTab({
    super.key,
    required this.searchController,
    required this.onFilterTap,
  });

  @override
  ConsumerState<TransactionHistoryTab> createState() =>
      _TransactionHistoryTabState();
}

class _TransactionHistoryTabState
    extends ConsumerState<TransactionHistoryTab> {
  @override
  Widget build(BuildContext context) {
    ref.listen(historySearchQueryProvider, (previous, next) {
      if (next.isEmpty && widget.searchController.text.isNotEmpty) {
        widget.searchController.clear();
      }
    });

    final historyState = ref.watch(historyListProvider);
    final searchQuery =
        ref.watch(historySearchQueryProvider).toLowerCase();
    final theme = Theme.of(context);

    final filteredItems = searchQuery.isEmpty
        ? historyState.items
        : historyState.items.where((item) {
            return item.title.toLowerCase().contains(searchQuery) ||
                item.subtitle.toLowerCase().contains(searchQuery) ||
                item.type.toLowerCase().contains(searchQuery) ||
                item.status.toLowerCase().contains(searchQuery);
          }).toList();

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(historyListProvider.notifier).loadInitial(),
      color: theme.colorScheme.primary,
      displacement: 100,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _buildActiveFilterChips(ref, context),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (filteredItems.isEmpty && !historyState.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      searchQuery.isEmpty
                          ? SolarIconsOutline.history
                          : SolarIconsOutline.magnifier,
                      size: 64,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchQuery.isEmpty
                          ? AppStrings.history.noTransactions
                          : AppStrings.history.noResultsFor(searchQuery),
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 0, bottom: 100),
              sliver: SliverList(
                key: const ValueKey('history_list'),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filteredItems[index];
                    return _HistoryCard(item: item);
                  },
                  childCount: filteredItems.length,
                ),
              ),
            ),
          if (historyState.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(WidgetRef ref, BuildContext context) {
    final filter = ref.watch(historyFilterNotifierProvider);
    final theme = Theme.of(context);
    if (filter.dateRange == null &&
        filter.type == 'ALL' &&
        filter.paymentMethod == 'ALL') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (filter.dateRange != null)
              _buildChip(
                '${DateFormat('dd MMM').format(filter.dateRange!.start)} - ${DateFormat('dd MMM').format(filter.dateRange!.end)}',
                () => ref
                    .read(historyFilterNotifierProvider.notifier)
                    .update((s) => s.copyWith(clearDateRange: true)),
                theme,
              ),
            if (filter.type != 'ALL')
              _buildChip(
                filter.type,
                () => ref
                    .read(historyFilterNotifierProvider.notifier)
                    .update((s) => s.copyWith(type: 'ALL')),
                theme,
              ),
            if (filter.paymentMethod != 'ALL')
              _buildChip(
                filter.paymentMethod,
                () => ref
                    .read(historyFilterNotifierProvider.notifier)
                    .update((s) => s.copyWith(paymentMethod: 'ALL')),
                theme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
      String label, VoidCallback onDeleted, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDeleted,
            child: Icon(Icons.close,
                color: theme.colorScheme.onPrimaryContainer, size: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History Card — dipindah dari _HistoryCard di history_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends ConsumerWidget {
  final HistoryItemData item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isService = item.type == 'SERVICE';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: isService
            ? () {
                final container = ProviderScope.containerOf(context);
                final trxListAsync = container.read(transactionListProvider);
                final trxList = trxListAsync.value ?? [];
                try {
                  final trx = trxList.firstWhere((t) => t.uuid == item.id);
                  AdaptiveNavigator.push(
                    context: context,
                    ref: ref,
                    detailContent: TransactionDetailScreen(transaction: trx),
                    routeBuilder: () => TransactionDetailScreen(transaction: trx),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.history.detailNotFound)),
                  );
                }
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (ID & Status)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(SolarIconsOutline.hashtag, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        item.trxNumber.split('-').last.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (item.status.toUpperCase() == 'LUNAS' 
                              ? const Color(0xFF10B981) 
                              : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.status,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: (item.status.toUpperCase() == 'LUNAS' 
                            ? const Color(0xFF10B981) 
                            : const Color(0xFFF59E0B)),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Body (Title & Price)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(SolarIconsOutline.calendar, size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd MMMM yyyy, HH:mm').format(item.date),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp',
                      decimalDigits: 0,
                    ).format(item.amount),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF6366F1), // Indigo accent
                    ),
                  ),
                ],
              ),
              
              // 3. Footer / Note section (if applicable)
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isService ? SolarIconsOutline.notes : SolarIconsOutline.box,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.subtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Bottom Sheet — dipindah dari history_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
class HistoryFilterBottomSheet extends ConsumerWidget {
  const HistoryFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterNotifierProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.history.filterTitle,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w900),
              ),
              TextButton(
                onPressed: () => ref
                    .read(historyFilterNotifierProvider.notifier)
                    .setFilter(HistoryFilter()),
                child: Text(AppStrings.common.reset),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFilterLabel(AppStrings.history.selectDate, theme),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime.now(),
                initialDateRange: filter.dateRange,
              );
              if (range != null) {
                ref
                    .read(historyFilterNotifierProvider.notifier)
                    .update((s) => s.copyWith(dateRange: range));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(SolarIconsOutline.calendar,
                      color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    filter.dateRange == null
                        ? AppStrings.history.selectDate
                        : '${DateFormat('dd/MM/yyyy').format(filter.dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(filter.dateRange!.end)}',
                    style: TextStyle(
                      color: filter.dateRange == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildFilterLabel(
              AppStrings.history.transactionType, theme),
          const SizedBox(height: 8),
          _buildChoiceRow(
            ref,
            ['ALL', 'SERVIS', 'PRODUK'],
            filter.type,
            (val) => ref
                .read(historyFilterNotifierProvider.notifier)
                .update((s) => s.copyWith(type: val)),
            theme,
          ),
          const SizedBox(height: 24),
          _buildFilterLabel(AppStrings.history.paymentMethod, theme),
          const SizedBox(height: 8),
          _buildChoiceRow(
            ref,
            ['ALL', 'Tunai', 'QRIS', 'Transfer'],
            filter.paymentMethod,
            (val) => ref
                .read(historyFilterNotifierProvider.notifier)
                .update((s) => s.copyWith(paymentMethod: val)),
            theme,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                AppStrings.history.applyFilter,
                style:
                    const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String label, ThemeData theme) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildChoiceRow(
    WidgetRef ref,
    List<String> options,
    String selected,
    Function(String) onSelected,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt == 'ALL'
                  ? AppStrings.history.all
                  : (opt == 'SERVIS'
                      ? AppStrings.history.typeService
                      : (opt == 'PRODUK'
                          ? AppStrings.history.typeProduct
                          : opt))),
              selected: isSelected,
              onSelected: (val) => val ? onSelected(opt) : null,
              selectedColor:
                  theme.colorScheme.primary.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
