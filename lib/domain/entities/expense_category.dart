import 'package:objectbox/objectbox.dart';

@Entity()
class ExpenseCategory {
  @Id()
  int id = 0;

  /// Key tetap untuk logika internal & sync (tidak berubah walau nama diganti).
  /// Contoh: 'LISTRIK', 'GAJI', 'SEWA'.
  @Unique()
  late String logicKey;

  /// Nama tampilan yang dapat dikustomisasi owner.
  late String name;

  /// Nama icon dari SolarIcons atau material icon key (opsional).
  String? icon;

  /// Apakah ini kategori bawaan sistem (tidak bisa dihapus).
  bool isDefault;

  /// Warna hex untuk badge, contoh: '#FF6B6B'.
  String? colorHex;

  @Index()
  String bengkelId;

  DateTime createdAt;

  ExpenseCategory({
    required this.logicKey,
    required this.name,
    required this.bengkelId,
    this.icon,
    this.isDefault = false,
    this.colorHex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Daftar kategori default yang di-seed saat pertama kali app dipakai.
  static List<ExpenseCategory> defaultCategories(String bengkelId) {
    final now = DateTime.now();
    return [
      ExpenseCategory(
        logicKey: 'LISTRIK',
        name: 'Listrik',
        bengkelId: bengkelId,
        icon: 'bolt',
        colorHex: '#F59E0B',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'AIR',
        name: 'Air',
        bengkelId: bengkelId,
        icon: 'water_drop',
        colorHex: '#3B82F6',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'GAJI',
        name: 'Gaji Karyawan',
        bengkelId: bengkelId,
        icon: 'people',
        colorHex: '#8B5CF6',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'SEWA',
        name: 'Sewa Tempat',
        bengkelId: bengkelId,
        icon: 'store',
        colorHex: '#EC4899',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'BELI_STOK',
        name: 'Beli Stok',
        bengkelId: bengkelId,
        icon: 'inventory',
        colorHex: '#10B981',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'INTERNET',
        name: 'Internet / WiFi',
        bengkelId: bengkelId,
        icon: 'wifi',
        colorHex: '#06B6D4',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'TRANSPORT',
        name: 'Transport',
        bengkelId: bengkelId,
        icon: 'local_shipping',
        colorHex: '#F97316',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'BAYAR_HUTANG',
        name: 'Bayar Hutang',
        bengkelId: bengkelId,
        icon: 'handshake',
        colorHex: '#EF4444',
        isDefault: true,
        createdAt: now,
      ),
      ExpenseCategory(
        logicKey: 'LAINNYA',
        name: 'Lainnya',
        bengkelId: bengkelId,
        icon: 'more_horiz',
        colorHex: '#6B7280',
        isDefault: true,
        createdAt: now,
      ),
    ];
  }

  /// Keyword map untuk kategorisasi OCR otomatis.
  static Map<String, List<String>> get ocrKeywords => {
        'LISTRIK': ['pln', 'listrik', 'token', 'prabayar', 'kwh'],
        'AIR': ['pdam', 'air', 'pam', 'water'],
        'GAJI': ['gaji', 'karyawan', 'teknisi', 'honor', 'upah', 'salary'],
        'SEWA': ['sewa', 'kontrakan', 'ruko', 'rent', 'kontrak'],
        'BELI_STOK': ['beli', 'stok', 'sparepart', 'spare part', 'oli', 'ban', 'aki', 'pembelian', 'purchase'],
        'INTERNET': ['internet', 'wifi', 'wi-fi', 'indihome', 'firstmedia', 'myrepublic', 'biznet'],
        'TRANSPORT': ['bensin', 'solar', 'bbm', 'pertamax', 'pertalite', 'grab', 'gojek', 'ojol'],
        'BAYAR_HUTANG': ['bayar', 'hutang', 'utang', 'pelunasan', 'cicilan', 'debt'],
      };
}
