import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';


@Entity()
class Staff {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  late String uuid;

  late String name;
  late String role; // Mechanic, Admin, Cashier
  String? phoneNumber;
  bool isActive = true;
  bool isDeleted = false;

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  int? syncStatus;
  DateTime? lastSyncedAt;

  String bengkelId = "";
  String? updatedBy;

  double commissionRate = 0.0; // 💰 Persentase komisi (misal: 0.1 = 10%)

  Staff({
    this.id = 0,
    String? uuid,
    required this.name,
    required this.role,
    this.phoneNumber,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.uuid = uuid ?? const Uuid().v4();
    this.createdAt = createdAt ?? DateTime.now();
    this.updatedAt = updatedAt ?? DateTime.now();
  }
}

