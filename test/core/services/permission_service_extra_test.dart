import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:servisio_core/core/services/permission_service.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  group('PermissionService Extra Coverage', () {
    late PermissionService permissionService;
    late FakeAuthService fakeAuth;
    late FakeFirebaseFirestore firestore;
    late FakeUser fakeUser;

    const testBengkelId = 'bengkel-123';
    const testUserId = 'user-456';

    setUp(() {
      fakeUser = FakeUser(uid: testUserId);
      fakeAuth = FakeAuthService(user: fakeUser);
      firestore = FakeFirebaseFirestore();
      permissionService = PermissionService(
        authService: fakeAuth,
        firestore: firestore,
      );
    });

    test('hasPermission should return false if bengkelId is missing in claims', () async {
      fakeAuth.mockClaims = {'role': 'owner'}; // No bengkelId
      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isFalse);
    });

    test('hasPermission should return false if role is missing in claims', () async {
      fakeAuth.mockClaims = {'bengkelId': testBengkelId}; // No role
      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isFalse);
    });

    test('hasPermission should handle non-owner roles (integration-like)', () async {
      // For non-owner, it might try to read from Firestore.
      // Since we use FakeFirebaseFirestore, it will return empty/null if not setup.
      fakeAuth.mockClaims = {
        'bengkelId': testBengkelId,
        'role': 'teknisi',
      };
      
      // Should return false because we haven't setup the staff doc in firestore
      expect(await permissionService.hasPermission(PermissionConstants.stokRead), isFalse);
    });
  });
}
