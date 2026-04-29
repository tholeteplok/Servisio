import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'supplier.dart';
import 'debt_payment.dart';

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

  int? syncStatus;
  DateTime? lastSyncedAt;

  /// Status hutang: 'HUTANG', 'PARTIAL', 'LUNAS'.
  /// null jika bukan transaksi hutang.
  @Index()
  String? debtStatus;

  /// Link ke entity Supplier.
  final supplier = ToOne<Supplier>();

  /// Snapshot nama supplier (penting untuk audit & migrasi bertahap).
  String? supplierName;

  /// Link ke ID hutang induk (jika record ini adalah cicilan/pembayaran).
  final parentExpense = ToOne<Expense>();

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
    this.debtStatus,
    this.supplierName,
    int? supplierId,
    int? relatedExpenseId,
    this.createdBy,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    if (supplierId != null) supplier.targetId = supplierId;
    if (relatedExpenseId != null) parentExpense.targetId = relatedExpenseId;
  }

  // Helper getters for compatibility with existing code
  @Transient()
  int? get supplierId => supplier.targetId == 0 ? null : supplier.targetId;
  set supplierId(int? value) => supplier.targetId = value ?? 0;

  @Transient()
  int? get relatedExpenseId => parentExpense.targetId == 0 ? null : parentExpense.targetId;
  set relatedExpenseId(int? value) => parentExpense.targetId = value ?? 0;

  /// True jika scan oleh AI dengan confidence tinggi (≥ 0.8).
  bool get isHighConfidenceAI =>
      aiConfidence != null && aiConfidence! >= 0.8;

  /// True jika data berasal dari scan OCR (memiliki extractedText).
  bool get isFromOcr => extractedText != null && extractedText!.isNotEmpty;

  /// Sisa hutang (khusus untuk record bertipe HUTANG).
  /// Dihitung dari amount - total cicilan.
  double? get debtBalance {
    if (debtStatus == null || debtStatus == 'LUNAS') return 0;
    
    double totalPaid = 0;
    
    // 1. Hitung dari record Expense yang merupakan cicilan (backlink parentExpense)
    if (repayments.isNotEmpty) {
      totalPaid += repayments.fold<double>(0, (sum, item) => sum + item.amount);
    }
    
    // 2. Hitung dari record DebtPayment (jika ada)
    if (debtPayments.isNotEmpty) {
      totalPaid += debtPayments.fold<double>(0, (sum, item) => sum + item.amount);
    }
    
    return amount - totalPaid;
  }

  /// Relasi ke record pembayaran (cicilan) yang berupa Expense.
  @Backlink('parentExpense')
  final ToMany<Expense> repayments = ToMany<Expense>();

  /// Relasi ke record pembayaran (cicilan) yang berupa DebtPayment.
  @Backlink('expense')
  final ToMany<DebtPayment> debtPayments = ToMany<DebtPayment>();
}

