import 'package:objectbox/objectbox.dart';
import 'expense.dart';

/// Entity untuk menganalisis dan memprioritaskan hutang supplier.
/// Memisahkan logika analisis dari record pengeluaran mentah (Expense).
@Entity()
class Debt {
  @Id()
  int id = 0;

  /// Link ke Expense yang memiliki status hutang.
  final expense = ToOne<Expense>();

  /// Skor prioritas (0.0 - 100.0)
  /// Dihitung berdasarkan keterlambatan, limit kredit, dan status supplier.
  double priorityScore;

  /// Status prioritas: 'PAY_NOW', 'THIS_WEEK', 'NEXT_WEEK', 'DEFER'.
  String priorityStatus;

  /// Tanggal jatuh tempo yang diprediksi atau ditetapkan.
  @Property(type: PropertyType.date)
  DateTime? dueDate;

  /// Catatan khusus untuk manajemen hutang ini.
  String? managementNote;

  Debt({
    this.priorityScore = 0.0,
    this.priorityStatus = 'DEFER',
    this.dueDate,
    this.managementNote,
  });

  /// Helper untuk mendapatkan warna indikator di UI.
  int get priorityColor {
    if (priorityScore >= 70) return 0xFFFF4444; // Red
    if (priorityScore >= 40) return 0xFFFFBB33; // Orange
    return 0xFF00C851; // Green
  }
}
