import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class ShopProfile {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  late String uuid; // Mapping from Firebase Auth UID

  late String shopName;
  String? ownerName;
  String? address;
  String? phoneNumber;
  String? logoUrl;
  bool isDeleted = false;
  String bengkelId = "";

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  ShopProfile({
    this.id = 0,
    String? uuid,
    required this.shopName,
    this.ownerName,
    this.address,
    this.phoneNumber,
    this.logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.uuid = uuid ?? const Uuid().v4();
    this.createdAt = createdAt ?? DateTime.now();
    this.updatedAt = updatedAt ?? DateTime.now();
  }
}

