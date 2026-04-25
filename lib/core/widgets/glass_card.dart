import 'package:flutter/material.dart';
import 'dart:ui';

/// Reusable Glassmorphism Card with high-performance optimization.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double opacity;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.blur = 15,
    this.opacity = 0.1,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.08),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border, // Defaulting to null/no border unless explicitly provided
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

