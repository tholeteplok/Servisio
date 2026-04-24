// ============================================================
// adaptive_layout.dart
// Responsive Layout Wrapper — ServisLog+
//
// Breakpoints:
//   Compact  (< 600px)  → Bottom Navigation + FAB (mobile portrait)
//   Medium   (600-840px) → Navigation Rail, no detail pane (tablet portrait)
//   Expanded (> 840px)  → Navigation Rail + Detail Pane, 3-col (tablet landscape)
// ============================================================

import 'dart:io' as java_io;
import 'dart:ui' as java_ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/providers/objectbox_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../core/providers/stok_provider.dart';
import '../../core/providers/master_providers.dart';
import '../../core/providers/backup_provider.dart';
import '../../core/providers/katalog_provider.dart';
import '../../core/providers/home_provider.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/providers/history_provider.dart';
import '../../core/providers/system_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/drive_backup_service.dart';
import '../../core/services/device_session_service.dart';
import '../../core/widgets/standard_dialog.dart';
import '../home/home_screen.dart';
import '../pelanggan/pelanggan_screen.dart';
import '../katalog/katalog_screen.dart';
import '../home/create_transaction_screen.dart';
import '../pelanggan/create_pelanggan_screen.dart';
import '../katalog/create_barang_screen.dart';
import '../katalog/create_service_master_screen.dart';
import '../katalog/create_sale_screen.dart';
import '../riwayat/history_screen.dart';
import '../auth/screens/session_displaced_screen.dart';
import '../auth/screens/access_revoked_screen.dart';
import '../pengaturan/sub/restore_screen.dart';
import '../riwayat/expense/create_expense_screen.dart';
import '../riwayat/expense/scan_expense_screen.dart';
// ─────────────────────────────────────────────────────────────
// BREAKPOINTS
// ─────────────────────────────────────────────────────────────

enum LayoutBreakpoint { compact, medium, expanded }

LayoutBreakpoint getBreakpoint(double width) {
  if (width < 600) return LayoutBreakpoint.compact;
  if (width < 840) return LayoutBreakpoint.medium;
  return LayoutBreakpoint.expanded;
}

// ─────────────────────────────────────────────────────────────
// DETAIL PANE PROVIDER
// Menyimpan widget yang ditampilkan di kolom kanan (expanded mode)
// ─────────────────────────────────────────────────────────────

final detailPaneProvider = StateProvider<Widget?>((ref) => null);

// ─────────────────────────────────────────────────────────────
// NAV ITEM MODEL
// ─────────────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final IconData icon;
  final IconData iconSelected;
  final String label;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.iconSelected,
    required this.label,
  });
}

List<_NavItem> get _navItems => [
      _NavItem(
        index: 0,
        icon: AppIcons.navHome,
        iconSelected: AppIcons.navHomeSelected,
        label: AppStrings.nav.home,
      ),
      _NavItem(
        index: 1,
        icon: AppIcons.navInventory,
        iconSelected: AppIcons.navInventorySelected,
        label: AppStrings.nav.inventory,
      ),
      _NavItem(
        index: 2,
        icon: AppIcons.navCustomers,
        iconSelected: AppIcons.navCustomersSelected,
        label: AppStrings.nav.customers,
      ),
      _NavItem(
        index: 3,
        icon: AppIcons.navHistory,
        iconSelected: AppIcons.navHistorySelected,
        label: AppStrings.nav.history,
      ),
    ];

