import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'pelanggan.dart';
import '../../core/constants/logic_constants.dart';

@Entity()
class Vehicle {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  late String uuid;

  late String model; // e.g., "Honda Vario 125"
  late String type; // e.g., "Motor", "Mobil", "Truk"

  @Index()
  late String plate; // e.g., "B 1234 ABC"

  String? color;
  int? year;
  String? vin; // Engine number or chassis number

  bool isDeleted = false;
  String bengkelId = "";

  final owner = ToOne<Pelanggan>();

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  Vehicle({
    this.id = 0,
    String? uuid,
    required this.model,
    this.type = LogicConstants.vehicleMotor,
    required this.plate,
    this.color,
    this.year,
    this.vin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.uuid = uuid ?? const Uuid().v4();
    this.createdAt = createdAt ?? DateTime.now();
    this.updatedAt = updatedAt ?? DateTime.now();
  }
}

