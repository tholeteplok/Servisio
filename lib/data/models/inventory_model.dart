import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_mixin.dart';

class InventoryModel with AuditFields {
  final String id;
  final String name;
  final String? sku;
  final String? category;
  final int quantity;
  final String? unit;
  final double costPrice;
  final double sellingPrice;
  final int lowStockAlert;
  final String? supplierId;
  final String? supplierName;
  final DateTime? lastRestockAt;
  final String? notes;

  InventoryModel({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    this.quantity = 0,
    this.unit,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.lowStockAlert = 5,
    this.supplierId,
    this.supplierName,
    this.lastRestockAt,
    this.notes,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? updatedAt,
  }) {
    this.createdBy = createdBy;
    this.createdByName = createdByName;
    this.createdAt = createdAt;
    this.updatedBy = updatedBy;
    this.updatedByName = updatedByName;
    this.updatedAt = updatedAt;
  }

  /// Dari Firestore
  factory InventoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return InventoryModel.empty(doc.id);
    }

    final model = InventoryModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      sku: data['sku'] as String?,
      category: data['category'] as String?,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unit: data['unit'] as String?,
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      lowStockAlert: (data['lowStockAlert'] as num?)?.toInt() ?? 5,
      supplierId: data['supplierId'] as String?,
      supplierName: data['supplierName'] as String?,
      lastRestockAt: (data['lastRestockAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
    );
    model.auditFromFirestore(data);
    return model;
  }

  /// Ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (sku != null) 'sku': sku,
      if (category != null) 'category': category,
      'quantity': quantity,
      if (unit != null) 'unit': unit,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'lowStockAlert': lowStockAlert,
      if (supplierId != null) 'supplierId': supplierId,
      if (supplierName != null) 'supplierName': supplierName,
      if (lastRestockAt != null)
        'lastRestockAt': Timestamp.fromDate(lastRestockAt!),
      if (notes != null) 'notes': notes,
      ...auditToFirestore(),
    };
  }

  InventoryModel copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    int? quantity,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    int? lowStockAlert,
    String? supplierId,
    String? supplierName,
    DateTime? lastRestockAt,
    String? notes,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? updatedAt,
  }) {
    return InventoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      lowStockAlert: lowStockAlert ?? this.lowStockAlert,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      lastRestockAt: lastRestockAt ?? this.lastRestockAt,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InventoryModel.empty(String id) {
    return InventoryModel(id: id, name: '');
  }

  bool get isLowStock => quantity <= lowStockAlert;
  bool get isOutOfStock => quantity <= 0;
}
