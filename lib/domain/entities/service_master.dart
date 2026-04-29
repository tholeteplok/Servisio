import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class ServiceMaster {
  @Id()
  int id = 0;

  @Unique()
  late String uuid;

  @Index()
  bool isDeleted = false; // Soft delete support STEP 3
  String bengkelId = "";

  late String name;
  int basePrice = 0; // Fixed precision (Rp)
  String? category; // e.g., "Servis Rutin", "Kelistrikan"

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  int? syncStatus;
  DateTime? lastSyncedAt;

  ServiceMaster({
    this.id = 0,
    String? uuid,
    required this.name,
    this.basePrice = 0,
    this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.uuid = uuid ?? const Uuid().v4();
    this.createdAt = createdAt ?? DateTime.now();
    this.updatedAt = updatedAt ?? DateTime.now();
  }
}

