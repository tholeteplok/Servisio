import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/objectbox_provider.dart';
import '../../domain/entities/trx_counter.dart';

final trxNumberServiceProvider = Provider<TrxNumberService>((ref) {
  final db = ref.watch(dbProvider);
  return TrxNumberService(db);
});

/// Service untuk generate nomor transaksi.
/// Menggunakan ObjectBox untuk persistence yang lebih reliable.
class TrxNumberService {
  final ObjectBoxProvider _db;

  TrxNumberService(this._db);

  /// Generate nomor transaksi format: PREFIX-YYMMDD-XXX
  /// Contoh: SVC-260421-001 atau SLS-260421-001
  Future<String> generateTrxNumber({
    required String category, // SERVICE or SALE
    required String prefix,   // SVC or SLS
  }) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyyMMdd').format(now);
    final displayDate = DateFormat('yyMMdd').format(now);
    final key = "${category}_$todayStr";

    // Gunakan ObjectBox untuk menyimpan counter per hari
    final counterBox = _db.store.box<TrxCounter>();
    
    // TEMPORARILY disable dynamic query to allow code generation
    // final query = counterBox.query(TrxCounter_.key.equals(key)).build();
    // TrxCounter? counter = query.findFirst();
    
    // Fallback: search manually until build_runner succeeds
    TrxCounter? counter;
    try {
      counter = counterBox.getAll().firstWhere((c) => c.key == key);
    } catch (_) {
      counter = null;
    }

    if (counter == null) {
      counter = TrxCounter(key: key, count: 1);
    } else {
      counter.count++;
    }

    counterBox.put(counter);
    // query.close();

    final formattedCount = counter.count.toString().padLeft(3, '0');
    return '$prefix-$displayDate-$formattedCount';
  }

  /// Reset counter untuk kunci tertentu (opsional, untuk testing/admin)
  Future<void> resetCounter(String key) async {
    final counterBox = _db.store.box<TrxCounter>();
    final all = counterBox.getAll();
    for (var c in all) {
      if (c.key == key) {
        counterBox.remove(c.id);
      }
    }
  }

  /// Get current count for today (tanpa increment)
  Future<int> getCurrentCount(String key) async {
    final counterBox = _db.store.box<TrxCounter>();
    try {
      final counter = counterBox.getAll().firstWhere((c) => c.key == key);
      return counter.count;
    } catch (_) {
      return 0;
    }
  }

  /// Cleanup old counters (lebih dari 30 hari)
  Future<void> cleanupOldCounters() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyyMMdd').format(cutoff);

    final counterBox = _db.store.box<TrxCounter>();
    final allCounters = counterBox.getAll();
    int removed = 0;
    for (final counter in allCounters) {
      final parts = counter.key.split('_');
      if (parts.length == 2 && parts[1].compareTo(cutoffStr) < 0) {
        counterBox.remove(counter.id);
        removed++;
      }
    }

    debugPrint('🧹 Cleaned up $removed old transaction counters');
  }
}


