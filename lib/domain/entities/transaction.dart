import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'pelanggan.dart';
import 'vehicle.dart';
import 'staff.dart';
import 'transaction_item.dart';

enum ServiceStatus { antri, dikerjakan, selesai, lunas }

@Entity()
class Transaction {
  @Id()
  int id = 0; // ObjectBox internal (auto-increment)

  @Unique()
  String uuid; // 🔑 WAJIB — UUID v4 untuk sync STEP 4

  @Index()
  DateTime createdAt; // Untuk audit & sorting

  @Index()
  DateTime updatedAt; // Untuk conflict resolution

  // STEP 3+: Sync tracking (nullable untuk STEP 1-2)
  int? syncStatus; // 0:local | 1:syncing | 2:synced | 3:failed
  DateTime? lastSyncedAt;

  // STEP 5: Multi-User / Cloud Support
  String bengkelId = ""; // Bengkel owner
  String? updatedBy; // UID of user who last updated

  // STEP 2+: Media fields (nullable)
  String? photoLocalPath; // Path lokal foto
  String? photoCloudUrl; // URL Firebase (STEP 4)
  int? mediaSyncStatus; // 0:local | 1:uploading | 2:synced

  // STEP 4+: Soft delete
  bool isDeleted = false;
  String? deletedBy;
  DateTime? deletedAt;

  @Index()
  int version = 1; // 🛡️ Version for Optimistic Locking K-5

  // 🏢 Business Fields
  String trxNumber; // Generated: SL-20260401-001

  // 👤 Customer Info
  final pelanggan = ToOne<Pelanggan>();

  String customerName; // Snapshot for history
  String customerPhone; // Snapshot for history

  // 🏍️ Vehicle Info
  final vehicle = ToOne<Vehicle>();
  String vehicleModel; // Snapshot for history
  String vehiclePlate; // Snapshot for history

  // 📝 Itemized Details
  @Backlink('transaction')
  final items = ToMany<TransactionItem>();

  String? paymentMethod; // Tunai, QRIS, Transfer

  // 💰 Finance
  int totalAmount = 0;
  int partsCost = 0;
  int laborCost = 0;
  int overheadCost = 0;      // 🆕 Cost like rent, electricity allocated
  int additionalCost = 0;    // 🆕 Expedisi, etc

  // 📊 Status
  String status = "pending"; // pending, in_progress, completed, lunas
  String? notes;

  // 🕒 Queue System (One-Way Workflow)
  int statusValue = 0; // 0: antri, 1: dikerjakan, 2: selesai
  DateTime? startTime;
  DateTime? endTime;

  String? complaint;
  String? mechanicNotes;
  int? recommendationTimeMonth; // 1, 2, 3 months
  int? recommendationKm;
  int? odometer; // 🏍️ Kilometer saat ini
  DateTime? lastReminderSentAt; // 📅 Waktu terakhir pengiriman pengingat

  ServiceStatus get serviceStatus {
    if (statusValue >= ServiceStatus.values.length) return ServiceStatus.antri;
    return ServiceStatus.values[statusValue];
  }

  set serviceStatus(ServiceStatus val) {
    statusValue = val.index;
    // Map to legacy status for compatibility
    switch (val) {
      case ServiceStatus.antri:
        status = "pending";
        break;
      case ServiceStatus.dikerjakan:
        status = "in_progress";
        break;
      case ServiceStatus.selesai:
        status = "completed";
        break;
      case ServiceStatus.lunas:
        status = "lunas";
        break;
    }
  }

  // 🕒 Reminder Helpers
  DateTime? get nextServiceDate {
    if (recommendationTimeMonth == null) return null;
    // Simple 30-day month approximation for performance
    return createdAt.add(Duration(days: recommendationTimeMonth! * 30));
  }

  bool get isOverdue {
    final date = nextServiceDate;
    if (date == null) return false;
    return DateTime.now().isAfter(date) && serviceStatus == ServiceStatus.lunas;
  }

  bool isDueSoon(int thresholdDays) {
    final date = nextServiceDate;
    if (date == null) return false;
    if (isOverdue) return true; // Overdue is always "due"

    final diff = date.difference(DateTime.now()).inDays;
    return diff <= thresholdDays &&
        diff >= 0 &&
        serviceStatus == ServiceStatus.lunas;
  }

  // Helper untuk estimasi KM servis berikutnya
  int? get targetServiceKm {
    if (odometer == null || recommendationKm == null) return null;
    return odometer! + recommendationKm!;
  }

  // Anti-spam: Sembunyikan jika baru dikirim dalam 7 hari terakhir
  bool get isRecentlyReminded {
    if (lastReminderSentAt == null) return false;
    final diff = DateTime.now().difference(lastReminderSentAt!).inDays;
    return diff < 7;
  }

  // 👨‍🔧 Staff
  final mechanic = ToOne<Staff>();
  String? mechanicName; // Snapshot for history

  // 📊 Profit Analysis (Pre-calculated for UI)
  int totalRevenue = 0;
  int totalHpp = 0;
  int totalMechanicBonus = 0;
  int totalProfit = 0; // Legacy / Gross
  int grossProfit = 0;
  int netProfit = 0;
  double profitMargin = 0.0;
  int breakEvenPoint = 0;

  // Constructor dengan UUID otomatis
  Transaction({
    required this.customerName,
    required this.customerPhone,
    required this.vehicleModel,
    required this.vehiclePlate,
    String? uuid,
    String? trxNumber,
    this.complaint,
    this.mechanicNotes,
    this.recommendationTimeMonth,
    this.recommendationKm,
    this.odometer,
    this.lastReminderSentAt,
  }) : uuid = uuid ?? const Uuid().v4(),
       trxNumber = trxNumber ?? '',
       createdAt = DateTime.now(),
       updatedAt = DateTime.now();

  void calculateTotals() {

    int total = 0;
    int hpp = 0;
    int labor = 0;
    int parts = 0;
    int bonuses = 0;

    for (var item in items) {
      item.recalculateSubtotal(); // Ensure item subtotal is fresh
      total += item.subtotal;
      hpp += (item.costPrice * item.quantity);
      bonuses += item.mechanicBonus; // Already total per item line or per item? 
      // Plan said: "mechanicBonus (int) for tracking commissions per item"
      // Wait, let's re-verify my item bonus definition.

      if (item.isService) {
        labor += item.subtotal;
      } else {
        parts += item.subtotal;
      }
    }

    totalAmount = total;
    partsCost = parts;
    laborCost = labor;

    // 📊 Profit Logic (COMPREHENSIVE)
    totalRevenue = total;
    totalHpp = hpp;
    totalMechanicBonus = bonuses;
    
    // Profit Kotor = Harga Jual - Harga Pokok
    grossProfit = totalRevenue - totalHpp;
    totalProfit = grossProfit; // Backward compatibility
    
    // Profit Bersih = Profit Kotor - Biaya Terkait
    netProfit = grossProfit - totalMechanicBonus - overheadCost - additionalCost;
    
    // Margin Bersih = (Profit Bersih / Harga Jual) * 100%
    profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;
    
    // Break-Even Point = Harga Pokok + Total Biaya Terkait
    breakEvenPoint = totalHpp + totalMechanicBonus + overheadCost + additionalCost;
  }
}

