import 'package:cloud_firestore/cloud_firestore.dart';

/// Mixin untuk field audit di semua model Firestore.
///
/// Digunakan oleh: InventoryModel, TransactionModel, CustomerModel,
/// SupplierModel, ExpenseModel.
///
/// Field yang disediakan:
/// - createdBy: memberId pembuat
/// - createdByName: nama member pembuat (denormalized)
/// - createdAt: timestamp pembuatan
/// - updatedBy: memberId pengubah terakhir
/// - updatedByName: nama member pengubah terakhir
/// - updatedAt: timestamp perubahan terakhir

mixin AuditFields {
  String? createdBy;
  String? createdByName;
  DateTime? createdAt;
  String? updatedBy;
  String? updatedByName;
  DateTime? updatedAt;

  /// Parse audit fields dari Map Firestore.
  /// Panggil ini di fromFirestore() model.
  void auditFromFirestore(Map<String, dynamic> data) {
    createdBy = data['createdBy'] as String?;
    createdByName = data['createdByName'] as String?;
    createdAt = _toDateTime(data['createdAt']);
    updatedBy = data['updatedBy'] as String?;
    updatedByName = data['updatedByName'] as String?;
    updatedAt = _toDateTime(data['updatedAt']);
  }

  /// Konversi audit fields ke Map untuk disimpan ke Firestore.
  /// Panggil ini di toFirestore() model.
  Map<String, dynamic> auditToFirestore() {
    return {
      if (createdBy != null) 'createdBy': createdBy,
      if (createdByName != null) 'createdByName': createdByName,
      if (createdAt != null) 'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (updatedByName != null) 'updatedByName': updatedByName,
      if (updatedAt != null) 'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Set audit fields saat CREATE (createdBy == updatedBy)
  void setCreateAudit({
    required String memberId,
    required String memberName,
  }) {
    final now = DateTime.now().toUtc();
    createdBy = memberId;
    createdByName = memberName;
    createdAt = now;
    updatedBy = memberId;
    updatedByName = memberName;
    updatedAt = now;
  }

  /// Set audit fields saat UPDATE (hanya updatedBy)
  void setUpdateAudit({
    required String memberId,
    required String memberName,
  }) {
    updatedBy = memberId;
    updatedByName = memberName;
    updatedAt = DateTime.now().toUtc();
  }

  /// Helper: konversi Timestamp/DateTime ke DateTime
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
