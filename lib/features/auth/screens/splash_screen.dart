import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    
    _floatAnimation = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    

    _controller.forward();
    _floatController.repeat(reverse: true);
    
    // Preload assets & font
    _preloadAssets();
  }
  
  Future<void> _preloadAssets() async {
    await Future.wait([
      rootBundle.load('assets/icons/app_icons.png'),
      GoogleFonts.pendingFonts([
        GoogleFonts.manrope(),
        GoogleFonts.inter(),
      ]),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hardcoded branding color for both modes
    const brandColor = AppColors.precisionViolet;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: brandColor,
        body: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         // Application Icon - Simplified with thin shadow
                         AnimatedBuilder(
                           animation: _floatAnimation,
                           builder: (context, child) {
                             return Transform.translate(
                               offset: Offset(0, _floatAnimation.value),
                               child: ScaleTransition(
                                 scale: _scaleAnimation,
                                 child: Container(
                                   decoration: BoxDecoration(
                                     boxShadow: [
                                       BoxShadow(
                                         color: Colors.black.withValues(alpha: 0.15),
                                         blurRadius: 30,
                                         offset: const Offset(0, 15),
                                       ),
                                     ],
                                   ),
                                   child: Image.asset(
                                     'assets/icons/app_icons.png',
                                     width: 98,
                                     height: 98,
                                     fit: BoxFit.contain,
                                   ),
                                 ),
                               ),
                             );
                           },
                         ),
                        const SizedBox(height: 32),
                        
                        SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              Text(
                                'Servisio',
                                style: GoogleFonts.manrope(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.5,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manajemen Workshop Modern',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
  
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       const SizedBox(
                         width: 32,
                         height: 32,
                         child: CircularProgressIndicator(
                           strokeWidth: 3,
                           valueColor: AlwaysStoppedAnimation<Color>(
                             Colors.white,
                           ),
                         ),
                       ),
                      const SizedBox(height: 24),
                      Text(
                        'v1.2.0',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
