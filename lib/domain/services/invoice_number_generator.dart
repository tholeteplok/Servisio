import '../../objectbox.g.dart';
import '../entities/trx_counter.dart';
import 'package:intl/intl.dart';

/// Generator nomor invoice yang atomic dan unik per kategori.
class InvoiceNumberGenerator {
  final Store _store;

  InvoiceNumberGenerator(this._store);

  /// Generate nomor invoice format: INV-YYYYMMDD-XXX
  /// Menggunakan TrxCounter untuk menjamin atomicity.
  Future<String> generate({String category = 'SERVICE'}) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyyMMdd').format(now);
    final key = "INV_${category}_$todayStr";
    
    return await _store.runInTransactionAsync<String, void>(
      TxMode.write,
      (store, _) {
        final counterBox = store.box<TrxCounter>();
        
        // Cari counter untuk hari ini
        TrxCounter? counter;
        final all = counterBox.getAll();
        for (var c in all) {
          if (c.key == key) {
            counter = c;
            break;
          }
        }

        if (counter == null) {
          counter = TrxCounter(key: key, count: 1);
        } else {
          counter.count++;
        }

        counterBox.put(counter);
        
        final countStr = counter.count.toString().padLeft(3, '0');
        return 'INV-$todayStr-$countStr';
      },
      null,
    );
  }
}