// ─────────────────────────────────────────────────────────────
// MAIN SCREEN — ADAPTIVE ENTRY POINT
// ─────────────────────────────────────────────────────────────

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final PageController _pageController = PageController();
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkBackupStatus();
    _watchDeviceSession();
    _startStatusPolling();
  }

  void _startStatusPolling() {
    // 🎯 SEC-FIX: Background Refresh every 15 minutes
    _statusTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (ref.read(isWipingProvider)) return;
      
      // 1. Invalidate providers to update UI status indicators
      ref.invalidate(currentSessionStatusProvider);
      ref.invalidate(deviceSessionStatusProvider);

      // 2. Trigger background handshake if needed (age > 30m)
      ref.read(sessionManagerProvider).refreshSessionIfNeeded();
    });
  }

  void _watchDeviceSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(deviceSessionStatusProvider, (previous, next) async {
        if (ref.read(isWipingProvider)) return;
        final status = next.value;
        if (status == null ||
            status == DeviceSessionStatus.valid ||
            status == DeviceSessionStatus.unknown) {
          return;
        }
        if (!mounted) return;
        final profile = ref.read(currentProfileProvider);
        if (profile == null) return;

        if (status == DeviceSessionStatus.accountDisabled) {
          final service = ref.read(deviceSessionServiceProvider);
          final isConfirmed = await service.verifyAccountStatusBeforeWipe();
          if (isConfirmed && mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AccessRevokedScreen()),
              (route) => false,
            );
            await Future.delayed(const Duration(milliseconds: 500));
            await service.executeNuclearSequence(
              onWipeStarted: () => ref.read(isWipingProvider.notifier).state = true,
              onCloseDatabase: () async => ref.read(dbProvider).store.close(),
              onComplete: () async {
                // Any additional cleanup if needed
              },
            );
          }
          return;
        }

        if (profile.role != 'owner') return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SessionDisplacedScreen(
              userId: profile.uid,
              isWipeRequested: status == DeviceSessionStatus.wipeRequested,
            ),
          ),
          (route) => false,
        );
      });
    });
  }

  Future<void> _checkBackupStatus() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupProvider.notifier).checkAndRunAutoBackup();
    });
    final settings = ref.read(settingsProvider);
    if (settings.lastBackupAt == null && !settings.hasCheckedBackupDiscovery) {
      final authService = AuthService();
      final user = await authService.signInSilently();
      if (user != null) {
        final driveService = DriveBackupService();
        try {
          final backup = await driveService.downloadLatestBackup();
          if (backup != null && mounted) {
            _showRestorePrompt(backup);
          } else {
            ref.read(settingsProvider.notifier).setHasCheckedBackupDiscovery(true);
          }
        } catch (e) {
          debugPrint('Silent backup check failed: $e');
        }
      } else {
        ref.read(settingsProvider.notifier).setHasCheckedBackupDiscovery(true);
      }
    }
  }

  void _showRestorePrompt(java_io.File backupFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StandardDialog(
        title: 'Cadangan Ditemukan',
        message:
            'Kami menemukan cadangan data Anda di Google Drive. Apakah Anda ingin memulihkannya sekarang?',
        secondaryActionLabel: 'Nanti',
        primaryActionLabel: 'Pulihkan sekarang',
        onPrimaryAction: () {
          ref.read(settingsProvider.notifier).setHasCheckedBackupDiscovery(true);
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RestoreScreen(backupFile: backupFile)),
          );
        },
        onSecondaryAction: () {
          ref.read(settingsProvider.notifier).setHasCheckedBackupDiscovery(true);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _clearSearchOnTabChange() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(homeSearchQueryProvider.notifier).clear();
    ref.read(pelangganListProvider.notifier).updateSearch('');
    ref.read(stokListProvider.notifier).search('');
    ref.invalidate(serviceMasterListProvider);
    ref.read(historySearchQueryProvider.notifier).set('');
    ref.read(historySearchActiveProvider.notifier).state = false;
  }

  void _navigateTo(int index) {
    _clearSearchOnTabChange();
    ref.read(navigationProvider.notifier).setIndex(index);
    if (_pageController.hasClients && _pageController.page?.round() != index) {
      _pageController.jumpToPage(index);
    }
  }

  void _openCreateTransaction() {
    final services = ref.read(serviceMasterListProvider).valueOrNull ?? [];
    
    if (services.isEmpty) {
      _showEmptyCatalogDialog(
        context: context,
        ref: ref,
        title: 'Katalog Kosong',
        message: 'Anda belum memiliki daftar jasa servis. Tambahkan jasa servis terlebih dahulu di menu Inventaris.',
        icon: LucideIcons.wrench,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTransactionScreen()),
    );
  }

  void _openCreateSale() {
    final inventory = ref.read(stokListProvider);
    
    if (inventory.isEmpty) {
      _showEmptyCatalogDialog(
        context: context,
        ref: ref,
        title: 'Stok Kosong',
        message: 'Belum ada barang di inventaris Anda. Tambahkan barang terlebih dahulu untuk mulai berjualan.',
        icon: LucideIcons.package,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
    );
  }

  /// Show friendly dialog when catalog is empty
  Future<void> _showEmptyCatalogDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor: isDark ? AppColors.surfaceLow : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.obsidianBase,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Nanti Saja',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    // Pindah ke tab Inventaris (Index 1)
                    _navigateTo(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Ke Inventaris',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreatePelanggan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePelangganScreen()),
    );
  }

  void _openCreateBarang() {
    final activeKatalogTab = ref.read(katalogActiveTabProvider);
    if (activeKatalogTab == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBarangScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateServiceMasterScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncWorkerProvider);

    final currentIndex = ref.watch(navigationProvider);

    // Sync PageController dengan provider
    ref.listen(navigationProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.jumpToPage(next);
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = getBreakpoint(constraints.maxWidth);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (currentIndex != 0) {
              _navigateTo(0);
            } else {
              SystemNavigator.pop();
            }
          },
          child: switch (breakpoint) {
            LayoutBreakpoint.compact => _CompactLayout(
                pageController: _pageController,
                currentIndex: currentIndex,
                onNavigate: _navigateTo,
                onCreateTransaction: _openCreateTransaction,
                onCreateSale: _openCreateSale,
                onCreatePelanggan: _openCreatePelanggan,
                onCreateBarang: _openCreateBarang,
                ref: ref,
              ),
            LayoutBreakpoint.medium => _MediumLayout(
                pageController: _pageController,
                currentIndex: currentIndex,
                onNavigate: _navigateTo,
                onCreateTransaction: _openCreateTransaction,
                onCreateSale: _openCreateSale,
                onCreatePelanggan: _openCreatePelanggan,
                onCreateBarang: _openCreateBarang,
              ),
            LayoutBreakpoint.expanded => _ExpandedLayout(
                pageController: _pageController,
                currentIndex: currentIndex,
                onNavigate: _navigateTo,
                onCreateTransaction: _openCreateTransaction,
                onCreateSale: _openCreateSale,
                onCreatePelanggan: _openCreatePelanggan,
                onCreateBarang: _openCreateBarang,
                ref: ref,
              ),
          },
        );
      },
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────
// COMPACT LAYOUT  (<600px) — Original mobile behavior preserved
// ─────────────────────────────────────────────────────────────

