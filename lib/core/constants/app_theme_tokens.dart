import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// APP THEME TOKENS — Design System Constants
// ═════════════════════════════════════════════════════════════════════════════
// Centralized design tokens for consistent UI across the app.
// Based on the "Precision Atelier" design language.
// ═════════════════════════════════════════════════════════════════════════════

/// ─── SPACING ───
/// Standard spacing values for margins, paddings, and gaps.
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// ─── BORDER RADIUS ───
/// Standard border radius values for consistent corner rounding.
class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double full = 100.0; // For pill/circle shapes
}

/// ─── SHADOWS ───
/// Standard shadow presets for consistent elevation effects.
class AppShadows {
  /// Soft shadow - subtle elevation (cards, buttons)
  static List<BoxShadow> soft(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
        blurRadius: 16,
        offset: const Offset(0, 6),
        spreadRadius: -4,
      ),
    ];
  }

  /// Medium shadow - moderate elevation (modals, dialogs)
  static List<BoxShadow> medium(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 12),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Hard shadow - strong elevation (FAB, toasts, important CTAs)
  static List<BoxShadow> hard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.12),
        blurRadius: 32,
        offset: const Offset(0, 16),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.08),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

/// ─── ANIMATION DURATIONS ───
/// Standard animation durations for consistent motion.
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// ─── ANIMATION CURVES ───
/// Standard animation curves for consistent easing.
class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve accelerate = Curves.easeInOut;
  static const Curve bounce = Curves.easeOutBack;
}

/// ─── SKELETON LOADING ───
/// Standard skeleton animation settings.
class AppSkeleton {
  static const Duration period = Duration(milliseconds: 1200);
  static const double baseOpacity = 0.12;
  static const double highlightOpacity = 0.04;
}

/// ─── TOUCH TARGETS ───
/// Standard touch target sizes for accessibility compliance.
class AppTouchTargets {
  /// Minimum touch target size (48x48) - WCAG 2.1 AA compliant
  static const double minimum = 48.0;
  
  /// Comfortable touch target size (56x56) - recommended for primary actions
  static const double comfortable = 56.0;
}

/// ─── OPACITY VALUES ───
/// Standard opacity values for consistent transparency.
class AppOpacities {
  /// High emphasis text - 100% opacity
  static const double high = 1.0;
  
  /// Medium emphasis text - 70% opacity (WCAG AA compliant)
  static const double medium = 0.7;
  
  /// Low emphasis text - 50% opacity (use sparingly)
  static const double low = 0.5;
  
  /// Disabled state - 38% opacity
  static const double disabled = 0.38;
  
  /// Subtle background/wash - 12% opacity
  static const double subtle = 0.12;
}

/// ─── LETTER SPACING ───
/// Standard letter spacing values for consistent typography.
class AppLetterSpacing {
  /// Tight - for large headlines
  static const double tight = -0.5;
  
  /// Normal - for body text
  static const double normal = 0.0;
  
  /// Wide - for small text, labels, uppercase
  static const double wide = 0.8;
  
  /// Extra wide - for section headers (uppercase)
  static const double extraWide = 1.2;
}

/// ─── GAPS ───
/// Extension to easily add spacing using SizedBox (Gap pattern).
/// Usage: 16.gapY or AppSpacing.md.gapY
extension GapX on double {
  Widget get gapX => SizedBox(width: this);
  Widget get gapY => SizedBox(height: this);
}

