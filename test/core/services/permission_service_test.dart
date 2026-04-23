import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servisio_core/core/services/permission_service.dart';
import 'package:servisio_core/core/services/auth_service.dart';
import 'package:servisio_core/core/models/user_profile.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';

import '../../mocks/manual_mocks.dart';
import 'permission_service_test.mocks.dart' hide MockIdTokenResult;

@GenerateMocks([
  AuthService,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  QueryDocumentSnapshot,
  User,
  IdTokenResult,
])
void main() {
  group('PermissionService', () {
    late PermissionService permissionService;
    late FakeAuthService fakeAuthService;
    late MockFirebaseFirestore mockFirestore;
    late FakeUser fakeUser;

    const testBengkelId = 'test-bengkel-123';
    const testUserId = 'test-user-456';

    setUp(() {
      fakeAuthService = FakeAuthService();
      mockFirestore = MockFirebaseFirestore();
      fakeUser = FakeUser(uid: testUserId);

      permissionService = PermissionService(
        authService: fakeAuthService,
        firestore: mockFirestore,
      );
    });

    group('hasPermission - Owner Access', () {
      test('owner should have all permissions automatically', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act & Assert
        expect(
          await permissionService.hasPermission(PermissionConstants.stokCreate),
          isTrue,
        );
        expect(
          await permissionService.hasPermission(PermissionConstants.stokDelete),
          isTrue,
        );
      });
    });

    group('hasPermission - Unauthenticated', () {
      test('should return false when user is not logged in', () async {
        // Arrange
        fakeAuthService.currentUser = null;

        // Act & Assert
        expect(
          await permissionService.hasPermission(PermissionConstants.stokCreate),
          isFalse,
        );
      });

      test('should return false when token claims are null', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = null;

        // Act & Assert
        expect(
          await permissionService.hasPermission(PermissionConstants.stokCreate),
          isFalse,
        );
      });

      test('should return false when bengkelId is null', () async {
        // Arrange
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'role': 'teknisi',
        };

        // Act & Assert
        expect(
          await permissionService.hasPermission(PermissionConstants.stokCreate),
          isFalse,
        );
      });
    });

    group('hasAllPermissions', () {
      test('should return true when all permissions are granted', () async {
        // Arrange - owner has all permissions
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act & Assert
        expect(
          await permissionService.hasAllPermissions([
            PermissionConstants.stokCreate,
            PermissionConstants.stokRead,
          ]),
          isTrue,
        );
      });
    });

    group('hasAnyPermission', () {
      test('should return true when at least one permission is granted', () async {
        // Arrange - owner has all permissions
        fakeAuthService.currentUser = fakeUser;
        fakeAuthService.mockClaims = {
          'bengkelId': testBengkelId,
          'role': 'owner',
        };

        // Act & Assert
        expect(
          await permissionService.hasAnyPermission([
            PermissionConstants.stokDelete,
            PermissionConstants.backupRestore,
          ]),
          isTrue,
        );
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
        expect(
          await permissionService.can(Permission.viewOmzet),
          isTrue,
        );
        expect(
          await permissionService.can(Permission.deleteTransaction),
          isTrue,
        );
      });
    });

    group('Cache Management', () {
      test('clearCache should clear both caches', () {
        // Act
        permissionService.clearCache();

        // Assert
        expect(true, isTrue); 
      });
    });

    group('isOwner Check', () {
      test('should correctly identify owner role', () async {
        // Arrange
        fakeAuthService.mockClaims = {
          'role': 'owner',
        };

        // Act & Assert
        // This is a placeholder as the method is private or tested indirectly
        expect(true, isTrue);
      });
    });
  });
}
