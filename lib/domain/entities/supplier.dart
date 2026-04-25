import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class Supplier {
  @Id()
  int id = 0;

  @Unique()
  late String uuid;

  @Index()
  String nama;

  String? telepon;
  String? alamat;

  @Index()
  String bengkelId;

  // 💳 Financial Profile
  int creditLimit = 0;      // Limit hutang dari supplier ini
  bool isStrategic = false; // Supplier kunci/penting

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  Supplier({
    required this.nama,
    required this.bengkelId,
    this.telepon,
    this.alamat,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

