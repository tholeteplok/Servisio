import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/providers/history_provider.dart';
import '../../core/constants/app_strings.dart';
import 'tabs/transaction_history_tab.dart';
import 'tabs/expense_history_tab.dart';
import '../../core/widgets/atelier_header.dart';

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


  bool get _isExpenseTab => _tabController.index == 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAtelierHeader(
            title: AppStrings.history.title,
            subtitle: AppStrings.history.subtitle,
            showBackButton: false,
            searchController: _searchController,
            searchHint: _tabController.index == 0
                ? AppStrings.history.searchHint
                : 'Cari pengeluaran...', // Custom hint for expense
            onSearchChanged: (v) {
              ref.read(historySearchQueryProvider.notifier).set(v);
            },
            actions: [
              if (!_isExpenseTab) ...[
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
          ),
          SliverAppBar(
            pinned: true,
            toolbarHeight: 0,
            collapsedHeight: 0,
            automaticallyImplyLeading: false,
            backgroundColor: theme.colorScheme.surface,
            bottom: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 4,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelColor: theme.colorScheme.primary,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(SolarIconsOutline.history, size: 16),
                      SizedBox(width: 8),
                      Text('Transaksi'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(SolarIconsOutline.billList, size: 16),
                      SizedBox(width: 8),
                      Text('Pengeluaran'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        body: NotificationListener<ScrollNotification>(
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
