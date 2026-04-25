import 'package:flutter/services.dart';

/// A [TextInputFormatter] that automatically formats phone numbers to the Indonesian
/// international format (+62).
///
/// It handles:
/// - Converting leading '0' to '+62'.
/// - Ensuring the '+62' prefix is always present.
/// - Filtering out non-digit characters after the prefix.
class IndonesianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String newText = newValue.text;

    // If the field is cleared, allow it
    if (newText.isEmpty) {
      return newValue;
    }

    // If typing '0' as the first character, transform to '+62'
    if (newText == '0' && oldValue.text.isEmpty) {
      return const TextEditingValue(
        text: '+62',
        selection: TextSelection.collapsed(offset: 3),
      );
    }

    String formatted = newText;

    // Handle leading '0' in multi-character strings
    if (formatted.startsWith('0')) {
      formatted = '+62${formatted.substring(1)}';
    }

    // Ensure it starts with '+62'
    if (!formatted.startsWith('+62')) {
      if (formatted.startsWith('62')) {
        formatted = '+$formatted';
      } else if (formatted.startsWith('+')) {
        // If it starts with + but not +62, assume they want +62
        final digits = formatted.replaceAll(RegExp(r'\D'), '');
        // If digits starts with 62, just add +
        if (digits.startsWith('62')) {
          formatted = '+$digits';
        } else {
          formatted = '+62$digits';
        }
      } else {
        // Prepend +62 to whatever was typed
        final digits = formatted.replaceAll(RegExp(r'\D'), '');
        formatted = '+62$digits';
      }
    }

    // Sanitize: Keep +62 and only digits after that
    const String prefix = '+62';
    if (formatted.length >= prefix.length) {
      final String rest = formatted.substring(prefix.length).replaceAll(RegExp(r'\D'), '');
      formatted = prefix + rest;
    }

    // Calculate selection offset adjustment
    int offset = newValue.selection.baseOffset;
    
    // If we transformed '0' to '+62', we added 2 characters
    if (newText.startsWith('0') && !oldValue.text.startsWith('+62')) {
      offset += 2;
    } else if (!newText.startsWith('+62') && formatted.startsWith('+62')) {
       // Calculation for generic prepend
       offset += (formatted.length - newText.length);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset.clamp(0, formatted.length)),
    );
  }
}

