import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/the_ceremony_dialog.dart';
import '../../core/widgets/qr_view_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import 'create_transaction_screen.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/master_providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/atelier_list_card.dart';
import '../../core/providers/home_provider.dart';
import '../../domain/entities/transaction.dart';
import '../statistik/statistik_screen.dart';
import 'transaction_detail_screen.dart';
import 'package:servislog_core/core/providers/stats_provider.dart';
import '../pengaturan/pengaturan_screen.dart';
import '../pengaturan/sub/fitur_screen.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../core/providers/stok_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/katalog_provider.dart';
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/vehicle.dart';
import '../pelanggan/pelanggan_detail_screen.dart';
import '../../core/providers/reminder_provider.dart';
import 'reminder_screen.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../core/services/session_manager.dart';
import '../../core/widgets/atelier_skeleton.dart';
import '../../core/widgets/atelier_header.dart';
import '../main/responsive_layout_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  
  // Hint Animation & State
  late AnimationController _hintController;
  bool _shouldShowSwipeHint = false;
  bool _shouldShowChevron = false;
  static const int _chevronThreshold = 5; // Menghilang setelah 5x interaksi (swipe)

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Initialize Hint Controller
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _checkDailyHint();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedTransactionListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _checkDailyHint() async {
    final prefs = await SharedPreferences.getInstance();
    final lastHintDate = prefs.getString('swipe_hint_last_date');
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    
    // Check Interaction Count
    final interactionCount = prefs.getInt('daily_swipe_count_$today') ?? 0;

    if (lastHintDate != today && mounted) {
      setState(() => _shouldShowSwipeHint = true);
      
      // Reset interaction count for new day
      await prefs.setInt('daily_swipe_count_$today', 0);
      setState(() => _shouldShowChevron = true);

      // Jalankan animasi geser (delay sedikit agar layar stabil)
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      
      await _hintController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _hintController.reverse();
      
      // Tandai sudah ditampilkan hari ini
      await prefs.setString('swipe_hint_last_date', today);
      
      if (mounted) {
        setState(() => _shouldShowSwipeHint = false);
      }
    } else {
      // Jika sudah hari yang sama, cek apakah chevron masih harus muncul
      if (interactionCount < _chevronThreshold && mounted) {
        setState(() => _shouldShowChevron = true);
      }
    }
  }

  Future<void> _onSwipeInteracted() async {
    if (!_shouldShowChevron) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final currentCount = (prefs.getInt('daily_swipe_count_$today') ?? 0) + 1;
    
    await prefs.setInt('daily_swipe_count_$today', currentCount);
    
    if (currentCount >= _chevronThreshold && mounted) {
      setState(() => _shouldShowChevron = false);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _handleDelete(BuildContext context, Transaction trx) {
    final messenger = ScaffoldMessenger.of(context);
    
    // Perform soft delete
    ref.read(paginatedTransactionListProvider.notifier).deleteTransaction(trx.id, trx.uuid);

    // Show SnackBar with Undo
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.transaction.deleteConfirmation(trx.trxNumber)),
        action: SnackBarAction(
          label: AppStrings.common.cancel.toUpperCase(),
          onPressed: () {
            ref.read(paginatedTransactionListProvider.notifier).undoDelete();
          },
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 Sync search controller with provider (e.g. when cleared via navigation)
    ref.listen(homeSearchQueryProvider, (previous, next) {
      if (next.isEmpty && _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    final paginatedState = ref.watch(paginatedTransactionListProvider);
    final transactions = paginatedState.items;
    final stats = ref.watch(statsProvider);
    final settings = ref.watch(settingsProvider);
    final searchQueryText = ref.watch(homeSearchQueryProvider);
    final searchQuery = searchQueryText.toLowerCase();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- GLOBAL SEARCH DATA ---
    final allPelanggan = ref.watch(pelangganListProvider);
    final allStok = ref.watch(stokListProvider);
    final allVehiclesAsync = ref.watch(vehicleListProvider);
    final allVehicles = allVehiclesAsync.valueOrNull ?? [];

    // Results filtered by search query
    final filteredPelanggan = searchQuery.isEmpty
        ? <Pelanggan>[]
        : allPelanggan
              .where(
                (p) =>
                    p.nama.toLowerCase().contains(searchQuery) ||
                    p.telepon.contains(searchQuery),
              )
              .take(5)
              .toList();

    final filteredVehicles = searchQuery.isEmpty
        ? <Vehicle>[]
        : allVehicles
              .where(
                (v) =>
                    v.plate.toLowerCase().contains(searchQuery) ||
                    v.model.toLowerCase().contains(searchQuery),
              )
              .take(5)
              .toList();

    final filteredStok = searchQuery.isEmpty
        ? <Stok>[]
        : allStok
              .where(
                (s) =>
                    s.nama.toLowerCase().contains(searchQuery) ||
                    (s.sku?.toLowerCase().contains(searchQuery) ?? false),
              )
              .take(5)
              .toList();

    final filteredHistory = searchQuery.isEmpty
        ? <Transaction>[]
        : transactions
              .where(
                (t) =>
                    t.trxNumber.toLowerCase().contains(searchQuery) ||
                    t.customerName.toLowerCase().contains(searchQuery) ||
                    t.vehiclePlate.toLowerCase().contains(searchQuery),
              )
              .take(5)
              .toList();

    final hasAnyResults =
        filteredPelanggan.isNotEmpty ||
        filteredVehicles.isNotEmpty ||
        filteredStok.isNotEmpty ||
        filteredHistory.isNotEmpty;
    final isSearching = searchQuery.isNotEmpty;

    // Filter today's transactions for the list with search support (Normal View)
    final todayTrx = transactions.where((t) {
      final matchesToday = _isToday(t.createdAt) && !t.isDeleted;
      if (!matchesToday) return false;

      // --- FIX: Exclude LUNAS (Paid) transactions from Dashboard ---
      if (t.serviceStatus == ServiceStatus.lunas) return false;

      if (searchQuery.isEmpty) return true;

      return t.vehicleModel.toLowerCase().contains(searchQuery) ||
          t.vehiclePlate.toLowerCase().contains(searchQuery) ||
          t.customerName.toLowerCase().contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAtelierHeader(
            title: settings.workshopName,
            subtitle: DateFormat('EEEE, d MMMM yyyy', AppStrings.date.localeID)
                .format(DateTime.now()),
            showBackButton: false,
            searchController: _searchController,
            searchHint: AppStrings.home.searchHint,
            onSearchChanged: (val) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                ref.read(homeSearchQueryProvider.notifier).update(val);
              });
            },
            actions: [
              const _InlineZoneBadge(),
              const SizedBox(width: 8),
              const SyncStatusIndicator(),
              if (settings.qrisEnabled) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (settings.qrisImagePath != null) {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.8),
                        builder: (_) => QRViewView(
                          imagePath: settings.qrisImagePath!,
                          workshopName: settings.workshopName,
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(AppStrings.home.qrisNotSet),
                          content: Text(AppStrings.home.qrisNotSetDesc),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppStrings.common.cancel),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FiturScreen(),
                                  ),
                                );
                              },
                              child: const Text('Atur Gambar'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(SolarIconsOutline.qrCode,
                      color: Colors.white, size: 20),
                   style: IconButton.styleFrom(
                     backgroundColor: isDark
                         ? Colors.white.withValues(alpha: 0.1)
                         : Colors.black.withValues(alpha: 0.05),
                     minimumSize: const Size(48, 48),
                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                   ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PengaturanScreen()),
                ),
                icon: const Icon(SolarIconsOutline.settings,
                    color: Colors.white, size: 20),
                tooltip: AppStrings.home.settings,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),


          // ── ASYMMETRIC BENTO GRID (Now Below Header) ──
          if (!isSearching)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StatistikScreen(),
                              ),
                            ),
                            child: _BentoCard(
                              title: AppStrings.home.todayRevenue,
                              value: _formatCurrencyShort(
                                stats.todayPendapatan.toDouble(),
                              ),
                              subValue: AppStrings.home.totalRevenueLabel,
                              icon: SolarIconsBold.wadOfMoney,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReminderScreen(),
                              ),
                            ),
                            child: _BentoCard(
                              title: AppStrings.home.reminder,
                              value: ref
                                  .watch(reminderCountProvider)
                                  .toString(),
                              subValue: AppStrings.home.upcoming,
                              icon: SolarIconsBold.bell,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _BentoCard(
                            title: AppStrings.home.visitors,
                            value: stats.todayVisitorCount.toString(),
                            subValue:
                                '${stats.todayActiveCount} ${AppStrings.home.processed}',
                            icon: SolarIconsBold.usersGroupTwoRounded,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // 1. Set sort filter to Low to High (Tersedikit)
                              ref
                                  .read(stokSortNotifierProvider.notifier)
                                  .setSort(StokSort.lowToHigh);

                              // 2. Ensure Katalog sub-tab is on 'Barang'
                              ref
                                  .read(katalogActiveTabProvider.notifier)
                                  .set(0);

                              // 3. Switch global tab to index 2 (Katalog)
                              ref
                                  .read(navigationProvider.notifier)
                                  .setIndex(1);
                            },
                            child: _BentoCard(
                              title: AppStrings.home.inventory,
                              icon: (stats.lowStockCount +
                                          stats.emptyStockCount >
                                      0)
                                  ? SolarIconsBold.box
                                  : SolarIconsBold.checkCircle,
                              color: (stats.lowStockCount +
                                          stats.emptyStockCount >
                                      0)
                                  ? Colors.orange
                                  : Colors.green,
                              border: null, // No-Line Rule
                              valueWidget: (stats.lowStockCount +
                                          stats.emptyStockCount >
                                      0)
                                  ? Row(
                                      children: [
                                        if (stats.lowStockCount > 0) ...[
                                          Text(
                                            stats.lowStockCount.toString(),
                                            style:
                                                GoogleFonts.manrope(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      Colors.orange.shade700,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (stats.emptyStockCount > 0) ...[
                                          Text(
                                            stats.emptyStockCount.toString(),
                                            style: GoogleFonts.manrope(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        const Icon(
                                          SolarIconsBold.checkCircle,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          AppStrings.home.inventorySafe,
                                          style: GoogleFonts.manrope(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                              subValue: AppStrings.home.inventoryStatus,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),


          // ── SEARCH RESULTS OR NORMAL VIEW ──
          if (isSearching) ...[
            if (hasAnyResults) ...[
              _buildSearchSection(
                context,
                ref,
                AppStrings.home.sectionCustomerPlate,
                [...filteredPelanggan, ...filteredVehicles],
                (item) {
                  if (item is Pelanggan) {
                    return _buildPelangganResult(context, item);
                  }
                  if (item is Vehicle) {
                    return _buildVehicleResult(context, item);
                  }
                  return const SizedBox();
                },
                onViewAll: () =>
                    ref.read(navigationProvider.notifier).setIndex(2),
              ),
              _buildSearchSection(
                context,
                ref,
                AppStrings.home.sectionInventory,
                filteredStok,
                (item) => _buildStokResult(context, ref, item as Stok),
                onViewAll: () {
                  ref.read(stokListProvider.notifier).search(searchQueryText);
                  ref.read(navigationProvider.notifier).setIndex(1);
                },
              ),
              _buildSearchSection(
                context,
                ref,
                AppStrings.home.sectionHistory,
                filteredHistory,
                (item) => _buildTransactionResult(context, item as Transaction),
                onViewAll: () =>
                    ref.read(navigationProvider.notifier).setIndex(3),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ] else
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        SolarIconsOutline.magnifier,
                        size: 64,
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${AppStrings.home.noSearchResults} "$searchQueryText"',
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            // ── Today's Visitors Section ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.home.todayActivities,
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(navigationProvider.notifier).setIndex(3),
                      child: Text(
                        AppStrings.home.seeAll,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            todayTrx.isEmpty
                ? (paginatedState.isInitialLoading
                    ? SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => AtelierSkeleton.transactionCard(),
                            childCount: 5,
                          ),
                        ),
                      )
                    : SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                SolarIconsOutline.ghost,
                                size: 48,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.home.noVisitorsToday,
                                style: GoogleFonts.plusJakartaSans(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == todayTrx.length) {
                          return paginatedState.isLoadingMore
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: AtelierSkeleton.transactionCard(),
                                  ),
                                )
                              : const SizedBox(height: 100);
                        }
                        final activityCard = _ActivityCard(
                          trx: todayTrx[index],
                          onDelete: () => _handleDelete(context, todayTrx[index]),
                          showChevronHint: _shouldShowChevron,
                          onSwiped: _onSwipeInteracted,
                        );

                        if (index == 0 && _shouldShowSwipeHint) {
                          return AnimatedBuilder(
                            animation: _hintController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  _hintController.value *
                                      MediaQuery.of(context).size.width *
                                      0.25,
                                  0,
                                ),
                                child: child,
                              );
                            },
                            child: activityCard,
                          );
                        }

                        return activityCard;
                      },
                      childCount: todayTrx.length + 1,
                    ),
                  ),
          ],

          // ── Bottom Banner: Monthly Goal ──
          if (!isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceLighter
                        : AppColors.amethyst.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage(
                        'assets/images/bg_pattern.png',
                      ), // Fallback pattern
                      opacity: 0.05,
                      alignment: Alignment.bottomRight,
                      fit: BoxFit.none,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.home.monthlyTarget,
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${(stats.monthlyPendapatan / (settings.monthlyTarget > 0 ? settings.monthlyTarget : 1) * 100).ceil().clamp(0, 100)}% ${AppStrings.home.progress}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            if (settings.monthlyTarget > stats.monthlyPendapatan)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${AppStrings.home.remainingTarget}${NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(settings.monthlyTarget - stats.monthlyPendapatan)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 80), // GAP FOR CENTERED FAB
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(
                            SolarIconsOutline.graphUp,
                            color: Colors.white24,
                            size: 32,
                          ),
                          Text(
                            AppStrings.home.performanceGood,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCurrencyShort(double amount) {
    if (amount >= 1000000) {
      return '${AppStrings.common.currencySymbol}${(amount / 1000000).toStringAsFixed(1)}${AppStrings.common.million}';
    } else if (amount >= 1000) {
      return '${AppStrings.common.currencySymbol}${(amount / 1000).toInt()}${AppStrings.common.thousand}';
    }
    return '${AppStrings.common.currencySymbol}${amount.toInt()}';
  }

  // ── SEARCH RESULT BUILDERS ──

  Widget _buildSearchSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<dynamic> items,
    Widget Function(dynamic) itemBuilder, {
    required VoidCallback onViewAll,
  }) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    AppStrings.home.seeAll,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: itemBuilder(items[index]),
            ),
            childCount: items.length,
          ),
        ),
      ],
    );
  }

  Widget _buildPelangganResult(BuildContext context, Pelanggan p) {
    return _ResultCard(
      title: p.nama,
      subtitle: p.telepon,
      icon: SolarIconsOutline.user,
      color: Colors.blue,
      badge: AppStrings.home.badgeCustomer, // UX-05
      onTap: () {
        AdaptiveNavigator.push(
          context: context,
          ref: ref,
          detailContent: PelangganDetailScreen(pelanggan: p),
          routeBuilder: () => PelangganDetailScreen(pelanggan: p),
        );
      },
    );
  }

  Widget _buildVehicleResult(BuildContext context, Vehicle v) {
    return _ResultCard(
      title: v.plate,
      subtitle: v.model,
      icon: AppIcons.motorcycle,
      color: AppColors.amethyst,
      badge: AppStrings.home.badgeVehicle, // UX-05
      onTap: () {
        final owner = v.owner.target;
        if (owner != null) {
          AdaptiveNavigator.push(
            context: context,
            ref: ref,
            detailContent: PelangganDetailScreen(pelanggan: owner),
            routeBuilder: () => PelangganDetailScreen(pelanggan: owner),
          );
        }
      },
    );
  }

  Widget _buildStokResult(BuildContext context, WidgetRef ref, Stok s) {
    return _ResultCard(
      title: s.nama,
      subtitle:
          '${s.kategori} • Rp ${NumberFormat('#,###').format(s.hargaJual)}',
      icon: SolarIconsOutline.box,
      color: s.jumlah == 0
          ? AppColors.error
          : (s.isLowStock ? Colors.amber : AppColors.success),
      onTap: () {
        ref.read(stokListProvider.notifier).search(s.nama);
        ref.read(navigationProvider.notifier).setIndex(2);
      },
    );
  }

  Widget _buildTransactionResult(BuildContext context, Transaction t) {
    return _ResultCard(
      title: t.trxNumber,
      subtitle: '${t.customerName} • ${t.vehiclePlate}',
      icon: SolarIconsOutline.billList,
      color: Colors.green,
      onTap: () {
        AdaptiveNavigator.push(
          context: context,
          ref: ref,
          detailContent: TransactionDetailScreen(transaction: t),
          routeBuilder: () => TransactionDetailScreen(transaction: t),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  // UX-05 FIX: Badge opsional untuk membedakan tipe hasil pencarian
  final String? badge;

  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
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
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                SolarIconsOutline.arrowRight,
                size: 16,
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              // UX-05 FIX: Tampilkan badge kategori jika ada
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
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

class _BentoCard extends StatelessWidget {
  final String title;
  final String? value;
  final Widget? valueWidget;
  final String subValue;
  final IconData icon;
  final Color color;
  final BoxBorder? border;

  const _BentoCard({
    required this.title,
    this.value,
    this.valueWidget,
    required this.subValue,
    required this.icon,
    required this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

     return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: border ?? Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.outline.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -3,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Watermark Icon
            Positioned(
              bottom: -20,
              right: -20,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  icon,
                  size: 100,
                  color: isDark ? Colors.white : color,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (valueWidget != null)
                    valueWidget!
                  else
                    Text(
                      value ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  Text(
                    subValue,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerStatefulWidget {
  final Transaction trx;
  final VoidCallback? onDelete;

  final bool showChevronHint;
  final VoidCallback? onSwiped;

  const _ActivityCard({
    required this.trx,
    this.onDelete,
    this.showChevronHint = false,
    this.onSwiped,
  });

  @override
  ConsumerState<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends ConsumerState<_ActivityCard> {
  int _swipeDeleteCount = 0;
  Timer? _resetSwipeTimer;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (widget.trx.serviceStatus == ServiceStatus.dikerjakan) {
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resetSwipeTimer?.cancel();
    super.dispose();
  }

  String _getDurationText(DateTime startTime) {
    final diff = DateTime.now().difference(startTime);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m';
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trx = widget.trx;

    // Status color, Label & Icon
    Color statusColor = Colors.grey;
    String statusLabel = 'ST';
    IconData statusIcon = SolarIconsOutline.infoCircle;
    ServiceStatus? nextStatus;

    switch (trx.serviceStatus) {
      case ServiceStatus.antri:
        statusColor = Colors.blue;
        statusLabel = AppStrings.transaction.statusAntriCaps;
        statusIcon = SolarIconsOutline.hourglass;
        nextStatus = ServiceStatus.dikerjakan;
        break;
      case ServiceStatus.dikerjakan:
        statusColor = AppColors.amethyst;
        statusLabel = AppStrings.transaction.statusServisCaps;
        statusIcon = SolarIconsOutline.settings;
        nextStatus = ServiceStatus.selesai;
        break;
      case ServiceStatus.selesai:
        statusColor = Colors.orange;
        statusLabel = AppStrings.transaction.statusSelesaiCaps;
        statusIcon = SolarIconsOutline.checkCircle;
        nextStatus = ServiceStatus.lunas;
        break;
      case ServiceStatus.lunas:
        statusColor = Colors.green;
        statusLabel = AppStrings.transaction.statusLunasCaps;
        statusIcon = SolarIconsBold.checkCircle;
        nextStatus = null; // No more forward progression
        break;
    }

    final Color nextStatusColor = nextStatus == ServiceStatus.dikerjakan 
        ? Colors.blue 
        : nextStatus == ServiceStatus.selesai 
            ? AppColors.amethyst 
            : Colors.green;

    final String nextStatusLabel = nextStatus == ServiceStatus.dikerjakan 
        ? AppStrings.transaction.actionProses 
        : nextStatus == ServiceStatus.selesai 
            ? AppStrings.transaction.actionSelesaikan 
            : AppStrings.transaction.actionLunas;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key('activity_${trx.uuid}_$_swipeDeleteCount'), // Replay key to force snapback if needed
        direction: trx.serviceStatus == ServiceStatus.antri 
            ? DismissDirection.horizontal 
            : DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // PROGRESSION (Swipe Right)
            if (nextStatus != null) {
              if (nextStatus == ServiceStatus.lunas) {
                HapticFeedback.mediumImpact();
                final result = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => TheCeremonyDialog(transaction: trx),
                );
                if (result == true) {
                  ref.invalidate(statsProvider);
                }
              } else {
                // Show confirmation for intermediate steps
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppStrings.common.confirm),
                    content: Text('Ubah status transaksi "${trx.trxNumber}" menjadi ${nextStatusLabel.toUpperCase()}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppStrings.common.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: nextStatusColor,
                        ),
                        child: Text(AppStrings.common.confirm),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  HapticFeedback.mediumImpact();
                  await ref
                      .read(transactionListProvider.notifier)
                      .updateTransactionStatus(trx, nextStatus);
                  ref.invalidate(statsProvider);
                }
              }
            }
            return false; // Never dismiss via progression
          } else {
            // DELETE (Swipe Left)
            // Interaction Trigger for Hint
            widget.onSwiped?.call();
            if (trx.serviceStatus == ServiceStatus.antri) {
              if (_swipeDeleteCount == 0) {
                HapticFeedback.lightImpact();
                setState(() {
                  _swipeDeleteCount = 1;
                });
                // Reset after 3 seconds if not confirmed
                _resetSwipeTimer?.cancel();
                _resetSwipeTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _swipeDeleteCount = 0);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.transaction.swipeToDeleteHint),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return false;
              } else {
                HapticFeedback.heavyImpact();
                return true; // Confirm delete
              }
            }
            return false;
          }
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: nextStatusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                nextStatus == ServiceStatus.lunas 
                    ? SolarIconsOutline.checkCircle 
                    : SolarIconsOutline.doubleAltArrowRight,
                color: nextStatusColor,
              ),
              const SizedBox(width: 12),
              Text(
                nextStatusLabel,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: nextStatusColor,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: trx.serviceStatus == ServiceStatus.antri 
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: _swipeDeleteCount == 0 
                    ? Colors.red.withValues(alpha: 0.1) 
                    : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _swipeDeleteCount == 0 
                        ? AppStrings.transaction.deleteCaps 
                        : AppStrings.transaction.confirmDelete,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _swipeDeleteCount == 0 ? Colors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    _swipeDeleteCount == 0 
                        ? SolarIconsOutline.trashBinMinimalistic 
                        : SolarIconsBold.trashBinTrash,
                    color: _swipeDeleteCount == 0 ? Colors.red : Colors.white,
                  ),
                ],
              ),
            )
          : null,
        onDismissed: (_) => widget.onDelete?.call(),
        child: AtelierListGroup(
          children: [
            AtelierListTile(
              customLeading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  image: trx.pelanggan.target?.photoLocalPath != null
                      ? DecorationImage(
                          image: ResizeImage(
                            FileImage(
                              File(trx.pelanggan.target!.photoLocalPath!),
                            ),
                            width: 120,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: trx.pelanggan.target?.photoLocalPath == null
                    ? Icon(
                        trx.vehicleModel.toLowerCase().contains('car')
                            ? AppIcons.car
                            : AppIcons.motorcycle,
                        color: statusColor,
                      )
                    : null,
              ),
              customTitle: Row(
                children: [
                  Text(
                    trx.vehiclePlate,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (trx.serviceStatus == ServiceStatus.dikerjakan &&
                      trx.startTime != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SolarIconsOutline.clockCircle,
                            size: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getDurationText(trx.startTime!),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: trx.customerName,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showChevronHint && trx.serviceStatus == ServiceStatus.antri)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: _PulseChevron(),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                widget.onSwiped?.call();
                if (trx.serviceStatus == ServiceStatus.antri ||
                    trx.serviceStatus == ServiceStatus.dikerjakan) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateTransactionScreen(initialTransaction: trx),
                    ),
                  );
                } else if (trx.serviceStatus == ServiceStatus.selesai) {
                  _showTechNoteSheet(context, trx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTechNoteSheet(BuildContext context, Transaction trx) {
    // Memberikan nilai default jika kosong sesuai permintaan user
    final noteController = TextEditingController(
      text: trx.mechanicNotes ?? AppStrings.transaction.defaultServiceNote,
    );
    final kmController = TextEditingController(
      text: trx.recommendationKm?.toString() ?? '1000',
    );
    int? selectedTime = trx.recommendationTimeMonth ?? 1;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.transaction.techNotesTitle,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.transaction.techNotesSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppStrings.transaction.techNotesLabel,
                  hintText: AppStrings.transaction.techNotesHint,
                  prefixIcon: const Icon(SolarIconsOutline.pen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                AppStrings.transaction.returnRecommendation,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.transaction.odometerLabel,
                        hintText: '2000',
                        prefixIcon: const Icon(SolarIconsOutline.ruler),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedTime,
                      decoration: InputDecoration(
                        labelText: AppStrings.transaction.timeLabel,
                        prefixIcon: const Icon(SolarIconsOutline.calendar),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: [1, 2, 3, 6, 12]
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text('$m ${AppStrings.transaction.month}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedTime = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        trx.mechanicNotes = noteController.text.isEmpty
                            ? null
                            : noteController.text;
                        trx.recommendationKm = int.tryParse(kmController.text);
                        trx.recommendationTimeMonth = selectedTime;

                        ref
                            .read(transactionListProvider.notifier)
                            .updateTransaction(trx);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppStrings.transaction.techNotesSuccess,
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: AppColors.amethyst,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppStrings.common.save,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🛡️ Inline Zone Badge — compact chip sejajar icon header
// Hanya tampil di Zone 2 / 3 / Blocked. Tersembunyi di Zone 1 (Full Access).
// ─────────────────────────────────────────────────────────────────────────────
class _InlineZoneBadge extends ConsumerWidget {
  const _InlineZoneBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(accessLevelProvider);

    if (level == AccessLevel.full) return const SizedBox.shrink();

    final (color, icon, label) = switch (level) {
      AccessLevel.readOnly => (
          Colors.amber,
          Icons.visibility_outlined,
          AppStrings.access.readOnlyLabel,
        ),
      AccessLevel.readOnlyFinancial => (
          Colors.orange,
          Icons.warning_amber_rounded,
          AppStrings.access.restrictedLabel,
        ),
      AccessLevel.blocked => (
          Colors.redAccent,
          Icons.lock_clock_outlined,
          AppStrings.access.sessionExpiredLabel,
        ),
      _ => (Colors.green, Icons.check_circle_outline, ''),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showDetail(context, level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, AccessLevel level) {
    final (color, title, body) = switch (level) {
      AccessLevel.readOnly => (
          Colors.amber,
          AppStrings.access.readOnlyMode,
          AppStrings.access.readOnlyDesc,
        ),
      AccessLevel.readOnlyFinancial => (
          Colors.orange,
          AppStrings.access.restrictedAccess,
          AppStrings.access.restrictedDesc,
        ),
      AccessLevel.blocked => (
          Colors.redAccent,
          AppStrings.access.sessionExpired,
          AppStrings.access.sessionExpiredDesc,
        ),
      _ => (Colors.green, '', ''),
    };

    if (title.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1528),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_clock_outlined, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppStrings.access.understand),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PulseChevron extends StatefulWidget {
  const _PulseChevron();

  @override
  State<_PulseChevron> createState() => _PulseChevronState();
}

class _PulseChevronState extends State<_PulseChevron>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              SolarIconsOutline.doubleAltArrowRight,
              size: 20,
              color: Colors.blue.withValues(alpha: 0.7),
            ),
          ),
        );
      },
    );
  }
}
