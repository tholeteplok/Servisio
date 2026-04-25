import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_haptic.dart';

class AtelierListGroup extends StatelessWidget {
  final List<Widget> children;
  final String? label;

  const AtelierListGroup({
    super.key,
    required this.children,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              label!.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
           decoration: BoxDecoration(
             color: isDark
                 ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                 : theme.colorScheme.surface,
             borderRadius: BorderRadius.circular(24),
             border: Border.all(
               color: isDark
                   ? Colors.white.withValues(alpha: 0.08)
                   : theme.colorScheme.outline.withValues(alpha: 0.12),
               width: 1.2,
             ),
             boxShadow: isDark
                 ? [
                     BoxShadow(
                       color: Colors.black.withValues(alpha: 0.12),
                       blurRadius: 16,
                       offset: const Offset(0, 6),
                       spreadRadius: -4,
                     ),
                   ]
                 : [
                     BoxShadow(
                       color: Colors.black.withValues(alpha: 0.04),
                       blurRadius: 24,
                       offset: const Offset(0, 8),
                       spreadRadius: -2,
                     ),
                     BoxShadow(
                       color: Colors.black.withValues(alpha: 0.02),
                       blurRadius: 8,
                       offset: const Offset(0, 2),
                     ),
                   ],
           ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class AtelierListTile extends StatelessWidget {

  const AtelierListTile({
    super.key,
    this.icon,
    this.iconColor,
    this.customLeading,
    this.title = '',
    this.customTitle,
    this.subtitle,
    this.customSubtitle,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.padding,
    this.semanticLabel,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? customLeading;
  final String title;
  final Widget? customTitle;
  final String? subtitle;
  final Widget? customSubtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildLeading() {
      if (customLeading != null) return customLeading!;
      if (icon != null && iconColor != null) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor!.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        );
      }
      return const SizedBox.shrink();
    }

    final leading = buildLeading();

    return Semantics(
      label: semanticLabel ?? title,
      button: true,
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            AppHaptic.light();
            onTap();
          },
          onLongPress: onLongPress != null
              ? () {
                  AppHaptic.medium();
                  onLongPress!();
                }
              : null,
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56), // Ensure 48dp+ hit target
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading is! SizedBox) ...[
                    leading,
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        customTitle ??
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                        if (customSubtitle != null || subtitle != null) ...[
                          const SizedBox(height: 4),
                          customSubtitle ??
                              Text(
                                subtitle!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AtelierSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AtelierSwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierListTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: iconColor,
        activeThumbColor: Colors.white,
      ),
    );
  }
}

