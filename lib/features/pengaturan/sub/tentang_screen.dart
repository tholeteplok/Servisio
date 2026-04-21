import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/atelier_header.dart';

class TentangScreen extends StatefulWidget {
  const TentangScreen({super.key});

  @override
  State<TentangScreen> createState() => _TentangScreenState();
}

class _TentangScreenState extends State<TentangScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could $url not be launched');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── MODERN ATELIER HEADER SUB ──
          const SliverAtelierHeaderSub(
            title: 'Tentang',
            subtitle: 'Detail versi, tim pengembang, dan hukum.',
            showBackButton: true,
          ),

          // ── BRANDING SECTION ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  // ── ANIMATED APP ICON ──
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      height: 120,
                      width: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icons/app_icons.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'ServisI/O',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Versi 1.0.0 (Stable)',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── LINKS SECTION ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _LinkTile(
                    icon: SolarIconsOutline.fileText,
                    title: 'Syarat & Ketentuan',
                    onTap: () =>
                        _launchUrl('https://servisio.web.app/terms.html'),
                  ),
                  _LinkTile(
                    icon: SolarIconsOutline.questionCircle,
                    title: 'Bantuan & FAQ',
                    onTap: () =>
                        _launchUrl('https://servisio.web.app/faq.html'),
                  ),
                  _LinkTile(
                    icon: SolarIconsOutline.shieldCheck,
                    title: 'Kebijakan Privasi',
                    onTap: () =>
                        _launchUrl('https://servisio.web.app/privacy.html'),
                  ),
                  _LinkTile(
                    icon: SolarIconsOutline.star,
                    title: 'Beri Rating APLIKASI',
                    onTap: () => _launchUrl(
                      'https://play.google.com/store/apps/details?id=com.tholeteplok.servisio',
                    ),
                  ),
                  _LinkTile(
                    icon: SolarIconsOutline.letter,
                    title: 'Dukungan & Email',
                    onTap: () => _launchUrl('mailto:support.servisioapps@gmail.com'),
                  ),

                  const SizedBox(height: 60),
                  Text(
                    'Dibuat dengan ❤️ oleh Pengembang ServisI/O',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
          trailing: Icon(
            SolarIconsOutline.arrowRight,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Divider(
          height: 1,
          indent: 56,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
