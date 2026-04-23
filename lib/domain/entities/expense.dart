import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class Expense {
  @Id()
  int id = 0;

  @Unique()
  late String uuid;

  /// Jumlah pengeluaran dalam rupiah (integer).
  @Index()
  int amount;

  /// logicKey dari ExpenseCategory (contoh: 'LISTRIK', 'GAJI').
  /// Disimpan sebagai key tetap agar aman saat sync lintas device.
  @Index()
  String category;

  /// Deskripsi opsional pengeluaran.
  String? description;

  /// Tanggal pengeluaran terjadi (bukan tanggal input).
  @Index()
  @Property(type: PropertyType.date)
  DateTime date;

  /// Path foto nota asli yang tersimpan lokal.
  String? photoPath;

  /// Path thumbnail untuk tampilan list (hemat memori).
  String? photoThumbPath;

  /// Teks mentah hasil OCR (disimpan untuk keperluan audit).
  String? extractedText;

  /// Confidence score dari AI (0.0 - 1.0).
  double? aiConfidence;

  /// Apakah data sudah diverifikasi/diperiksa oleh user.
  bool isVerified;

  bool isDeleted;

  /// ID bengkel pemilik data ini.
  @Index()
  String bengkelId;

  String? createdBy;

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  Expense({
    required this.amount,
    required this.category,
    required this.bengkelId,
    this.description,
    DateTime? date,
    this.photoPath,
    this.photoThumbPath,
    this.extractedText,
    this.aiConfidence,
    this.isVerified = false,
    this.isDeleted = false,
    this.createdBy,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// True jika scan oleh AI dengan confidence tinggi (≥ 0.8).
  bool get isHighConfidenceAI =>
      aiConfidence != null && aiConfidence! >= 0.8;

  /// True jika data berasal dari scan OCR (memiliki extractedText).
  bool get isFromOcr => extractedText != null && extractedText!.isNotEmpty;
}
