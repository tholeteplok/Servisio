import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_mixin.dart';

class CustomerModel with AuditFields {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final List<VehicleModel> vehicles;
  final int totalVisits;
  final double totalSpent;
  final DateTime? lastVisitAt;
  final String? notes;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.vehicles = const [],
    this.totalVisits = 0,
    this.totalSpent = 0,
    this.lastVisitAt,
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

  factory CustomerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return CustomerModel.empty(doc.id);

    final vehiclesList = (data['vehicles'] as List<dynamic>?)
            ?.map((v) => VehicleModel.fromMap(v as Map<String, dynamic>))
            .toList() ??
        [];

    final model = CustomerModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      vehicles: vehiclesList,
      totalVisits: (data['totalVisits'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0,
      lastVisitAt: (data['lastVisitAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
    );
    model.auditFromFirestore(data);
    return model;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'totalVisits': totalVisits,
      'totalSpent': totalSpent,
      if (lastVisitAt != null)
        'lastVisitAt': Timestamp.fromDate(lastVisitAt!),
      if (notes != null) 'notes': notes,
      ...auditToFirestore(),
    };
  }

  factory CustomerModel.empty(String id) {
    return CustomerModel(id: id, name: '');
  }
}

class VehicleModel {
  final String? plateNumber;
  final String? brand;
  final String? model;
  final int? year;
  final String? transmission;

  VehicleModel({
    this.plateNumber,
    this.brand,
    this.model,
    this.year,
    this.transmission,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      plateNumber: map['plateNumber'] as String?,
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      year: (map['year'] as num?)?.toInt(),
      transmission: map['transmission'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (plateNumber != null) 'plateNumber': plateNumber,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (transmission != null) 'transmission': transmission,
    };
  }
}
