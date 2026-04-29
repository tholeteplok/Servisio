import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../core/widgets/atelier_header.dart';
import 'package:servisio_core/core/providers/stats_provider.dart';
import '../../core/widgets/atelier_skeleton.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/services/session_manager.dart';
import '../../core/providers/system_providers.dart';
import '../../core/utils/app_logger.dart';

// Tabs
import 'tabs/ringkasan_tab.dart';
import 'tabs/pemasukan_tab.dart';
import 'tabs/pengeluaran_tab.dart';
import 'tabs/teknisi_tab.dart';
import 'tabs/hutang_tab.dart';

class StatistikScreen extends ConsumerStatefulWidget {
  const StatistikScreen({super.key});

  @override
  ConsumerState<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends ConsumerState<StatistikScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isPrivate = true;
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    
    // ⚡ OPTIMISTIC CHECK: Jika akses sudah penuh (diverifikasi sebelumnya), skip skeleton.
    final currentAccess = ref.read(currentAccessLevelProvider);
    if (currentAccess == AccessLevel.full) {
      _isLoading = false;
    } else {
      _isLoading = true;
    }

    // 🛡️ SECURITY CHECK: Jalankan verifikasi di latar belakang.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkSecurity();
    });
  }

  Future<void> _checkSecurity() async {
    if (!mounted) return;
    
    setState(() => _isVerifying = true);

    try {
      // 🔐 Verifikasi identitas (Biometrik/PIN). 
      // Jika sudah diverifikasi sebelumnya dalam sesi ini, ini akan langsung return true.
      final verified = await CriticalActionGuard.check(
        ref,
        context,
        CriticalActionType.viewFinancials,
      );
      
      if (verified) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isVerifying = false;
          });
        }
      } else {
        // Jika batal/gagal, kembali ke layar sebelumnya.
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      appLogger.error('Security check error', context: 'StatistikScreen', error: e);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHeader(theme),
              Positioned(
                bottom: -28,
                left: 0,
                right: 0,
                child: _buildTabBar(theme),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Stack(
              children: [
                // Layer Utama: Data atau Skeleton
                if (_isLoading)
                  _buildSkeletonView(theme)
                else
                  TabBarView(
                    controller: _tabController,
                    children: [
                      RingkasanTab(isPrivate: _isPrivate),
                      const PemasukanTab(),
                      const PengeluaranTab(),
                      const HutangTab(),
                      TeknisiTab(isPrivate: _isPrivate),
                    ],
                  ),
                
                // Layer Keamanan: Hanya muncul jika proses verifikasi memakan waktu (misal: jaringan lambat)
                if (_isVerifying)
                  _buildSecurityOverlay(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: AtelierSkeleton.statCard()),
              const SizedBox(width: 12),
              Expanded(child: AtelierSkeleton.statCard()),
            ],
          ),
          const SizedBox(height: 12),
          AtelierSkeleton.custom(
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AtelierSkeleton.listOf(3, () => AtelierSkeleton.listItem()),
        ],
      ),
    );
  }

  Widget _buildSecurityOverlay(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary, 
            ),
            const SizedBox(height: 20),
            Text(
              'Menyiapkan Kunci Keamanan...',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan koneksi internet stabil',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return AtelierHeaderSub(
      title: 'Analisis Bisnis',
      showBackButton: true,
      onBackPressed: () => Navigator.pop(context),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      showWorkshopSelector: false,
      bottomPadding: 44,
      actions: [
        IconButton(
          onPressed: () => setState(() => _isPrivate = !_isPrivate),
          icon: Icon(
            _isPrivate ? SolarIconsOutline.eyeClosed : SolarIconsOutline.eye,
            color: Colors.white,
          ),
          tooltip: 'Visibilitas',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            ref.invalidate(statsProvider);
          },
          icon: const Icon(
            SolarIconsOutline.refresh,
            color: Colors.white,
          ),
          tooltip: 'Segarkan',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
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
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'Ringkasan'),
          Tab(text: 'Pemasukan'),
          Tab(text: 'Pengeluaran'),
          Tab(text: 'Hutang'),
          Tab(text: 'Teknisi'),
        ],
      ),
    );
  }
}

