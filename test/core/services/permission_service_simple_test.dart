import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:servisio_core/core/services/permission_service.dart';
import 'package:servisio_core/core/models/user_profile.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  group('PermissionService Simple Tests', () {
    late PermissionService permissionService;
    late FakeAuthService fakeAuthService;
    late FakeUser fakeUser;

    const testBengkelId = 'test-bengkel-123';
    const testUserId = 'test-user-456';

    setUp(() {
      fakeUser = FakeUser(uid: testUserId);
      fakeAuthService = FakeAuthService(user: fakeUser);

      permissionService = PermissionService(
        authService: fakeAuthService,
        firestore: FakeFirebaseFirestore(),
      );
    });

    group('hasPermission - Basic Logic', () {
      test('should return false when user is not logged in', () async {
        // Arrange
        fakeAuthService.currentUser = null;

        // Act
        final result = await permissionService.hasPermission(PermissionConstants.stokCreate);

        // Assert
        expect(result, isFalse);
      });

      test('owner should have all permissions automatically', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act & Assert
        expect(await permissionService.hasPermission(PermissionConstants.stokCreate), isTrue);
        expect(await permissionService.hasPermission(PermissionConstants.stokDelete), isTrue);
        expect(await permissionService.hasPermission(PermissionConstants.transaksiDelete), isTrue);
        expect(await permissionService.hasPermission(PermissionConstants.backupRestore), isTrue);
      });

      test('should return false when token claims are null', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = null;

        // Act
        final result = await permissionService.hasPermission(PermissionConstants.stokCreate);

        // Assert
        expect(result, isFalse);
      });

      test('should return false when bengkelId is null', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'role': 'teknisi',
        };

        // Act
        final result = await permissionService.hasPermission(PermissionConstants.stokCreate);

        // Assert
        expect(result, isFalse);
      });
    });

    group('hasAllPermissions', () {
      test('should return true when all permissions are granted for owner', () async {
        // Arrange - owner has all permissions
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act
        final result = await permissionService.hasAllPermissions([
          PermissionConstants.stokCreate,
          PermissionConstants.stokRead,
          PermissionConstants.pelangganCreate,
        ]);

        // Assert
        expect(result, isTrue);
      });
    });

    group('hasAnyPermission', () {
      test('should return true when at least one permission is granted for owner', () async {
        // Arrange - owner has all permissions
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act
        final result = await permissionService.hasAnyPermission([
          PermissionConstants.stokDelete,
          PermissionConstants.backupRestore,
        ]);

        // Assert
        expect(result, isTrue);
      });
    });

    group('can - Backward Compatibility', () {
      test('should map Permission enum correctly for owner', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act & Assert
        expect(await permissionService.can(Permission.viewOmzet), isTrue);
        expect(await permissionService.can(Permission.deleteTransaction), isTrue);
        expect(await permissionService.can(Permission.manageInventory), isTrue);
        expect(await permissionService.can(Permission.backupData), isTrue);
        expect(await permissionService.can(Permission.manageStaff), isTrue);
      });
    });

    group('Cache Management', () {
      test('clearCache should not throw', () {
        // Act & Assert
        expect(() => permissionService.clearCache(), returnsNormally);
      });
    });
  });
}
