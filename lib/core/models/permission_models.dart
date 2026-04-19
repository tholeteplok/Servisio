import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Role Template Model - Template untuk role dengan set permission tertentu
class RoleTemplate extends Equatable {
  final String id;
  final String name;
  final String description;
  final Map<String, bool> permissions;
  final DateTime createdAt;
  final String createdBy;

  const RoleTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.createdAt,
    required this.createdBy,
  });

  factory RoleTemplate.fromMap(String id, Map<String, dynamic> map) {
    return RoleTemplate(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      permissions: Map<String, bool>.from(map['permissions'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'permissions': permissions,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  @override
  List<Object?> get props => [id, name, permissions];
}

/// Staff dengan permissions - Model untuk staff dengan custom permission
class StaffWithPermissions extends Equatable {
  final String userId;
  final String name;
  final String email;
  final String? roleTemplateId;
  final Map<String, bool> customPermissions;
  final DateTime assignedAt;
  final String assignedBy;

  const StaffWithPermissions({
    required this.userId,
    required this.name,
    required this.email,
    this.roleTemplateId,
    required this.customPermissions,
    required this.assignedAt,
    required this.assignedBy,
  });

  bool hasPermission(String permissionKey) {
    // Custom permission override
    if (customPermissions.containsKey(permissionKey)) {
      return customPermissions[permissionKey] ?? false;
    }
    // Role template check handled by PermissionService
    return false;
  }

  factory StaffWithPermissions.fromMap(String userId, Map<String, dynamic> map) {
    return StaffWithPermissions(
      userId: userId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      roleTemplateId: map['roleTemplateId'],
      customPermissions: Map<String, bool>.from(map['customPermissions'] ?? {}),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedBy: map['assignedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'roleTemplateId': roleTemplateId,
      'customPermissions': customPermissions,
      'assignedAt': FieldValue.serverTimestamp(),
      'assignedBy': assignedBy,
    };
  }

  @override
  List<Object?> get props => [userId, name, roleTemplateId, customPermissions];
}
