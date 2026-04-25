import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class Pelanggan {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  late String uuid;

  late String nama;
  late String telepon;
  late String alamat;
  late String catatan;
  String? photoLocalPath;

  bool isDeleted = false;

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? updatedAt;

  int? syncStatus; // 0:local | 1:syncing | 2:synced | 3:failed
  DateTime? lastSyncedAt;

  String bengkelId = "";
  String? updatedBy;

  Pelanggan({
    this.id = 0,
    String? uuid,
    required this.nama,
    required this.telepon,
    this.alamat = '',
    this.catatan = '',
    this.photoLocalPath,
    DateTime? createdAt,
    this.updatedAt,
  }) {
    this.uuid = uuid ?? const Uuid().v4();
    this.createdAt = createdAt ?? DateTime.now();
    updatedAt ??= this.createdAt;
  }
}

