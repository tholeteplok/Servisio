// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:servisio_core/core/services/permission_service.dart';
import 'package:servisio_core/core/models/user_profile.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  group('PermissionService with Mocks', () {
    const testBengkelId = 'test-bengkel-123';
    const testUserId = 'test-user-456';
    late FakeUser fakeUser;
    late FakeAuthService fakeAuth;

    setUp(() {
      fakeUser = FakeUser(uid: testUserId);
      fakeAuth = FakeAuthService(user: fakeUser);
    });

    group('hasPermission - Basic Logic', () {
      test('should return false when user is not logged in', () async {
        fakeAuth.currentUser = null;

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        final result = await permissionService.hasPermission(PermissionConstants.stokCreate);
        expect(result, isFalse);
      });

      test('owner should have all permissions automatically', () async {
        fakeAuth.currentUser = fakeUser;
        fakeAuth.mockClaims = {'bengkelId': testBengkelId, 'role': 'owner'};

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        expect(await permissionService.hasPermission(PermissionConstants.stokCreate), isTrue);
        expect(await permissionService.hasPermission(PermissionConstants.stokDelete), isTrue);
        expect(await permissionService.hasPermission(PermissionConstants.transaksiDelete), isTrue);
        expect(await permissionService.hasPermission(PermissionConstants.backupRestore), isTrue);
      });

      test('should return false when token claims are null', () async {
        fakeAuth.currentUser = fakeUser;
        fakeAuth.mockClaims = null;

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        final result = await permissionService.hasPermission(PermissionConstants.stokCreate);
        expect(result, isFalse);
      });

      test('should return false when bengkelId is null', () async {
        fakeAuth.currentUser = fakeUser;
        fakeAuth.mockClaims = {'role': 'teknisi'};

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        final result = await permissionService.hasPermission(PermissionConstants.stokCreate);
        expect(result, isFalse);
      });
    });

    group('hasAllPermissions', () {
      test('should return true for owner', () async {
        fakeAuth.currentUser = fakeUser;
        fakeAuth.mockClaims = {'bengkelId': testBengkelId, 'role': 'owner'};

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        final result = await permissionService.hasAllPermissions([
          PermissionConstants.stokCreate,
          PermissionConstants.stokRead,
          PermissionConstants.pelangganCreate,
        ]);
        expect(result, isTrue);
      });
    });

    group('hasAnyPermission', () {
      test('should return true for owner', () async {
        fakeAuth.currentUser = fakeUser;
        fakeAuth.mockClaims = {'bengkelId': testBengkelId, 'role': 'owner'};

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        final result = await permissionService.hasAnyPermission([
          PermissionConstants.stokDelete,
          PermissionConstants.backupRestore,
        ]);
        expect(result, isTrue);
      });
    });

    group('can - Backward Compatibility', () {
      test('should map Permission enum correctly for owner', () async {
        fakeAuth.currentUser = fakeUser;
        fakeAuth.mockClaims = {'bengkelId': testBengkelId, 'role': 'owner'};

        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        expect(await permissionService.can(Permission.viewOmzet), isTrue);
        expect(await permissionService.can(Permission.deleteTransaction), isTrue);
        expect(await permissionService.can(Permission.manageInventory), isTrue);
        expect(await permissionService.can(Permission.backupData), isTrue);
        expect(await permissionService.can(Permission.manageStaff), isTrue);
      });
    });

    group('Cache Management', () {
      test('clearCache should not throw', () {
        final permissionService = PermissionService(
          authService: fakeAuth,
          firestore: FakeFirebaseFirestore(),
        );

        expect(() => permissionService.clearCache(), returnsNormally);
      });
    });
  });
}
