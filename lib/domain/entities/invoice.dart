import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

/// Entity representasi invoice untuk audit dan cetak nota.
@Entity()
class Invoice {
  @Id()
  int id = 0;

  @Unique()
  String uuid;

  @Index()
  String invoiceNumber; // Contoh: INV-20260425-001

  @Index()
  String transactionUuid; // Link ke Transaction.uuid

  String category; // 🆕 InvoiceCategory: SERVICE, SALE, etc

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Invoice({
    required this.invoiceNumber,
    required this.transactionUuid,
    this.category = 'SERVICE',
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
