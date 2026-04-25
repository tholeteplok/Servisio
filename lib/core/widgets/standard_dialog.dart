import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StandardDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final Color? primaryActionColor;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final List<Widget>? customActions;
  final Widget? extraContent;

  const StandardDialog({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionColor,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.customActions,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(height: 20),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            if (extraContent != null) ...[
              const SizedBox(height: 24),
              extraContent!,
            ],
            const SizedBox(height: 32),
            if (customActions != null)
              Column(children: customActions!)
            else
              Row(
                children: [
                  if (secondaryActionLabel != null)
                    Expanded(
                      child: TextButton(
                        onPressed: onSecondaryAction ?? () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          secondaryActionLabel!.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: (isDark ? Colors.white : Colors.black87)
                                .withValues(alpha: 0.3),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  if (secondaryActionLabel != null && primaryActionLabel != null)
                    const SizedBox(width: 16),
                  if (primaryActionLabel != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimaryAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryActionColor ?? theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          primaryActionLabel!.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

