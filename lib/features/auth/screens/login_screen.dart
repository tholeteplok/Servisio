import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_logger.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      
      appLogger.info('DEBUG: Starting Google Sign In process...');
      final cred = await authService.signInWithGoogle();
      
      if (cred == null && mounted) {
        appLogger.info('DEBUG: Google Sign In cancelled by user or timed out');
        setState(() {
          _error = 'Otentikasi dibatalkan atau waktu habis.';
        });
        return;
      }

      appLogger.info('DEBUG: Firebase Auth success for user: ${cred?.user?.uid}');
      // We don't stop loading here because we expect AuthGate to transition 
      // when authStateProvider resolves the profile.
    } catch (e) {
      appLogger.error('DEBUG: Login process caught error', error: e);
      if (mounted) {
        setState(() {
          _error = 'Otentikasi Gagal: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for background errors from profile resolution
    // Watch for background errors or state changes
    ref.listen<AsyncValue<AuthStateContainer>>(authStateProvider, (previous, next) {
      next.when(
        data: (container) {
          if (container.state == AuthState.unauthenticated && container.isError) {
            if (mounted) {
              setState(() {
                _error = container.errorMessage;
                _isLoading = false;
              });
            }
          }
        },
        loading: () {
          // Keep showing locally initiated loading
        },
        error: (err, stack) {
          if (mounted) {
            setState(() {
              _error = 'Kesalahan otentikasi: $err';
              _isLoading = false;
            });
          }
        },
      );
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.obsidianBase : AppColors.atelierBase,
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.precisionViolet.withValues(alpha: isDark ? 0.05 : 0.03),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // App Identity
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.03) 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.05) 
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                      boxShadow: isDark ? [] : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Image.asset(
                      'assets/icons/app_icons.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,  
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Branding Text
                Text(
                  'ServisLog+',
                  style: GoogleFonts.manrope(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: isDark ? Colors.white : AppColors.obsidianBase,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.precisionViolet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PLATFORM WORKSHOP PROFESIONAL',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.precisionViolet,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Manajemen rincian Teknisi, Inventaris,\ndan Pendapatan secara real-time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),

                const Spacer(flex: 3),

                // Error handling UI
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(SolarIconsOutline.danger, color: AppColors.error, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Authentication Action
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.precisionViolet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        shadowColor: AppColors.precisionViolet.withValues(alpha: 0.3),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(SolarIconsBold.login, size: 20),
                                const SizedBox(width: 16),
                                Text(
                                  'Masuk dengan Akun Google',
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Footer Metadata
                Text(
                  'Precision Atelier v1.2 • Protected Enclave',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
