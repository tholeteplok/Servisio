import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/atelier_skeleton.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/services/session_manager.dart';
import '../../core/providers/system_providers.dart';

// Tabs
import 'tabs/pendapatan_tab.dart';
import 'tabs/layanan_tab.dart';
import 'tabs/produk_tab.dart';
import 'tabs/teknisi_tab.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    
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
      debugPrint('❌ StatistikScreen: Security check error: $e');
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

    // UI Statistik sekarang tersentralisasi dalam satu Scaffold agar transisi mulus.
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(theme),
          _buildTabBar(theme),
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
                      PendapatanTab(isPrivate: _isPrivate),
                      const LayananTab(),
                      const ProdukTab(),
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
      padding: const EdgeInsets.all(20),
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
      color: theme.colorScheme.surface.withValues(alpha: 0.8), // Sedikit lebih opaque agar tidak distraktif
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
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan koneksi internet stabil',
              style: TextStyle(
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
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 12, 20, 24),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient(context),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  LucideIcons.chevronLeft,
                  color: theme.colorScheme.onPrimary,
                ),
                tooltip: 'Kembali',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _isPrivate = !_isPrivate),
                    icon: Icon(
                      _isPrivate ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: theme.colorScheme.onPrimary,
                    ),
                    tooltip: 'Visibilitas',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                        // Refresh logic here if needed, or just visual
                    },
                    icon: Icon(
                      LucideIcons.refreshCw,
                      color: theme.colorScheme.onPrimary,
                    ),
                    tooltip: 'Segarkan',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Analisis Bisnis',
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onPrimary,
              letterSpacing: -1.0,
            ),
          ),
          Text(
            'Laporan performa bengkel secara real-time',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Ringkasan'),
          Tab(text: 'Layanan'),
          Tab(text: 'Produk'),
          Tab(text: 'Teknisi'),
        ],
      ),
    );
  }
}
