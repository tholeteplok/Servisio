import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class StokHistory {
  @Id()
  int id = 0;

  @Index()
  String stokUuid; // Link to the stock item

  @Index()
  @Unique()
  late String uuid;

  /// Types: 'MANUAL_ADD', 'MANUAL_SUBTRACT', 'SALE', 'SERVICE', 'INITIAL'
  @Index()
  String type;

  int quantityChange; // e.g., +5 or -1
  int previousQuantity;
  int newQuantity;

  String? note;

  @Index()
  DateTime createdAt;

  DateTime? updatedAt;

  int? syncStatus;
  DateTime? lastSyncedAt;

  String bengkelId = "";

  StokHistory({
    this.id = 0,
    String? uuid,
    required this.stokUuid,
    required this.type,
    required this.quantityChange,
    required this.previousQuantity,
    required this.newQuantity,
    this.note,
    DateTime? createdAt,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();
}
