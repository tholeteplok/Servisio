import 'package:flutter/services.dart';

/// Formatter untuk Plat Nomor Kendaraan Indonesia (Nopol).
/// Mengubah format b1234abc menjadi B 1234 ABC secara otomatis.
class IndonesianLicensePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Normalized text (Uppercase and no spaces)
    final text = newValue.text.replaceAll(' ', '').toUpperCase();
    
    // Pattern Dasar Plate Indonesia:
    // [Kode Area: 1-2 Huruf] [Nomor: 1-4 Angka] [Suffix: 1-3 Huruf]
    
    String formatted = '';
    
    // 1. Ekstrak Kode Area (1-2 huruf di awal)
    final areaMatch = RegExp(r'^([A-Z]{1,2})').firstMatch(text);
    if (areaMatch != null) {
      formatted = areaMatch.group(1)!;
      final remainingAfterArea = text.substring(formatted.length);
      
      if (remainingAfterArea.isNotEmpty) {
        // 2. Ekstrak Nomor (1-4 angka berikutnya)
        final numberMatch = RegExp(r'^(\d{1,4})').firstMatch(remainingAfterArea);
        if (numberMatch != null) {
          final number = numberMatch.group(1)!;
          formatted += ' $number';
          final remainingAfterNumber = remainingAfterArea.substring(number.length);
          
          if (remainingAfterNumber.isNotEmpty) {
            // 3. Ekstrak Suffix (sisa huruf, limit 3)
            final suffixMatch = RegExp(r'^([A-Z]{1,3})').firstMatch(remainingAfterNumber);
            if (suffixMatch != null) {
              formatted += ' ${suffixMatch.group(1)!}';
            } else {
              // Jika karakter sisa bukan huruf, tetap tampilkan tanpa spasi tambahan
              formatted += ' $remainingAfterNumber';
            }
          }
        } else {
          // Jika setelah kode area bukan angka, kemungkinan sedang diketik
          formatted += ' $remainingAfterArea';
        }
      }
    } else {
      // Jika tidak mengikuti pola standar (misal diawali angka), biarkan kapital saja
      formatted = text;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

