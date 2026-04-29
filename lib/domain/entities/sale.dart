import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class Sale {
  @Id()
  int id = 0;

  @Unique()
  String uuid;

  @Index()
  bool isDeleted = false; // Soft delete support STEP 3
  String bengkelId = "";

  @Index()
  String itemName;

  int quantity;
  int totalPrice; // Fixed precision (Rp)
  int costPrice = 0;
  int totalProfit = 0;

  @Index()
  String? transactionId;

  String? stokUuid; // Referensi ke Stok.uuid jika penjualan terkait stok
  String? customerName;
  String? paymentMethod; // Tunai, QRIS, Transfer

  @Index()
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? updatedAt;

  int? syncStatus;
  DateTime? lastSyncedAt;

  @Index()
  String trxNumber; // Generated: SLS-20260401-001

  Sale({
    required this.itemName,
    required this.quantity,
    required this.totalPrice,
    this.costPrice = 0,
    this.customerName,
    this.transactionId,
    this.stokUuid,
    this.trxNumber = '',
    String? uuid,
    DateTime? createdAt,
    this.updatedAt,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now() {
    updatedAt ??= createdAt;
    totalProfit = totalPrice - (costPrice * quantity);
  }
}

