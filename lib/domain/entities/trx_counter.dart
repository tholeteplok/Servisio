import 'package:objectbox/objectbox.dart';

/// Entity untuk menyimpan counter transaksi per hari di ObjectBox.
/// Digunakan oleh TrxNumberService.
@Entity()
class TrxCounter {
  @Id()
  int id = 0;

  @Unique()
  String key; // Format: CATEGORY_YYYYMMDD

  // ⚠️ TEMPORARY: Restored for compatibility with objectbox.g.dart until next build
  String date;

  int count;

  TrxCounter({
    this.key = '',
    this.date = '',
    this.count = 0,
  });
}
