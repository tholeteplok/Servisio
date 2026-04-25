import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/system_providers.dart';
import 'create_bengkel_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _joinController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isJoining = false;
  bool _obscurePin = true;
  String? _joinError;
  String? _pinError;

  @override
  void dispose() {
    _joinController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.obsidianBase : AppColors.atelierBase,
      body: Stack(
        children: [
          // Ambient Background Glows (Matching Login Screen Consistency)
          Positioned(
            top: -150,
            left: -100,
            child: _buildGlowCircle(isDark, size: 400),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: _buildGlowCircle(isDark, size: 300),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    Text(
                      AppStrings.auth.welcomeTitle.replaceAll(' ', '\n'), // Visual break
                      style: GoogleFonts.manrope(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -1,
                        color: isDark ? Colors.white : AppColors.obsidianBase,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.auth.welcomeSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 80), // More space for overlapping assets
                    
                    _OptionCard(
                      isDark: isDark,
                      imageAsset: 'assets/illustrations/owner_icons.png',
                      accentColor: AppColors.precisionViolet,
                      title: AppStrings.auth.ownerTitle,
                      subtitle: AppStrings.auth.ownerSubtitle,
                      badge: AppStrings.auth.badgeExecutive,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateBengkelScreen()),
                      ),
                    ),
                    
                    const SizedBox(height: 60), // Space between cards to avoid overlap collisions
                    
                    _OptionCard(
                      isDark: isDark,
                      imageAsset: 'assets/illustrations/staff_icons.png',
                      accentColor: AppColors.neonGreen,
                      title: AppStrings.auth.staffTitle,
                      subtitle: AppStrings.auth.staffSubtitle,
                      badge: AppStrings.auth.badgeOperational,
                      onTap: () => _showJoinDialog(context, isDark),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    Center(
                      child: Column(
                        children: [
                          Text(
                            AppStrings.auth.loginDescription.split('\n').first,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => ref.read(authServiceProvider).signOut(),
                            child: Text(
                              '${AppStrings.common.logout} ${AppStrings.common.item}', // 'Keluar Akun' approx
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.precisionViolet.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowCircle(bool isDark, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.precisionViolet.withValues(alpha: isDark ? 0.05 : 0.03),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceLow : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              AppStrings.auth.staffTitle,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.obsidianBase,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.auth.staffSubtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    TextField(
                      controller: _joinController,
                      decoration: InputDecoration(
                        labelText: AppStrings.auth.workshopIdLabel,
                        hintText: AppStrings.auth.workshopIdHint,
                        prefixIcon: const Icon(SolarIconsOutline.key),
                        errorText: _joinError,
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.precisionViolet, width: 2),
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (_) => setModalState(() => _joinError = null),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: AppStrings.auth.enterPin,
                        hintText: AppStrings.auth.workshopIdHint, // Reusing hint pattern
                        prefixIcon: const Icon(SolarIconsOutline.lock),
                        counterText: '',
                        errorText: _pinError,
                        suffixIcon: IconButton(
                          onPressed: () => setModalState(() => _obscurePin = !_obscurePin),
                          icon: Icon(
                            _obscurePin ? SolarIconsOutline.eyeClosed : SolarIconsOutline.eye,
                            size: 20,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.precisionViolet, width: 2),
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (_) => setModalState(() => _pinError = null),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isJoining
                    ? null
                    : () {
                        final id = _joinController.text.trim();
                        final pin = _pinController.text.trim();
                        if (id.isEmpty || pin.length != 6) {
                          setState(() {
                            _joinError = id.isEmpty ? AppStrings.error.requiredField : null;
                            _pinError = pin.length != 6 ? AppStrings.error.pinTooShort : null;
                          });
                          return;
                        }
                        _joinBengkel(id, pin);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.precisionViolet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  shadowColor: AppColors.precisionViolet.withValues(alpha: 0.3),
                ),
                child: _isJoining
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Text(
                        AppStrings.common.confirm,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinBengkel(String bengkelId, String pin) async {
    setState(() => _isJoining = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Sesi berakhir, silahkan login kembali.');
      
      await ref.read(bengkelServiceProvider).joinBengkel(
        bengkelId: bengkelId,
        uid: user.uid,
        name: user.displayName ?? AppStrings.common.item,
        email: user.email ?? '',
        role: 'staff',
        pin: pin,
      );
      
      if (mounted) {
        ref.invalidate(authStateProvider);
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final err = e.toString().toLowerCase();
          if (err.contains('tidak ditemukan')) {
            _joinError = AppStrings.auth.idUnavailable;
          } else if (err.contains('pin salah')) {
            _pinError = AppStrings.auth.pinIncorrect;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sistem bermasalah: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }
}

class _OptionCard extends StatefulWidget {
  final bool isDark;
  final String imageAsset;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _OptionCard({
    required this.isDark,
    required this.imageAsset,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double cardWidth = double.infinity;
    const double imageSize = 140;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isHovered ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Card Container
            Container(
              width: cardWidth,
              padding: const EdgeInsets.fromLTRB(28, 70, 28, 28),
              decoration: BoxDecoration(
                gradient: AppColors.glassGradient(widget.isDark ? Brightness.dark : Brightness.light),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                ),
                boxShadow: widget.isDark ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          widget.badge,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: widget.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: widget.isDark ? Colors.white : AppColors.obsidianBase,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Overlapping Illustration with Floating Animation
            Positioned(
              top: -imageSize / 2, // 50% overlap
              right: 20,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 8 * Curves.easeInOut.transform(_floatController.value) - 4),
                    child: child,
                  );
                },
                child: Image.asset(
                  widget.imageAsset,
                  height: imageSize,
                  width: imageSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Interaction Indicator
            Positioned(
              bottom: 24,
              right: 24,
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 24,
                color: widget.accentColor.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


