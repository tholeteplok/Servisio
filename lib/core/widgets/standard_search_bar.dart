import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

class StandardSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autoFocus;
  final Widget? suffix;

  const StandardSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autoFocus = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme-adaptive colors
    final accentColor = theme.colorScheme.primary;
    final glassColor = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.08) 
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autoFocus,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: accentColor,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  SolarIconsOutline.magnifier,
                  color: accentColor.withValues(alpha: 0.7),
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 0,
                ),
                suffixIcon: suffix,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }
}

