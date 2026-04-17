import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/atelier_skeleton.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/services/session_manager.dart';

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
    
    // 🛡️ SECURITY CHECK: Jalankan setelah frame pertama dirender
    // agar context valid dan UI sudah siap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSecurity();
    });
  }

  Future<void> _checkSecurity() async {
    if (!mounted) return;
    setState(() => _isVerifying = true);

    try {
      final verified = await CriticalActionGuard.check(
        ref,
        context,
        CriticalActionType.viewFinancials,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('⚠️ StatistikScreen: Security check global timeout');
          return false;
        },
      );
      
      if (verified) {
        if (mounted) setState(() => _isLoading = false);
      } else {
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Column(
          children: [
            _buildHeader(theme),
            _buildTabBar(theme),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AtelierSkeleton.listOf(3, () => AtelierSkeleton.listItem()),
                      ],
                    ),
                  ),
                  if (_isVerifying)
                    Container(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.precisionViolet,
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
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(theme),
          _buildTabBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PendapatanTab(isPrivate: _isPrivate),
                const LayananTab(),
                const ProdukTab(),
                TeknisiTab(isPrivate: _isPrivate),
              ],
            ),
          ),
        ],
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
                icon: const Icon(
                  LucideIcons.chevronLeft,
                  color: Colors.white,
                ),
                tooltip: 'Kembali',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _isPrivate = !_isPrivate),
                    icon: Icon(
                      _isPrivate ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: Colors.white,
                    ),
                    tooltip: 'Visibilitas',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                        // Refresh logic here if needed, or just visual
                    },
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: Colors.white,
                    ),
                    tooltip: 'Segarkan',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
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
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
          Text(
            'Laporan performa bengkel secara real-time',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLow : AppColors.lightSurfaceLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.precisionViolet,
          borderRadius: BorderRadius.circular(20),
        ),
        labelColor: isDark ? AppColors.obsidianBase : Colors.white,
        unselectedLabelColor: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black38,
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
