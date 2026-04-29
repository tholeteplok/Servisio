import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/providers/history_provider.dart';
import '../../core/constants/app_strings.dart';
import 'tabs/transaction_history_tab.dart';
import 'tabs/expense_history_tab.dart';
import '../../core/widgets/atelier_header.dart';

// [x] Refactor HistoryScreen for floating TabBar
// [ ] Implement premium _HistoryCard in transaction_history_tab.dart
// [ ] Update ExpenseCard for visual consistency
// [ ] Final polish and padding verification
// [ ] Run flutter analyze and fix any errors
// [ ] Update CHANGELOG_SERVISIO.md

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(historyActiveTabProvider);
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(historyActiveTabProvider.notifier).set(_tabController.index);
        _onTabChanged();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      ref.read(historySearchQueryProvider.notifier).set('');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // 1. Header & TabBar Section
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHeader(context),
              Positioned(
                bottom: -28,
                left: 0,
                right: 0,
                child: _buildTabBar(theme),
              ),
            ],
          ),

          // 2. Content Spacer
          const SizedBox(height: 32),

          // 3. Main Content
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200 &&
                    _tabController.index == 0) {
                  ref.read(historyListProvider.notifier).loadMore();
                }
                return false;
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  TransactionHistoryTab(
                    searchController: _searchController,
                    onFilterTap: () => _showFilterBottomSheet(context),
                  ),
                  const ExpenseHistoryTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AtelierHeader(
      title: AppStrings.history.title,
      subtitle: '', 
      showBackButton: false,
      showWorkshopSelector: false,
      searchController: _searchController,
      searchHint: _tabController.index == 0
          ? AppStrings.history.searchHint
          : 'Cari pengeluaran...',
      onSearchChanged: (v) {
        ref.read(historySearchQueryProvider.notifier).set(v);
      },
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      bottomPadding: 48, // Adjusted for the floating TabBar
      actions: [
        if (_tabController.index == 0) ...[
          IconButton(
            onPressed: () => _showFilterBottomSheet(context),
            icon: Icon(
              ref.watch(historyFilterNotifierProvider).dateRange != null ||
                      ref.watch(historyFilterNotifierProvider).type != 'ALL' ||
                      ref.watch(historyFilterNotifierProvider).paymentMethod != 'ALL'
                  ? SolarIconsBold.filter
                  : SolarIconsOutline.filter,
              color: Colors.white,
              size: 20,
            ),
            tooltip: AppStrings.common.filter,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          onPressed: () => ref.read(historyListProvider.notifier).loadInitial(),
          icon: const Icon(SolarIconsOutline.refresh, color: Colors.white, size: 20),
          tooltip: AppStrings.common.refresh,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'Transaksi'),
          Tab(text: 'Pengeluaran'),
        ],
      ),
    );
  }


  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HistoryFilterBottomSheet(),
    );
  }
}

