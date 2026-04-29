import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_mixin.dart';

class TransactionModel with AuditFields {
  final String id;

  // ── DIGABUNG DARI INVOICE ──
  final String? invoiceNumber;
  final String paymentStatus; // unpaid | partial | paid

  // ── STATUS ──
  final String status; // draft | pending | completed | cancelled
  final String category; // service | sale | service_with_sale

  // ── DENORMALIZED ──
  final String customerId;
  final String customerName;
  final String? vehiclePlate;
  final String mechanicId;
  final String mechanicName;

  // ── ITEMS ──
  final List<TransactionItemModel> items;

  // ── KEUANGAN ──
  final double subtotal;
  final double tax;
  final double discount;
  final double grandTotal;
  final String paymentMethod;
  final ProfitSummary? profitSummary;

  // ── TIMESTAMP ──
  final DateTime? completedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;

  TransactionModel({
    required this.id,
    this.invoiceNumber,
    this.paymentStatus = 'unpaid',
    this.status = 'draft',
    this.category = 'service',
    required this.customerId,
    required this.customerName,
    this.vehiclePlate,
    required this.mechanicId,
    required this.mechanicName,
    this.items = const [],
    this.subtotal = 0,
    this.tax = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.paymentMethod = 'cash',
    this.profitSummary,
    this.completedAt,
    this.paidAt,
    this.cancelledAt,
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

  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return TransactionModel.empty(doc.id);

    final itemsList = (data['items'] as List<dynamic>?)
            ?.map((i) => TransactionItemModel.fromMap(i as Map<String, dynamic>))
            .toList() ??
        [];

    final profitData = data['profitSummary'] as Map<String, dynamic>?;

    final model = TransactionModel(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String?,
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      status: data['status'] as String? ?? 'draft',
      category: data['category'] as String? ?? 'service',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      vehiclePlate: data['vehiclePlate'] as String?,
      mechanicId: data['mechanicId'] as String? ?? '',
      mechanicName: data['mechanicName'] as String? ?? '',
      items: itemsList,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      profitSummary: profitData != null
          ? ProfitSummary.fromMap(profitData)
          : null,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
    model.auditFromFirestore(data);
    return model;
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      'paymentStatus': paymentStatus,
      'status': status,
      'category': category,
      'customerId': customerId,
      'customerName': customerName,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      if (profitSummary != null)
        'profitSummary': profitSummary!.toMap(),
      if (completedAt != null)
        'completedAt': Timestamp.fromDate(completedAt!),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      if (cancelledAt != null)
        'cancelledAt': Timestamp.fromDate(cancelledAt!),
      ...auditToFirestore(),
    };
  }

  factory TransactionModel.empty(String id) {
    return TransactionModel(
      id: id,
      customerId: '',
      customerName: '',
      mechanicId: '',
      mechanicName: '',
    );
  }

  bool get isPaid => paymentStatus == 'paid';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isDraft => status == 'draft';
}

class TransactionItemModel {
  final String type; // service | inventory
  final String? inventoryId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double? costPrice;
  final double total;
  final double? profitPerUnit;

  TransactionItemModel({
    required this.type,
    this.inventoryId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.costPrice,
    required this.total,
    this.profitPerUnit,
  });

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      type: map['type'] as String? ?? 'service',
      inventoryId: map['inventoryId'] as String?,
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      total: (map['total'] as num?)?.toDouble() ?? 0,
      profitPerUnit: (map['profitPerUnit'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (inventoryId != null) 'inventoryId': inventoryId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      if (costPrice != null) 'costPrice': costPrice,
      'total': total,
      if (profitPerUnit != null) 'profitPerUnit': profitPerUnit,
    };
  }
}

class ProfitSummary {
  final double totalCost;
  final double totalRevenue;
  final double grossProfit;

  ProfitSummary({
    required this.totalCost,
    required this.totalRevenue,
    required this.grossProfit,
  });

  factory ProfitSummary.fromMap(Map<String, dynamic> map) {
    return ProfitSummary(
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0,
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0,
      grossProfit: (map['grossProfit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCost': totalCost,
      'totalRevenue': totalRevenue,
      'grossProfit': grossProfit,
    };
  }

  double get profitMargin =>
      totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;
}
