import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/permission_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../mocks/manual_mocks.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late PermissionService permissionService;
  late FakeFirebaseFirestore fakeFirestore;
  late FakeAuthService fakeAuthService;

  const bengkelId = 'bengkel_123';
  const ownerUid = 'owner_001';
  const staffUid = 'staff_001';
  const roleTemplateId = 'manager_role';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    
    // Setup initial data in Firestore
    // 1. Role Template
    await fakeFirestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('role_templates')
        .doc(roleTemplateId)
        .set({
      'name': 'Manager',
      'description': 'Manager Role',
      'permissions': {
        PermissionConstants.stokRead: true,
        PermissionConstants.stokUpdateJumlah: true,
        PermissionConstants.keuanganView: false,
      },
      'createdAt': Timestamp.now(),
      'createdBy': ownerUid,
    });

    // 2. Staff Member
    await fakeFirestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('staff')
        .doc(staffUid)
        .set({
      'name': 'Test Staff',
      'email': 'staff@test.com',
      'roleTemplateId': roleTemplateId,
      'customPermissions': {
        PermissionConstants.keuanganView: true, // Override to true
        PermissionConstants.stokUpdateJumlah: false, // Override to false
      },
      'assignedAt': Timestamp.now(),
      'assignedBy': ownerUid,
    });

    fakeAuthService = FakeAuthService();
    permissionService = PermissionService(
      authService: fakeAuthService,
      firestore: fakeFirestore,
    );
  });

  group('PermissionService - hasPermission', () {
    test('Returns false if user is not logged in', () async {
      fakeAuthService.currentUser = null;
      final result = await permissionService.hasPermission(PermissionConstants.stokRead);
      expect(result, isFalse);
    });

    test('Owner has all permissions', () async {
      fakeAuthService.currentUser = FakeUser(uid: ownerUid);
      fakeAuthService.mockClaims = {
        'role': 'owner',
        'bengkelId': bengkelId,
      };

      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isTrue);
      expect(await permissionService.hasPermission('any_random_permission'), isTrue);
    });

    test('Staff uses role template and custom overrides', () async {
      fakeAuthService.currentUser = FakeUser(uid: staffUid);
      fakeAuthService.mockClaims = {
        'role': 'teknisi',
        'bengkelId': bengkelId,
      };

      // 1. From template (stokRead: true)
      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isTrue);

      // 2. Custom override (keuanganView: false in template, but true in staff record)
      expect(await permissionService.hasPermission(PermissionConstants.keuanganView), isTrue);

      // 3. Custom override (stokUpdateJumlah: true in template, but false in staff record)
      expect(await permissionService.hasPermission(PermissionConstants.stokUpdateJumlah), isFalse);
    });

    test('Returns false if permission is not defined in either', () async {
      fakeAuthService.currentUser = FakeUser(uid: staffUid);
      fakeAuthService.mockClaims = {
        'role': 'teknisi',
        'bengkelId': bengkelId,
      };

      expect(await permissionService.hasPermission('unknown_permission'), isFalse);
    });
  });

  group('PermissionService - Caching', () {
    test('Subsequent calls use cache', () async {
      fakeAuthService.currentUser = FakeUser(uid: staffUid);
      fakeAuthService.mockClaims = {
        'role': 'teknisi',
        'bengkelId': bengkelId,
      };

      // First call fetches from Firestore
      await permissionService.hasPermission(PermissionConstants.stokRead);
      
      // Modify Firestore directly
      await fakeFirestore
          .collection('bengkels')
          .doc(bengkelId)
          .collection('staff')
          .doc(staffUid)
          .update({'roleTemplateId': null});

      // Second call should still return true because it's cached
      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isTrue);
      
      // Clear cache and try again
      permissionService.clearCache();
      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isFalse);
    });
  });
}
