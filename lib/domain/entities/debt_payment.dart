import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'expense.dart';
import 'supplier.dart';

@Entity()
class DebtPayment {
  @Id()
  int id = 0;

  @Unique()
  late String uuid;

  /// Nominal pembayaran.
  int amount;

  /// TUNAI, TRANSFER, QRIS, dll.
  String paymentMethod;

  @Property(type: PropertyType.date)
  DateTime paymentDate;

  /// Path ke bukti foto (sudah dikompres).
  String? photoPath;

  String? note;

  /// Link ke ID Expense asal (hutang yang dibayar).
  final expense = ToOne<Expense>();

  /// Link ke ID Supplier.
  final supplier = ToOne<Supplier>();

  @Index()
  String bengkelId;

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  DebtPayment({
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.bengkelId,
    this.photoPath,
    this.note,
    String? uuid,
    DateTime? createdAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}
