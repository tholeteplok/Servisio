import 'package:flutter/services.dart';

/// Utility class for consistent haptic feedback across the app.
/// Provides standardized haptic feedback patterns for different user interactions.
class AppHaptic {
  /// Light impact - for subtle feedback (tapping buttons, selecting items)
  static void light() => HapticFeedback.lightImpact();

  /// Medium impact - for moderate feedback (confirming actions, toggling switches)
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy impact - for strong feedback (deleting, completing important actions)
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection click - for picker/selection interactions
  static void selection() => HapticFeedback.selectionClick();

  /// Success pattern - light then medium for positive feedback
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  /// Error pattern - double heavy for error feedback
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}

