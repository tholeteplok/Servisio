import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'transaction.dart';
import 'stok.dart';
import 'service_master.dart';

@Entity()
class TransactionItem {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  late String uuid;

  late String name;
  int price = 0;
  int costPrice = 0; // 🛡️ Modal/HPP (Buying price)
  int quantity = 1;
  int subtotal = 0;

  bool isDeleted = false;
  bool isService = false; // true for ServiceMaster, false for Stok/Parts
  String? notes;
  int mechanicBonus = 0; // 🎁 Bonus yang didapat mekanik untuk item ini (total per item * quantity)
  String bengkelId = "";

  final transaction = ToOne<Transaction>();
  final stok = ToOne<Stok>();
  final serviceMaster = ToOne<ServiceMaster>();

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  TransactionItem({
    this.id = 0,
    String? uuid,
    required this.name,
    this.price = 0,
    this.costPrice = 0,
    this.quantity = 1,
    this.isService = false,
    this.notes,
    this.mechanicBonus = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.uuid = uuid ?? const Uuid().v4();
    recalculateSubtotal();
    this.createdAt = createdAt ?? DateTime.now();
    this.updatedAt = updatedAt ?? DateTime.now();
  }

  void recalculateSubtotal() {
    subtotal = price * quantity;
  }
}

