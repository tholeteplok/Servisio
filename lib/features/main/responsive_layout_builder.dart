// ============================================================
// responsive_layout_builder.dart
// Responsive utilities — ServisLog+
//
// Menyediakan:
//   - ResponsiveContext extension  (isCompact, isMedium, isExpanded, dll)
//   - ResponsiveLayoutBuilder      (widget builder per breakpoint)
//   - BreakpointScope              (InheritedWidget opsional)
//   - ResponsivePadding            (padding adaptif)
//   - AdaptiveGrid                 (grid adaptif)
//   - DetailPaneHeader             (header panel kanan expanded)
//   - AdaptiveNavigator            (navigasi adaptif)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import 'adaptive_layout.dart';

// ─────────────────────────────────────────────────────────────
// BREAKPOINT CONSTANTS
// ─────────────────────────────────────────────────────────────

const double kCompactBreakpoint = 600.0;
const double kExpandedBreakpoint = 840.0;

// ─────────────────────────────────────────────────────────────
// CONTEXT EXTENSION — konveniensi akses breakpoint
// ─────────────────────────────────────────────────────────────

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isCompact => screenWidth < kCompactBreakpoint;
  bool get isMedium =>
      screenWidth >= kCompactBreakpoint && screenWidth < kExpandedBreakpoint;
  bool get isExpanded => screenWidth >= kExpandedBreakpoint;

  bool get hasRail => screenWidth >= kCompactBreakpoint;
  bool get hasDetailPane => screenWidth >= kExpandedBreakpoint;

  LayoutBreakpoint get breakpoint => getBreakpoint(screenWidth);
}

// ─────────────────────────────────────────────────────────────
// RESPONSIVE LAYOUT BUILDER
// ─────────────────────────────────────────────────────────────

/// Builder yang menyediakan widget berbeda tergantung breakpoint.
///
/// ```dart
/// ResponsiveLayoutBuilder(
///   compact: (ctx) => MobileWidget(),
///   medium:  (ctx) => TabletWidget(),       // optional
///   expanded: (ctx) => DesktopPane(),
/// )
/// ```
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext) compact;
  final Widget Function(BuildContext)? medium;
  final Widget Function(BuildContext) expanded;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.compact,
    this.medium,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bp = getBreakpoint(constraints.maxWidth);
        return switch (bp) {
          LayoutBreakpoint.compact => compact(context),
          LayoutBreakpoint.medium => (medium ?? expanded)(context),
          LayoutBreakpoint.expanded => expanded(context),
        };
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BREAKPOINT SCOPE — InheritedWidget (opsional)
// ─────────────────────────────────────────────────────────────

/// Menyimpan breakpoint saat ini di widget tree.
/// Berguna untuk widget-widget deep-nested yang butuh tahu breakpoint
/// tanpa melakukan LayoutBuilder sendiri.
///
/// Biasanya tidak perlu — gunakan [ResponsiveContext] extension.
class BreakpointScope extends InheritedWidget {
  final LayoutBreakpoint breakpoint;

  const BreakpointScope({
    super.key,
    required this.breakpoint,
    required super.child,
  });

  static BreakpointScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BreakpointScope>();
  }

  /// Convenience — returns current breakpoint or falls back to context width.
  static LayoutBreakpoint read(BuildContext context) {
    return BreakpointScope.of(context)?.breakpoint ??
        getBreakpoint(MediaQuery.of(context).size.width);
  }

  @override
  bool updateShouldNotify(BreakpointScope oldWidget) =>
      breakpoint != oldWidget.breakpoint;
}

// ─────────────────────────────────────────────────────────────
// RESPONSIVE PADDING
// ─────────────────────────────────────────────────────────────

/// Padding adaptif berdasarkan breakpoint.
///
/// ```dart
/// ResponsivePadding(
///   compact:  EdgeInsets.symmetric(horizontal: 16),
///   expanded: EdgeInsets.symmetric(horizontal: 32),
///   child: MyWidget(),
/// )
/// ```
class ResponsivePadding extends StatelessWidget {
  final EdgeInsetsGeometry compact;
  final EdgeInsetsGeometry? medium;
  final EdgeInsetsGeometry expanded;
  final Widget child;

  const ResponsivePadding({
    super.key,
    required this.compact,
    this.medium,
    required this.expanded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry padding;
    if (context.isExpanded) {
      padding = expanded;
    } else if (context.isMedium) {
      padding = medium ?? expanded;
    } else {
      padding = compact;
    }
    return Padding(padding: padding, child: child);
  }
}

// ─────────────────────────────────────────────────────────────
// ADAPTIVE GRID
// ─────────────────────────────────────────────────────────────

/// Grid columns adaptif:
///   compact  → compactColumns (default: 2)
///   medium   → mediumColumns  (default: 3)
///   expanded → expandedColumns (default: 4)
///
/// ```dart
/// AdaptiveGrid(
///   compactColumns: 1,
///   expandedColumns: 3,
///   children: items.map((e) => ItemCard(e)).toList(),
/// )
/// ```
class AdaptiveGrid extends StatelessWidget {
  final int compactColumns;
  final int? mediumColumns;
  final int expandedColumns;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final List<Widget> children;

  const AdaptiveGrid({
    super.key,
    this.compactColumns = 2,
    this.mediumColumns,
    this.expandedColumns = 4,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1.0,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final int columns;
    if (context.isExpanded) {
      columns = expandedColumns;
    } else if (context.isMedium) {
      columns = mediumColumns ?? ((compactColumns + expandedColumns) ~/ 2);
    } else {
      columns = compactColumns;
    }

    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL PANE HEADER
// Header khusus untuk konten yang ditampilkan di kolom Detail Pane
// ─────────────────────────────────────────────────────────────

class DetailPaneHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final Color? accent;

  const DetailPaneHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onClose,
    this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = accent ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: effectiveAccent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ...actions,
          if (onClose != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              iconSize: 20,
              tooltip: 'Tutup',
              onPressed: () {
                ref.read(detailPaneProvider.notifier).state = null;
                onClose?.call();
              },
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADAPTIVE NAVIGATOR
// Push route biasa di compact/medium, update detail pane di expanded
// ─────────────────────────────────────────────────────────────

class AdaptiveNavigator {
  AdaptiveNavigator._();

  /// Gunakan ini pengganti [Navigator.push] untuk navigasi yang responsive.
  ///
  /// Di **compact/medium**: push route baru ke navigator stack.
  /// Di **expanded**: tampilkan widget sebagai konten di detail pane.
  ///
  /// ```dart
  /// AdaptiveNavigator.push(
  ///   context: context,
  ///   ref: ref,
  ///   routeBuilder: () => TransactionDetailScreen(transaction: trx),
  ///   detailContent: TransactionDetailScreen(transaction: trx),
  /// );
  /// ```
  static void push({
    required BuildContext context,
    required WidgetRef ref,
    required Widget detailContent,
    required Widget Function() routeBuilder,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= kExpandedBreakpoint) {
      // Expanded mode: tampilkan detail pane
      ref.read(detailPaneProvider.notifier).state = detailContent;
    } else {
      // Compact/Medium mode: push route biasa
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => routeBuilder()),
      );
    }
  }

  /// Kosongkan detail pane (tutup konten).
  static void closeDetailPane(WidgetRef ref) {
    ref.read(detailPaneProvider.notifier).state = null;
  }

  /// Apakah saat ini dalam expanded mode (detail pane tersedia).
  static bool isExpandedMode(BuildContext context) {
    return MediaQuery.of(context).size.width >= kExpandedBreakpoint;
  }
}
