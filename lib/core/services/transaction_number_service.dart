import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../providers/objectbox_provider.dart';
import '../../objectbox.g.dart';
import '../../domain/entities/trx_counter.dart';

/// Service untuk generate nomor transaksi.
/// Menggunakan ObjectBox untuk persistence yang lebih reliable.
class TrxNumberService {
  final ObjectBoxProvider _db;

  TrxNumberService(this._db);

  /// Generate nomor transaksi format: SL-YYYYMMDD-XXX
  /// Contoh: SL-20260416-001
  Future<String> generateTrxNumber() async {
    final now = DateTime.now();
    final today = DateFormat('yyyyMMdd').format(now);

    // Gunakan ObjectBox untuk menyimpan counter per hari
    final counterBox = _db.store.box<TrxCounter>();
    final query = counterBox
        .query(TrxCounter_.date.equals(today))
        .build();

    TrxCounter? counter = query.findFirst();

    if (counter == null) {
      counter = TrxCounter(date: today, count: 1);
    } else {
      counter.count++;
    }

    counterBox.put(counter);
    query.close();

    final formattedCount = counter.count.toString().padLeft(3, '0');
    return 'SL-$today-$formattedCount';
  }

  /// Reset counter untuk hari tertentu (opsional, untuk testing/admin)
  Future<void> resetCounter(String date) async {
    final counterBox = _db.store.box<TrxCounter>();
    final query = counterBox
        .query(TrxCounter_.date.equals(date))
        .build();

    final counter = query.findFirst();
    if (counter != null) {
      counterBox.remove(counter.id);
    }
    query.close();
  }

  /// Get current count for today (tanpa increment)
  Future<int> getCurrentCount() async {
    final now = DateTime.now();
    final today = DateFormat('yyyyMMdd').format(now);

    final counterBox = _db.store.box<TrxCounter>();
    final query = counterBox
        .query(TrxCounter_.date.equals(today))
        .build();

    final counter = query.findFirst();
    query.close();

    return counter?.count ?? 0;
  }

  /// Cleanup old counters (lebih dari 30 hari)
  Future<void> cleanupOldCounters() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyyMMdd').format(cutoff);

    final counterBox = _db.store.box<TrxCounter>();
    final query = counterBox
        .query(TrxCounter_.date.lessThan(cutoffStr))
        .build();

    final oldCounters = query.find();
    for (final counter in oldCounters) {
      counterBox.remove(counter.id);
    }
    query.close();

    debugPrint('🧹 Cleaned up ${oldCounters.length} old transaction counters');
  }
}

// 🔄 Riverpod Provider
final trxNumberServiceProvider = Provider<TrxNumberService>((ref) {
  final db = ref.watch(dbProvider);
  return TrxNumberService(db);
});


