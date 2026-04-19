import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/logic_constants.dart';

@Entity()
class Stok {
  @Id()
  int id = 0;

  @Unique()
  String uuid;

  @Index()
  bool isDeleted = false; // Soft delete support STEP 3
  String? deletedBy;
  DateTime? deletedAt;

  @Index()
  int version = 1; // 🛡️ Version for Optimistic Locking K-5

  @Index()
  String nama; // Nama barang (e.g., "Oli MPX 2")

  @Unique()
  String? sku; // Kode barang (e.g., "OL-001")

  int hargaBeli; // Modal (Precision: Rp)
  int hargaJual; // Harga ke konsumen (Precision: Rp)

  int jumlah; // Stok saat ini

  int minStok; // Batas peringatan stok menipis

  @Index()
  String kategori; // Sparepart, Oli, Aksesoris, dll.

  String? photoLocalPath; // Path to local product image

  DateTime createdAt;
  DateTime updatedAt;

  int? syncStatus;
  DateTime? lastSyncedAt;

  String bengkelId = "";
  String? updatedBy;

  Stok({
    required this.nama,
    this.sku,
    this.hargaBeli = 0,
    this.hargaJual = 0,
    this.jumlah = 0,
    this.minStok = 5,
    this.kategori = LogicConstants.catSparepart,
    this.photoLocalPath,
    String? uuid,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = DateTime.now(),
       updatedAt = DateTime.now();

  // Helper to check if stock is low
  bool get isLowStock => jumlah <= minStok;
}