class _CompactLayout extends StatefulWidget {
  final PageController pageController;
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback onCreateTransaction;
  final VoidCallback onCreateSale;
  final VoidCallback onCreatePelanggan;
  final VoidCallback onCreateBarang;
  final WidgetRef ref;

  const _CompactLayout({
    required this.pageController,
    required this.currentIndex,
    required this.onNavigate,
    required this.onCreateTransaction,
    required this.onCreateSale,
    required this.onCreatePelanggan,
    required this.onCreateBarang,
    required this.ref,
  });

  @override
  State<_CompactLayout> createState() => _CompactLayoutState();
}

class _CompactLayoutState extends State<_CompactLayout> {
  bool _isMenuExpanded = false;
  bool _isHistoryMenuExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _PageBody(
            pageController: widget.pageController,
            onPageChanged: (index) {
              if (_isMenuExpanded) setState(() => _isMenuExpanded = false);
              if (_isHistoryMenuExpanded) setState(() => _isHistoryMenuExpanded = false);
              widget.onNavigate(index);
            },
          ),
          if (_isMenuExpanded)
            _FabExpandedMenu(
              onDismiss: () => setState(() => _isMenuExpanded = false),
              onCreateTransaction: () {
                setState(() => _isMenuExpanded = false);
                widget.onCreateTransaction();
              },
              onCreateSale: () {
                setState(() => _isMenuExpanded = false);
                widget.onCreateSale();
              },
            ),
          if (_isHistoryMenuExpanded)
            _FabHistoryMenu(
              onDismiss: () => setState(() => _isHistoryMenuExpanded = false),
              onScanExpense: () {
                setState(() => _isHistoryMenuExpanded = false);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanExpenseScreen()),
                );
              },
              onCreateExpense: () {
                setState(() => _isHistoryMenuExpanded = false);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateExpenseScreen()),
                );
              },
            ),
        ],
      ),
      floatingActionButton: (widget.currentIndex == 3 && widget.ref.watch(historyActiveTabProvider) == 0)
          ? null
          : FloatingActionButton(
              tooltip: widget.currentIndex == 0
                  ? 'Aksi Cepat'
                  : widget.currentIndex == 1
                      ? 'Tambah Katalog'
                      : widget.currentIndex == 2
                          ? 'Tambah Pelanggan'
                          : 'Cari Riwayat',
              onPressed: () {
                switch (widget.currentIndex) {
                  case 0:
                    setState(() => _isMenuExpanded = !_isMenuExpanded);
                    break;
                  case 1:
                    widget.onCreateBarang();
                    break;
                  case 2:
                    widget.onCreatePelanggan();
                    break;
                  case 3:
                    setState(() => _isHistoryMenuExpanded = !_isHistoryMenuExpanded);
                    break;
                }
              },
              backgroundColor: (_isMenuExpanded || _isHistoryMenuExpanded)
                  ? Colors.grey
                  : Theme.of(context).colorScheme.primary,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: RotationTransition(turns: animation, child: child),
                ),
                child: _FabIcon(
                  currentIndex: widget.currentIndex,
                  isMenuExpanded: _isMenuExpanded || _isHistoryMenuExpanded,
                  ref: widget.ref,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: widget.currentIndex,
        onNavigate: widget.onNavigate,
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MEDIUM LAYOUT  (600–840px) — Rail + no detail pane
// ─────────────────────────────────────────────────────────────

class _MediumLayout extends StatelessWidget {
  final PageController pageController;
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback onCreateTransaction;
  final VoidCallback onCreateSale;
  final VoidCallback onCreatePelanggan;
  final VoidCallback onCreateBarang;

  const _MediumLayout({
    required this.pageController,
    required this.currentIndex,
    required this.onNavigate,
    required this.onCreateTransaction,
    required this.onCreateSale,
    required this.onCreatePelanggan,
    required this.onCreateBarang,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _NavigationRail(
            currentIndex: currentIndex,
            onNavigate: onNavigate,
            onCreateTransaction: onCreateTransaction,
            onCreateSale: onCreateSale,
            onCreatePelanggan: onCreatePelanggan,
            onCreateBarang: onCreateBarang,
            extended: false,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _PageBody(
              pageController: pageController,
              onPageChanged: onNavigate,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EXPANDED LAYOUT  (>840px) — Rail + Feed + Detail Pane (3-col)
// ─────────────────────────────────────────────────────────────

class _ExpandedLayout extends StatelessWidget {
  final PageController pageController;
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback onCreateTransaction;
  final VoidCallback onCreateSale;
  final VoidCallback onCreatePelanggan;
  final VoidCallback onCreateBarang;
  final WidgetRef ref;

  const _ExpandedLayout({
    required this.pageController,
    required this.currentIndex,
    required this.onNavigate,
    required this.onCreateTransaction,
    required this.onCreateSale,
    required this.onCreatePelanggan,
    required this.onCreateBarang,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final detailPane = ref.watch(detailPaneProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // ── Column 1: Navigation Rail (extended) ──
          _NavigationRail(
            currentIndex: currentIndex,
            onNavigate: onNavigate,
            onCreateTransaction: onCreateTransaction,
            onCreateSale: onCreateSale,
            onCreatePelanggan: onCreatePelanggan,
            onCreateBarang: onCreateBarang,
            extended: true,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),

          // ── Column 2: Feed / Dashboard ──
          Expanded(
            flex: 5,
            child: _PageBody(
              pageController: pageController,
              onPageChanged: onNavigate,
            ),
          ),

          // ── Column 3: Detail Pane ──
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          SizedBox(
            width: 360,
            child: detailPane != null
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(detailPane.hashCode),
                      child: detailPane,
                    ),
                  )
                : _DetailPanePlaceholder(isDark: isDark, theme: theme),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAVIGATION RAIL — shared between medium and expanded
// ─────────────────────────────────────────────────────────────

class _NavigationRail extends ConsumerWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback onCreateTransaction;
  final VoidCallback onCreateSale;
  final VoidCallback onCreatePelanggan;
  final VoidCallback onCreateBarang;
  final bool extended;

  const _NavigationRail({
    required this.currentIndex,
    required this.onNavigate,
    required this.onCreateTransaction,
    required this.onCreateSale,
    required this.onCreatePelanggan,
    required this.onCreateBarang,
    required this.extended,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBg = isDark ? AppColors.surfaceLow : Colors.white;
    final railWidth = extended ? 200.0 : 72.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: railWidth,
      decoration: BoxDecoration(
        color: railBg,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo / App Name ──
              if (extended)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          SolarIconsBold.settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ref.watch(settingsProvider).workshopName,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.obsidianBase,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 4),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      SolarIconsBold.settings,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

              // ── Aksi Cepat (di atas nav items) ──
              _RailActionSection(
                extended: extended,
                isDark: isDark,
                onCreateTransaction: onCreateTransaction,
                onCreateSale: onCreateSale,
              ),

              const SizedBox(height: 8),
              Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
                height: 1,
              ),
              const SizedBox(height: 8),

              // ── Nav Items ──
              ..._navItems.map((item) => _RailNavItem(
                    item: item,
                    isSelected: currentIndex == item.index,
                    extended: extended,
                    isDark: isDark,
                    onTap: () => onNavigate(item.index),
                  )),

              const Spacer(),

              // ── Context Action (per-tab) ──
              _RailContextAction(
                currentIndex: currentIndex,
                extended: extended,
                isDark: isDark,
                onCreatePelanggan: onCreatePelanggan,
                onCreateBarang: onCreateBarang,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Rail: Quick Actions (Servis + Jual Barang) ───────────────

class _RailActionSection extends StatelessWidget {
  final bool extended;
  final bool isDark;
  final VoidCallback onCreateTransaction;
  final VoidCallback onCreateSale;

  const _RailActionSection({
    required this.extended,
    required this.isDark,
    required this.onCreateTransaction,
    required this.onCreateSale,
  });

  @override
  Widget build(BuildContext context) {
    if (extended) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionButton(
            icon: AppIcons.service,
            label: AppStrings.nav.createService,
            gradient: true,
            onTap: onCreateTransaction,
          ),
          const SizedBox(height: 6),
          _ActionButton(
            icon: SolarIconsOutline.cartLarge,
            label: AppStrings.nav.sellProduct,
            gradient: false,
            isDark: isDark,
            onTap: onCreateSale,
          ),
          const SizedBox(height: 12),
        ],
      );
    }
    // Compact icon-only
    return Column(
      children: [
        _RailIconAction(
          icon: AppIcons.service,
          tooltip: AppStrings.nav.createService,
          onTap: onCreateTransaction,
          accent: true,
        ),
        const SizedBox(height: 6),
        _RailIconAction(
          icon: SolarIconsOutline.cartLarge,
          tooltip: AppStrings.nav.sellProduct,
          onTap: onCreateSale,
          accent: false,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool gradient;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    this.isDark = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient ? AppColors.primaryGradient(context) : null,
            color: gradient
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: gradient
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.obsidianBase),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gradient
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.obsidianBase),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;
  final bool isDark;

  const _RailIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 42,
          decoration: BoxDecoration(
            gradient: accent ? AppColors.primaryGradient(context) : null,
            color: accent
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: accent
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.obsidianBase),
          ),
        ),
      ),
    );
  }
}

// ─── Rail: Nav Item ──────────────────────────────────────────

class _RailNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool extended;
  final bool isDark;
  final VoidCallback onTap;

  const _RailNavItem({
    required this.item,
    required this.isSelected,
    required this.extended,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : Colors.grey;
    final selectedBg = theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.10);

    if (extended) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? item.iconSelected : item.icon,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Icon-only compact
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? item.iconSelected : item.icon,
              size: 22,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Rail: Context Action (per active tab) ───────────────────

class _RailContextAction extends StatelessWidget {
  final int currentIndex;
  final bool extended;
  final bool isDark;
  final VoidCallback onCreatePelanggan;
  final VoidCallback onCreateBarang;

  const _RailContextAction({
    required this.currentIndex,
    required this.extended,
    required this.isDark,
    required this.onCreatePelanggan,
    required this.onCreateBarang,
  });

  @override
  Widget build(BuildContext context) {
    if (currentIndex == 2) {
      return _contextButton(
        icon: LucideIcons.userPlus,
        label: 'Pelanggan Baru',
        onTap: onCreatePelanggan,
      );
    }
    if (currentIndex == 1) {
      return _contextButton(
        icon: LucideIcons.packagePlus,
        label: 'Tambah Barang',
        onTap: onCreateBarang,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _contextButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    if (extended) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: _ActionButton(
          icon: icon,
          label: label,
          gradient: false,
          isDark: isDark,
          onTap: onTap,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: _RailIconAction(
        icon: icon,
        tooltip: label,
        onTap: onTap,
        accent: false,
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE BODY — shared across layouts
// ─────────────────────────────────────────────────────────────

class _PageBody extends StatelessWidget {
  final PageController pageController;
  final void Function(int) onPageChanged;

  const _PageBody({
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: onPageChanged,
      children: const [
        HomeScreen(),
        KatalogScreen(mainPageController: null),
        PelangganScreen(),
        HistoryScreen(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL PANE PLACEHOLDER
// ─────────────────────────────────────────────────────────────

class _DetailPanePlaceholder extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _DetailPanePlaceholder({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark
          ? AppColors.surfaceLow.withValues(alpha: 0.5)
          : AppColors.lightSurfaceLow.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                SolarIconsOutline.letter,
                size: 32,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih item untuk\nmelihat detail',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPACT HELPERS  (Bottom Bar, FAB icon, Expanded Menu)
// ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final bool isDark;

  const _BottomBar({
    required this.currentIndex,
    required this.onNavigate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildItem(context, 0, SolarIconsOutline.home, AppStrings.nav.home),
            _buildItem(context, 1, SolarIconsOutline.box, AppStrings.nav.inventory),
            const SizedBox(width: 40),
            _buildItem(context, 2, SolarIconsOutline.usersGroupTwoRounded, AppStrings.nav.customers),
            _buildItem(context, 3, SolarIconsOutline.history, AppStrings.nav.history),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onNavigate(index);
      },
      borderRadius: BorderRadius.circular(16),
      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 72,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutQuart,
              transform: Matrix4.translationValues(0, isSelected ? -3 : 0, 0)
                ..multiply(Matrix4.diagonal3Values(isSelected ? 1.15 : 1.0, isSelected ? 1.15 : 1.0, 1.0)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutQuart,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                height: 1.0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabIcon extends StatelessWidget {
  final int currentIndex;
  final bool isMenuExpanded;
  final WidgetRef ref;

  const _FabIcon({
    required this.currentIndex,
    required this.isMenuExpanded,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (isMenuExpanded || (currentIndex == 3 && isMenuExpanded)) {
      // Note: isMenuExpanded here refers to the FAB state, but we need to handle history too
      // Actually, in the caller we pass _isMenuExpanded or _isHistoryMenuExpanded
      return const Icon(Icons.close, key: ValueKey('close'), color: Colors.white);
    }
    switch (currentIndex) {
      case 0:
        return const Icon(Icons.add, key: ValueKey('add'), color: Colors.white);
      case 1:
        final activeKatalogTab = ref.watch(katalogActiveTabProvider);
        return Icon(
          activeKatalogTab == 0 ? LucideIcons.packagePlus : LucideIcons.filePlus,
          key: ValueKey('katalog_$activeKatalogTab'),
          color: Colors.white,
        );
      case 2:
        return const Icon(LucideIcons.userPlus, key: ValueKey('user'), color: Colors.white);
      case 3:
        return const Icon(Icons.add, key: ValueKey('history_add'), color: Colors.white);
      default:
        return const Icon(Icons.add, key: ValueKey('default'), color: Colors.white);
    }
  }
}

class _FabExpandedMenu extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onCreateTransaction;
  final VoidCallback onCreateSale;

  const _FabExpandedMenu({
    required this.onDismiss,
    required this.onCreateTransaction,
    required this.onCreateSale,
  });

  @override
  Widget build(BuildContext context) {
    final double centerX = MediaQuery.of(context).size.width / 2;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: BackdropFilter(
                  filter: java_ui.ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
                  child: Container(color: Colors.black.withValues(alpha: 0.4 * value)),
                ),
              ),
            ),
            Positioned(
              bottom: 120 + (30 * (1 - value)),
              left: centerX - 120,
              child: Opacity(
                opacity: value,
                child: _MenuOption(
                  icon: AppIcons.service,
                  label: 'Servis',
                  onTap: onCreateTransaction,
                ),
              ),
            ),
            Positioned(
              bottom: 120 + (30 * (1 - value)),
              right: centerX - 120,
              child: Opacity(
                opacity: value,
                child: _MenuOption(
                  icon: SolarIconsOutline.cartLarge,
                  label: 'Jual Barang',
                  onTap: onCreateSale,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPER FUNCTION — openDetailOrPush
// Gunakan di tap handler untuk adaptasi expanded / compact mode
// ─────────────────────────────────────────────────────────────

class _FabHistoryMenu extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onScanExpense;
  final VoidCallback onCreateExpense;

  const _FabHistoryMenu({
    required this.onDismiss,
    required this.onScanExpense,
    required this.onCreateExpense,
  });

  @override
  Widget build(BuildContext context) {
    final double centerX = MediaQuery.of(context).size.width / 2;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: BackdropFilter(
                  filter: java_ui.ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
                  child: Container(color: Colors.black.withValues(alpha: 0.4 * value)),
                ),
              ),
            ),
            Positioned(
              bottom: 120 + (30 * (1 - value)),
              left: centerX - 120,
              child: Opacity(
                opacity: value,
                child: _MenuOption(
                  icon: SolarIconsOutline.camera,
                  label: 'Scan Nota',
                  onTap: onScanExpense,
                ),
              ),
            ),
            Positioned(
              bottom: 120 + (30 * (1 - value)),
              right: centerX - 120,
              child: Opacity(
                opacity: value,
                child: _MenuOption(
                  icon: SolarIconsOutline.addCircle,
                  label: 'Manual',
                  onTap: onCreateExpense,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper function — gunakan di tap handler saat memilih item detail
void openDetailOrPush({
  required BuildContext context,
  required WidgetRef ref,
  required Widget detailContent,
  required Widget Function() routeBuilder,
}) {
  final width = MediaQuery.of(context).size.width;
  if (width > 840) {
    ref.read(detailPaneProvider.notifier).state = detailContent;
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => routeBuilder()),
    );
  }
}
