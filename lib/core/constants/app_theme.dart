import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_theme_extension.dart';

class AppTheme {
  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color buttonAccent,
    Color? fontAccent,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [
        AppThemeExtension(fontAccent: fontAccent, buttonAccent: buttonAccent),
      ],
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: colorScheme.brightness).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.onSurface,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none, // "No-Line" rule implementation
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonAccent,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonAccent,
          side: BorderSide(color: buttonAccent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: buttonAccent,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonAccent,
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 6,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return buttonAccent;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return buttonAccent;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return buttonAccent.withValues(alpha: 0.5);
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: buttonAccent,
        inactiveTrackColor: buttonAccent.withValues(alpha: 0.2),
        thumbColor: buttonAccent,
        overlayColor: buttonAccent.withValues(alpha: 0.1),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return buttonAccent;
          return null;
        }),
      ),
    );
  }

  static ThemeData get light => _base(
    buttonAccent: AppColors.precisionViolet,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.precisionViolet,
          primary: AppColors.precisionViolet,
          secondary: AppColors.neonGreen,
          surface: AppColors.atelierBase,
          brightness: Brightness.light,
        ).copyWith(
          surfaceContainerHighest: AppColors.lightSurfaceHighest,
          surfaceContainerHigh: AppColors.lightSurfaceHigh,
          surfaceContainerLow: AppColors.lightSurfaceLow,
          outline: Colors.transparent,
        ),
  );
 
  static ThemeData get dark => _base(
    buttonAccent: AppColors.kiwiGreen,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.kiwiGreen,
          primary: AppColors.kiwiGreen,
          secondary: AppColors.precisionViolet,
          surface: AppColors.obsidianBase,
          brightness: Brightness.dark,
        ).copyWith(
          surfaceContainerHighest: AppColors.surfaceHighest,
          surfaceContainerHigh: AppColors.surfaceHigh,
          surfaceContainerLow: AppColors.surfaceLow,
          onSurface: const Color(0xFFF5F5F5),
          onSurfaceVariant: const Color(0xFF9E9E9E), 
          outline: Colors.transparent,
        ),
  );

  // Maintain aliases for backward compatibility if needed, but point to new logic
  static ThemeData get modernSiang => light;
  static ThemeData get modernMalam => dark;
}
