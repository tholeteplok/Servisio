import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/expense_category.dart';
import 'media_service.dart';

/// Hasil scanning nota via OCR + AI kategorisasi.
class ExpenseScanResult {
  final bool success;
  final int amount;
  final String category; // logicKey dari ExpenseCategory
  final DateTime date;
  final String fullText;
  final double confidence;
  final String? error;

  const ExpenseScanResult._({
    required this.success,
    required this.amount,
    required this.category,
    required this.date,
    required this.fullText,
    required this.confidence,
    this.error,
  });

  factory ExpenseScanResult.success({
    required int amount,
    required String category,
    required DateTime date,
    required String fullText,
    required double confidence,
  }) =>
      ExpenseScanResult._(
        success: true,
        amount: amount,
        category: category,
        date: date,
        fullText: fullText,
        confidence: confidence,
      );

  factory ExpenseScanResult.empty() => ExpenseScanResult._(
        success: false,
        amount: 0,
        category: 'LAINNYA',
        date: DateTime.now(),
        fullText: '',
        confidence: 0,
        error: 'Tidak ada teks yang terdeteksi pada gambar',
      );

  factory ExpenseScanResult.error(String message) => ExpenseScanResult._(
        success: false,
        amount: 0,
        category: 'LAINNYA',
        date: DateTime.now(),
        fullText: '',
        confidence: 0,
        error: message,
      );

  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.6 && confidence < 0.8;
}

/// Service untuk OCR nota menggunakan Google ML Kit Text Recognition.
/// Mengintegrasikan [MediaService.compressImageForOcr] sebelum pemrosesan
/// untuk menghemat memori dan meningkatkan akurasi deteksi.
class ExpenseAIService {
  final MediaService _mediaService;
  TextRecognizer? _textRecognizer;

  ExpenseAIService({MediaService? mediaService})
      : _mediaService = mediaService ?? MediaService();

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Scan gambar nota dan ekstrak data pengeluaran.
  Future<ExpenseScanResult> scanReceipt(File image) async {
    try {
      // 1. Kompres gambar sebelum OCR (hemat memori, tingkatkan akurasi)
      final compressedImage = await _mediaService.compressImageForOcr(image);
      final fileToProcess = compressedImage ?? image;

      // 2. Proses dengan ML Kit
      final inputImage = InputImage.fromFile(fileToProcess);
      final recognizedText = await _recognizer.processImage(inputImage);
      final fullText = recognizedText.text;

      debugPrint('📷 OCR Result (${fullText.length} chars): ${fullText.substring(0, fullText.length.clamp(0, 100))}...');

      if (fullText.trim().isEmpty) {
        return ExpenseScanResult.empty();
      }

      // 3. Ekstrak data
      final amount = _extractAmount(fullText);
      final date = _extractDate(fullText);
      final category = _categorizeExpense(fullText);

      // 4. Hitung confidence
      final confidence = _calculateConfidence(amount, category, fullText);

      return ExpenseScanResult.success(
        amount: amount,
        category: category,
        date: date,
        fullText: fullText,
        confidence: confidence,
      );
    } catch (e, st) {
      debugPrint('❌ ExpenseAIService error: $e\n$st');
      return ExpenseScanResult.error('Gagal memproses gambar: ${e.toString()}');
    }
  }

  // ───────────────────────────────────────────────
  // Ekstraksi Nominal
  // ───────────────────────────────────────────────
  int _extractAmount(String text) {
    // Cari pola nominal Rp dari yang paling spesifik ke umum
    final patterns = [
      r'(?:Total|TOTAL|Jumlah|JUMLAH|Grand\s*Total)\s*:?\s*Rp\.?\s*([0-9]{1,3}(?:[.,][0-9]{3})*)',
      r'Rp\.?\s*([0-9]{1,3}(?:[.,][0-9]{3})+)',
      r'([0-9]{1,3}(?:\.[0-9]{3})+)(?:\s*$|\s*\n)',
    ];

    int bestAmount = 0;

    for (final pattern in patterns) {
      final regExp = RegExp(pattern, caseSensitive: false, multiLine: true);
      for (final match in regExp.allMatches(text)) {
        final raw = (match.group(1) ?? match.group(0) ?? '').trim();
        final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.isNotEmpty) {
          final val = int.tryParse(cleaned) ?? 0;
          // Ambil nilai terbesar yang masuk akal (< 1 miliar)
          if (val > bestAmount && val < 1000000000) {
            bestAmount = val;
          }
        }
      }
      if (bestAmount > 0) break;
    }

    return bestAmount;
  }

  // ───────────────────────────────────────────────
  // Ekstraksi Tanggal
  // ───────────────────────────────────────────────
  DateTime _extractDate(String text) {
    final monthMap = {
      'januari': 1, 'february': 2, 'februari': 2, 'maret': 3, 'march': 3,
      'april': 4, 'mei': 5, 'may': 5, 'juni': 6, 'june': 6,
      'juli': 7, 'july': 7, 'agustus': 8, 'august': 8,
      'september': 9, 'oktober': 10, 'october': 10,
      'november': 11, 'desember': 12, 'december': 12,
    };

    // Format: dd/mm/yyyy atau dd-mm-yyyy
    final numericPattern = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})');
    final numericMatch = numericPattern.firstMatch(text);
    if (numericMatch != null) {
      final day = int.tryParse(numericMatch.group(1) ?? '') ?? 0;
      final month = int.tryParse(numericMatch.group(2) ?? '') ?? 0;
      final year = int.tryParse(numericMatch.group(3) ?? '') ?? 0;
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 2000) {
        return DateTime(year, month, day);
      }
    }

    // Format: dd Bulan yyyy
    final textPattern = RegExp(
      '(\\d{1,2})\\s+(${monthMap.keys.join('|')})\\s+(\\d{4})',
      caseSensitive: false,
    );
    final textMatch = textPattern.firstMatch(text.toLowerCase());
    if (textMatch != null) {
      final day = int.tryParse(textMatch.group(1) ?? '') ?? 0;
      final monthName = textMatch.group(2) ?? '';
      final year = int.tryParse(textMatch.group(3) ?? '') ?? 0;
      final month = monthMap[monthName] ?? 0;
      if (day >= 1 && day <= 31 && month >= 1 && year >= 2000) {
        return DateTime(year, month, day);
      }
    }

    return DateTime.now();
  }

  // ───────────────────────────────────────────────
  // Kategorisasi via keyword map
  // ───────────────────────────────────────────────
  String _categorizeExpense(String text) {
    final lowerText = text.toLowerCase();
    final keywords = ExpenseCategory.ocrKeywords;

    for (final entry in keywords.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return 'LAINNYA';
  }

  // ───────────────────────────────────────────────
  // Hitung Confidence Score
  // ───────────────────────────────────────────────
  double _calculateConfidence(int amount, String category, String fullText) {
    double confidence = 0.5; // Base

    if (amount > 0) confidence += 0.2;
    if (amount > 1000) confidence += 0.05; // Reasonable minimum amount
    if (category != 'LAINNYA') confidence += 0.15;
    if (fullText.length > 50) confidence += 0.05; // Enough text extracted
    if (fullText.toLowerCase().contains('total') ||
        fullText.toLowerCase().contains('jumlah')) {
      confidence += 0.05; // Found total keyword
    }

    return confidence.clamp(0.0, 1.0);
  }

  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
