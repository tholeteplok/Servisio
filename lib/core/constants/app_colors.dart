import 'package:flutter/material.dart';

class AppColors {
  // ── Constant Colors ──
  static const Color precisionViolet = Color(0xFFAFA2FF); // Softer, premium violet
  static const Color neonGreen = Color(0xFF00E676); 
  static const Color accent = Color(0xFFFF7052); 
  static const Color whatsapp = Color(0xFF25D366); 

  // ── Midnight Palette (OLED/WatchOS Style) ──
  // ── Obsidian Palette (Precision Engine - Dark) ──
  static const Color obsidianBase = Color(0xFF0E0E0E); 
  static const Color surfaceLow = Color(0xFF131313); 
  static const Color surfaceHigh = Color(0xFF20201F);
  static const Color surfaceHighest = Color(0xFF262626);
  static const Color darkFontAccent = Color(0xFFE7DBEF);

  // ── Atelier Palette (Precision Atelier - Light) ──
  static const Color atelierBase = Color(0xFFF3FAFF); // Industrial Off-White
  static const Color lightSurfaceLow = Color(0xFFE6F6FF); // Alice Blue
  static const Color lightSurfaceHigh = Color(0xFFFFFFFF);
  static const Color lightSurfaceHighest = Color(0xFFCFE6F2);
  static const Color lightFontAccent = Color(0xFF4A3F58); 

  // ── Status Colors (Semantic) ──
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB40);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF40C4FF);

  // ── Legacy Aliases (For Backward Compatibility during Migration) ──
  static const Color amethyst = precisionViolet;
  static const Color darkBg = obsidianBase;
  static const Color darkSurface = surfaceLow;
  static const Color darkSurfaceLighter = surfaceHighest;

  // ── Aliases (Dynamic/Semantic) ──
  static const Color primaryBackground = obsidianBase;
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9E9E9E);


  // ── Additional Colors Palette ──
  static const Color lightSkyBlue = Color(0xFF7ECDF4); // Light Sky Blue
  static const Color mintMajesty = Color(0xFF78D6B9); // Mint Majesty
  static const Color ninjinOrange = Color(0xFFE5A273); // Ninjin Orange
  static const Color strawberryFields = Color(0xFFF98A8B); // Strawberry Fields
  static const Color kiwiGreen = Color(0xFF89E900); // Kiwi Green

  // ── Gradients ──
  static LinearGradient primaryGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          kiwiGreen,
          kiwiGreen.withValues(alpha: 0.5),
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        precisionViolet, 
        lightSkyBlue.withValues(alpha: 0.5),
      ],
    );
  }

  static Gradient headerGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return RadialGradient(
        center: const Alignment(-1.1, -1.1),
        radius: 1.5,
        colors: [
          mintMajesty,
          obsidianBase.withValues(alpha: 0.5),
        ],
      );
    }
    return RadialGradient(
        center: const Alignment(-1.1, -1.1),
        radius: 1.5,
        colors: [
          precisionViolet,
          mintMajesty.withValues(alpha: 0.5),
        ],
        stops: const [0.6, 1.0],
    );
  }

  static LinearGradient glassGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.05),
        ],
      );
    }
    return LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.7),
        Colors.white.withValues(alpha: 0.4),
      ],
    );
  }
}

