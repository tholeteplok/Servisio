import 'package:objectbox/objectbox.dart';

/// Entity untuk menyimpan counter transaksi per hari di ObjectBox.
/// Digunakan oleh TrxNumberService.
@Entity()
class TrxCounter {
  @Id()
  int id = 0;

  @Unique()
  String date; // Format: YYYYMMDD

  int count;

  TrxCounter({
    required this.date,
    required this.count,
  });
}
