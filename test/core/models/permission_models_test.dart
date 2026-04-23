import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servisio_core/core/models/permission_models.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';

// Re-export FieldValue for type checking in tests
export 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

void main() {
  group('RoleTemplate', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    test('should create RoleTemplate with all fields', () {
      final roleTemplate = RoleTemplate(
        id: 'role-123',
        name: 'Admin',
        description: 'Role untuk admin dengan akses penuh ke transaksi dan stok',
        permissions: const {
          PermissionConstants.stokCreate: true,
          PermissionConstants.stokRead: true,
          PermissionConstants.transaksiCreate: true,
        },
        createdAt: testDate,
        createdBy: 'owner-123',
      );

      expect(roleTemplate.id, equals('role-123'));
      expect(roleTemplate.name, equals('Admin'));
      expect(roleTemplate.description, contains('admin'));
      expect(roleTemplate.permissions[PermissionConstants.stokCreate], isTrue);
      expect(roleTemplate.permissions[PermissionConstants.stokRead], isTrue);
      expect(roleTemplate.permissions[PermissionConstants.transaksiCreate], isTrue);
      expect(roleTemplate.createdAt, equals(testDate));
      expect(roleTemplate.createdBy, equals('owner-123'));
    });

    test('should convert to map correctly', () {
      final roleTemplate = RoleTemplate(
        id: 'role-456',
        name: 'Kasir',
        description: 'Role untuk kasir',
        permissions: const {
          PermissionConstants.transaksiCreate: true,
        },
        createdAt: testDate,
        createdBy: 'owner-456',
      );

      final map = roleTemplate.toMap();

      expect(map['name'], equals('Kasir'));
      expect(map['description'], equals('Role untuk kasir'));
      expect(map['permissions'], isA<Map<String, bool>>());
      expect(map['permissions'][PermissionConstants.transaksiCreate], isTrue);
      expect(map['createdBy'], equals('owner-456'));
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('should be equal when props are same', () {
      final role1 = RoleTemplate(
        id: 'role-123',
        name: 'Admin',
        description: 'Deskripsi',
        permissions: const {},
        createdAt: testDate,
        createdBy: 'owner-123',
      );

      final role2 = RoleTemplate(
        id: 'role-123',
        name: 'Admin',
        description: 'Deskripsi berbeda', // Not in props
        permissions: const {}, // Same as role1
        createdAt: DateTime.now(), // Not in props
        createdBy: 'owner-999', // Not in props
      );

      // Props are id, name, permissions - so they should be equal
      expect(role1, equals(role2));
    });

    test('should not be equal when id is different', () {
      final role1 = RoleTemplate(
        id: 'role-123',
        name: 'Admin',
        description: 'Deskripsi',
        permissions: const {},
        createdAt: testDate,
        createdBy: 'owner-123',
      );

      final role2 = RoleTemplate(
        id: 'role-456',
        name: 'Admin',
        description: 'Deskripsi',
        permissions: const {},
        createdAt: testDate,
        createdBy: 'owner-123',
      );

      expect(role1, isNot(equals(role2)));
    });
  });

  group('StaffWithPermissions', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    test('should create StaffWithPermissions with all fields', () {
      final staff = StaffWithPermissions(
        userId: 'user-123',
        name: 'John Doe',
        email: 'john@example.com',
        roleTemplateId: 'role-123',
        customPermissions: const {
          PermissionConstants.stokDelete: true,
        },
        assignedAt: testDate,
        assignedBy: 'owner-123',
      );

      expect(staff.userId, equals('user-123'));
      expect(staff.name, equals('John Doe'));
      expect(staff.email, equals('john@example.com'));
      expect(staff.roleTemplateId, equals('role-123'));
      expect(staff.customPermissions[PermissionConstants.stokDelete], isTrue);
      expect(staff.assignedAt, equals(testDate));
      expect(staff.assignedBy, equals('owner-123'));
    });

    test('should create StaffWithPermissions without role template', () {
      final staff = StaffWithPermissions(
        userId: 'user-456',
        name: 'Jane Doe',
        email: 'jane@example.com',
        roleTemplateId: null,
        customPermissions: const {},
        assignedAt: testDate,
        assignedBy: 'owner-123',
      );

      expect(staff.roleTemplateId, isNull);
      expect(staff.customPermissions, isEmpty);
    });

    test('hasPermission should return value from custom permissions', () {
      final staff = StaffWithPermissions(
        userId: 'user-123',
        name: 'John Doe',
        email: 'john@example.com',
        roleTemplateId: null,
        customPermissions: const {
          PermissionConstants.stokCreate: true,
          PermissionConstants.stokDelete: false,
        },
        assignedAt: testDate,
        assignedBy: 'owner-123',
      );

      expect(staff.hasPermission(PermissionConstants.stokCreate), isTrue);
      expect(staff.hasPermission(PermissionConstants.stokDelete), isFalse);
    });

    test('hasPermission should return false for undefined permission', () {
      final staff = StaffWithPermissions(
        userId: 'user-123',
        name: 'John Doe',
        email: 'john@example.com',
        roleTemplateId: null,
        customPermissions: const {},
        assignedAt: testDate,
        assignedBy: 'owner-123',
      );

      expect(staff.hasPermission(PermissionConstants.stokCreate), isFalse);
      expect(staff.hasPermission('unknown_permission'), isFalse);
    });

    test('should convert to map correctly', () {
      final staff = StaffWithPermissions(
        userId: 'user-789',
        name: 'Bob Smith',
        email: 'bob@example.com',
        roleTemplateId: 'role-789',
        customPermissions: const {
          PermissionConstants.transaksiCreate: true,
        },
        assignedAt: testDate,
        assignedBy: 'owner-789',
      );

      final map = staff.toMap();

      expect(map['name'], equals('Bob Smith'));
      expect(map['email'], equals('bob@example.com'));
      expect(map['roleTemplateId'], equals('role-789'));
      expect(map['customPermissions'], isA<Map<String, bool>>());
      expect(map['customPermissions'][PermissionConstants.transaksiCreate], isTrue);
      expect(map['assignedBy'], equals('owner-789'));
      expect(map['assignedAt'], isA<FieldValue>());
    });

    test('should be equal when props are same', () {
      final staff1 = StaffWithPermissions(
        userId: 'user-123',
        name: 'John',
        email: 'john@example.com',
        roleTemplateId: 'role-123',
        customPermissions: const {},
        assignedAt: testDate,
        assignedBy: 'owner-123',
      );

      final staff2 = StaffWithPermissions(
        userId: 'user-123',
        name: 'John',
        email: 'different@example.com', // Not in props
        roleTemplateId: 'role-123',
        customPermissions: const {},
        assignedAt: DateTime.now(), // Not in props
        assignedBy: 'owner-999', // Not in props
      );

      // Props are userId, name, roleTemplateId, customPermissions
      // So they should be equal based on those fields
      expect(staff1, equals(staff2));
    });
  });
}
