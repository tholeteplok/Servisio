import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
import '../../core/providers/katalog_provider.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/service_master.dart';
import '../../core/providers/master_providers.dart';
import '../../core/providers/stok_provider.dart';
import 'create_barang_screen.dart';
import 'create_service_master_screen.dart';
import 'stok_history_screen.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/utils/app_haptic.dart';
import '../../core/widgets/atelier_header.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../domain/entities/expense.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/services/session_manager.dart';

class KatalogScreen extends ConsumerStatefulWidget {
  final PageController? mainPageController;
  const KatalogScreen({super.key, this.mainPageController});
  @override
  ConsumerState<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends ConsumerState<KatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(katalogActiveTabProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(katalogActiveTabProvider.notifier).set(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const BarcodeScannerDialog(),
    );

    if (result != null && mounted) {
      _searchController.text = result;
      // Trigger search
      if (_tabController.index == 0) {
        ref.read(stokListProvider.notifier).search(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 Listen to navigation changes to clear search
    ref.listen(navigationProvider, (previous, next) {
      if (next != 2) {
        // 2 is Katalog tab
        _searchController.clear();
      }
    });

    final theme = Theme.of(context);
    final stokList = ref.watch(stokListProvider);
    final serviceListAsync = ref.watch(serviceMasterListProvider);
    final serviceList = serviceListAsync.valueOrNull ?? [];
    final settings = ref.watch(settingsProvider);

    // Show onboarding hint for overscroll navigation
    if (!settings.hasSeenOverscrollHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.catalog.overscrollNavHint),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
          ref.read(settingsProvider.notifier).setHasSeenOverscrollHint(true);
        }
      });
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAtelierHeader(
            title: AppStrings.catalog.inventoryTitle,
            subtitle: AppStrings.catalog.inventorySubtitle,
            showBackButton: false,
            searchController: _searchController,
            searchHint: _tabController.index == 0
                ? AppStrings.catalog.searchBarang
                : AppStrings.catalog.searchJasa,
            onSearchChanged: (v) {
              if (_tabController.index == 0) {
                ref.read(stokListProvider.notifier).search(v);
              }
            },
            actions: [
              if (_tabController.index == 0) ...[
                IconButton(
                  onPressed: _openScanner,
                  icon: Icon(SolarIconsOutline.scanner,
                      color: theme.colorScheme.onPrimary, size: 20),
                  tooltip: AppStrings.catalog.tooltipScanner,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => ref.invalidate(serviceMasterListProvider),
                icon: Icon(SolarIconsOutline.refresh,
                    color: theme.colorScheme.onPrimary, size: 20),
                tooltip: AppStrings.common.refresh,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppStrings.catalog.tabBarang),
                      if (stokList.isEmpty) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppStrings.catalog.tabJasa),
                      if (serviceListAsync.isLoading) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
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
            // 🛠️ FIX: Only trigger page navigation for HORIZONTAL overscroll.
            // This prevents vertical list overscroll (hitting top/bottom) from accidentally flipping screens.
            if (notification is OverscrollNotification &&
                notification.metrics.axis == Axis.horizontal &&
                widget.mainPageController != null) {
              if (notification.overscroll < 0 && _tabController.index == 0) {
                // Swipe Right (drag right) -> Go to Home (index 0)
                widget.mainPageController!.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else if (notification.overscroll > 0 &&
                  _tabController.index == 1) {
                // Swipe Left (drag left) -> Go to Pelanggan (index 2)
                widget.mainPageController!.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            }
            return false;
          },
          child: TabBarView(
            controller: _tabController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildBarangTab(stokList, theme),
              _buildJasaTab(serviceList, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarangTab(List<Stok> stokList, ThemeData theme) {
    final sortedStok = ref.watch(sortedStokProvider);
    final currentSort = ref.watch(stokSortNotifierProvider);

    if (stokList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              SolarIconsOutline.box,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.catalog.emptyBarang,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // --- Sorting Bar ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              _buildSortChip(AppStrings.catalog.sortAll, StokSort.none, currentSort, theme),
              _buildSortChip(AppStrings.catalog.sortLow, StokSort.lowToHigh, currentSort, theme),
              _buildSortChip(AppStrings.catalog.sortHigh, StokSort.highToLow, currentSort, theme),
              _buildSortChip(AppStrings.catalog.sortSupplier, StokSort.supplier, currentSort, theme),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('stok_list_view'),
            itemExtent: 122,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            itemCount: sortedStok.length,
            itemBuilder: (context, index) {
              final item = sortedStok[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StokCard(item: item, currencyFormat: _currencyFormat),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, StokSort sort, StokSort currentSort, ThemeData theme) {
    final isSelected = sort == currentSort;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            AppHaptic.selection();
            ref.read(stokSortNotifierProvider.notifier).setSort(sort);
          }
        },
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildJasaTab(List<ServiceMaster> serviceList, ThemeData theme) {
    if (serviceList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              SolarIconsOutline.penNewSquare,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.catalog.emptyJasa,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('jasa_list_view'),
      itemExtent: 122,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: serviceList.length,
      itemBuilder: (context, index) {
        final item = serviceList[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ServiceCard(item: item, currencyFormat: _currencyFormat),
        );
      },
    );
  }
}

class _StokCard extends ConsumerWidget {
  final Stok item;
  final NumberFormat currencyFormat;

  const _StokCard({required this.item, required this.currencyFormat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bestSellingMap = ref.watch(supplierBestSellingProvider);
    final isBestSelling = item.supplierName != null && 
                          item.supplierName!.isNotEmpty && 
                          bestSellingMap[item.supplierName!]?.uuid == item.uuid;

    // Status colors & icons (semantic labels for accessibility)
    final isLow = item.isLowStock && item.jumlah > 0;
    final isEmpty = item.jumlah == 0;
    final Color badgeColor = isEmpty
        ? theme.colorScheme.error
        : (isLow ? Colors.amber : theme.colorScheme.tertiary);
    final IconData statusIcon = isEmpty
        ? SolarIconsBold.boxMinimalistic
        : (isLow ? SolarIconsBold.bell : SolarIconsBold.checkCircle);
    final String statusLabel = isEmpty
        ? AppStrings.catalog.statusOutOfStock
        : (isLow ? AppStrings.catalog.statusLowStock : AppStrings.catalog.statusInStock);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: item.photoLocalPath != null
                ? Image.file(
                    File(item.photoLocalPath!),
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(SolarIconsOutline.gallery, size: 24),
                  )
                : Icon(
                    SolarIconsOutline.box,
                    size: 24,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 16),
          // Middle: Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nama,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      item.kategori,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.supplierName != null && item.supplierName!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '• ${item.supplierName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.sku != null)
                  Text(
                    '${AppStrings.catalog.skuPrefix}${item.sku!}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  currencyFormat.format(item.hargaJual),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Right: Stock Badge & Menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      color: theme.colorScheme.onPrimary,
                      size: 12,
                      semanticLabel: statusLabel,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.jumlah} ${AppStrings.catalog.unitPcs}',
                      style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBestSelling) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(SolarIconsBold.fire, color: theme.colorScheme.tertiary, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.catalog.bestSelling.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              _buildPopupMenu(context, theme, ref),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, ThemeData theme, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(SolarIconsOutline.menuDots, size: 20),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onOpened: () => AppHaptic.light(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                CriticalActionGuard.check(
                  ref,
                  context,
                  CriticalActionType.manageInventory,
                ).then((verified) {
                  if (verified && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateBarangScreen(itemToEdit: item),
                      ),
                    );
                  }
                });
                break;
              case 'restock':
                _showRestockDialog(context, ref, theme);
                break;
              case 'history':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StokHistoryScreen(stok: item),
                  ),
                );
                break;
              case 'hapus':
                CriticalActionGuard.check(
                  ref,
                  context,
                  CriticalActionType.manageInventory,
                ).then((verified) {
                  if (verified && context.mounted) {
                    _confirmDelete(context, ref, theme);
                  }
                });
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem(context, 'edit', SolarIconsOutline.penNewSquare, AppStrings.catalog.actionEdit, theme),
            _buildMenuItem(
              context,
              'restock',
              SolarIconsOutline.addSquare,
              AppStrings.catalog.actionAddStock,
              theme,
            ),
            _buildMenuItem(
              context,
              'history',
              SolarIconsOutline.history,
              AppStrings.catalog.actionStockHistory,
              theme,
            ),
            const PopupMenuDivider(),
            _buildMenuItem(
              context,
              'hapus',
              SolarIconsOutline.trashBinTrash,
              AppStrings.common.delete,
              theme,
              isDestructive: true,
            ),
          ],
        );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
    ThemeData theme, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isDestructive ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(BuildContext context, WidgetRef ref, ThemeData theme) {
    final controller = TextEditingController();
    bool isHutang = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: theme.colorScheme.surface,
          title: Text(
            AppStrings.catalog.dialogAddStockTitle,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.catalog.dialogAddStockContent(item.nama),
                style: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: AppStrings.catalog.labelQuantity,
                  suffixText: AppStrings.catalog.unitPcs,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Metode Pembayaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentToggle(
                      context: context,
                      label: 'Tunai',
                      icon: SolarIconsOutline.wallet,
                      isSelected: !isHutang,
                      onTap: () => setState(() => isHutang = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaymentToggle(
                      context: context,
                      label: 'Hutang',
                      icon: SolarIconsOutline.usersGroupTwoRounded,
                      isSelected: isHutang,
                      onTap: () => setState(() => isHutang = true),
                      activeColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.common.cancel.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = int.tryParse(controller.text);
                if (amount != null && amount > 0) {
                  final bengkelId = ref.read(bengkelIdProvider);
                  if (bengkelId == null) return;

                  try {
                    // Create Expense for restock
                    final totalBeli = amount * item.hargaBeli;
                    if (totalBeli > 0) {
                      final expense = Expense(
                        amount: totalBeli,
                        category: 'BELI_STOK',
                        bengkelId: bengkelId,
                        description: 'Restock ${item.nama} x$amount',
                        date: DateTime.now(),
                        supplierName: item.supplierName,
                        debtStatus: isHutang ? 'HUTANG' : null,
                        isVerified: true,
                      );
                      ref.read(expenseListProvider(bengkelId).notifier).addExpense(expense);
                    }

                    ref
                        .read(stokListProvider.notifier)
                        .restock(item.uuid, amount, 'Restock cepat dari menu');
                    Navigator.pop(context);
                  } catch (e) {
                    debugPrint('❌ Restock error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal tambah stok: $e')),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: Text(
                AppStrings.common.save.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentToggle({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final color = activeColor ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outlineVariant,
              width: 1.5,
            ),
            color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          AppStrings.catalog.dialogDeleteTitleBarang,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          AppStrings.catalog.dialogDeleteContentBarang(item.nama),
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.common.cancel.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(stokListProvider.notifier).deleteItem(item.id);
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.common.delete.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceMaster item;
  final NumberFormat currencyFormat;

  const _ServiceCard({required this.item, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                SolarIconsOutline.penNewSquare,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.category ?? AppStrings.common.noCategory,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(item.basePrice),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                _buildPopupMenu(context, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, ThemeData theme) {
    return Consumer(
      builder: (context, ref, child) {
        return PopupMenuButton<String>(
          icon: const Icon(SolarIconsOutline.menuDots, size: 20),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onOpened: () => AppHaptic.light(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateServiceMasterScreen(itemToEdit: item),
                  ),
                );
                break;
              case 'hapus':
                _confirmDelete(context, ref, theme);
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem(context, 'edit', SolarIconsOutline.penNewSquare, AppStrings.catalog.actionEdit, theme),
            const PopupMenuDivider(),
            _buildMenuItem(
              context,
              'hapus',
              SolarIconsOutline.trashBinTrash,
              AppStrings.common.delete,
              theme,
              isDestructive: true,
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
    ThemeData theme, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isDestructive ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          AppStrings.catalog.dialogDeleteTitleJasa,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          AppStrings.catalog.dialogDeleteContentJasa(item.name),
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.common.cancel.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(serviceMasterListProvider.notifier).deleteItem(item.id);
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.common.delete.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
