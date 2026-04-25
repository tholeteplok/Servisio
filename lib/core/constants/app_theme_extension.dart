import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extension to provide custom brand colors in Theme.of(context)
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color? buttonAccent;
  final Color? fontAccent;

  const AppThemeExtension({this.buttonAccent, this.fontAccent});

  @override
  AppThemeExtension copyWith({Color? buttonAccent, Color? fontAccent}) {
    return AppThemeExtension(
      buttonAccent: buttonAccent ?? this.buttonAccent,
      fontAccent: fontAccent ?? this.fontAccent,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      buttonAccent: Color.lerp(buttonAccent, other.buttonAccent, t),
      fontAccent: Color.lerp(fontAccent, other.fontAccent, t),
    );
  }
}

/// Helper extension to access these colors via theme
extension AppThemeExtensionX on ThemeData {
  Color get buttonAccentColor =>
      extension<AppThemeExtension>()?.buttonAccent ?? Colors.blue;
  Color get fontAccentColor =>
      extension<AppThemeExtension>()?.fontAccent ?? Colors.black;

  TextStyle get sectionLabelStyle => GoogleFonts.manrope(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: colorScheme.primary.withValues(alpha: 0.7),
  );

  TextStyle get displayMetricStyle => GoogleFonts.manrope(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: brightness == Brightness.dark ? Colors.white : Colors.black87,
  );

  TextStyle get precisionHeaderStyle => GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: brightness == Brightness.dark ? Colors.white : Colors.black87,
  );

  TextStyle get bodyMediumStyle => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: brightness == Brightness.dark ? Colors.white70 : Colors.black54,
  );
}

