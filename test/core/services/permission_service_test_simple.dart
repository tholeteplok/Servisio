import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:servisio_core/core/services/permission_service.dart';
import 'package:servisio_core/core/services/auth_service.dart';
import 'package:servisio_core/core/models/user_profile.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// Manual stub for AuthService - no mockito, no Firebase dependencies
class SimpleAuthService implements AuthService {
  final User? _currentUser;
  final Map<String, dynamic>? _claims;

  SimpleAuthService({User? currentUser, Map<String, dynamic>? claims})
      : _currentUser = currentUser,
        _claims = claims;

  @override
  User? get currentUser => _currentUser;

  @override
  Future<IdTokenResult?> getIdTokenResult({bool forceRefresh = false}) async {
    if (_claims == null) return null;
    return SimpleTokenResult(_claims) as IdTokenResult?;
  }

  // Minimal implementations for other required members
  @override
  Future<String?> getCurrentUserRole() async => _claims?['role'] as String?;

  @override
  Future<String?> getCurrentUserBengkelId() async => _claims?['bengkelId'] as String?;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SimpleTokenResult implements IdTokenResult {
  final Map<String, dynamic>? _claims;
  SimpleTokenResult(this._claims);

  @override
  Map<String, dynamic>? get claims => _claims;

  @override
  String? get token => 'test-token';

  @override
  DateTime? get authTime => DateTime.now();

  @override
  DateTime? get expirationTime => DateTime.now().add(const Duration(hours: 1));

  @override
  DateTime? get issuedAtTime => DateTime.now();

  @override
  String? get signInProvider => 'google.com';
}

class SimpleUser implements User {
  final String _uid;
  SimpleUser(this._uid);

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PermissionService Basic Tests', () {
    const testBengkelId = 'test-bengkel-123';

    test('should return false when user is not logged in', () async {
      final authService = SimpleAuthService(currentUser: null, claims: null);
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      final result = await permissionService.hasPermission(PermissionConstants.stokCreate);
      expect(result, isFalse);
    });

    test('owner should have all permissions automatically', () async {
      final authService = SimpleAuthService(
        currentUser: SimpleUser('user-123'),
        claims: {'bengkelId': testBengkelId, 'role': 'owner'},
      );
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      expect(await permissionService.hasPermission(PermissionConstants.stokCreate), isTrue);
      expect(await permissionService.hasPermission(PermissionConstants.stokDelete), isTrue);
      expect(await permissionService.hasPermission(PermissionConstants.transaksiDelete), isTrue);
      expect(await permissionService.hasPermission(PermissionConstants.backupRestore), isTrue);
    });

    test('should return false when token claims are null', () async {
      final authService = SimpleAuthService(
        currentUser: SimpleUser('user-123'),
        claims: null,
      );
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      final result = await permissionService.hasPermission(PermissionConstants.stokCreate);
      expect(result, isFalse);
    });

    test('should return false when bengkelId is null', () async {
      final authService = SimpleAuthService(
        currentUser: SimpleUser('user-123'),
        claims: {'role': 'teknisi'},
      );
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      final result = await permissionService.hasPermission(PermissionConstants.stokCreate);
      expect(result, isFalse);
    });

    test('hasAllPermissions should return true for owner', () async {
      final authService = SimpleAuthService(
        currentUser: SimpleUser('user-123'),
        claims: {'bengkelId': testBengkelId, 'role': 'owner'},
      );
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      final result = await permissionService.hasAllPermissions([
        PermissionConstants.stokCreate,
        PermissionConstants.stokRead,
        PermissionConstants.pelangganCreate,
      ]);
      expect(result, isTrue);
    });

    test('hasAnyPermission should return true for owner', () async {
      final authService = SimpleAuthService(
        currentUser: SimpleUser('user-123'),
        claims: {'bengkelId': testBengkelId, 'role': 'owner'},
      );
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      final result = await permissionService.hasAnyPermission([
        PermissionConstants.stokDelete,
        PermissionConstants.backupRestore,
      ]);
      expect(result, isTrue);
    });

    test('can - backward compatibility should work for owner', () async {
      final authService = SimpleAuthService(
        currentUser: SimpleUser('user-123'),
        claims: {'bengkelId': testBengkelId, 'role': 'owner'},
      );
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      expect(await permissionService.can(Permission.viewOmzet), isTrue);
      expect(await permissionService.can(Permission.deleteTransaction), isTrue);
      expect(await permissionService.can(Permission.manageInventory), isTrue);
      expect(await permissionService.can(Permission.backupData), isTrue);
      expect(await permissionService.can(Permission.manageStaff), isTrue);
    });

    test('clearCache should not throw', () {
      final authService = SimpleAuthService();
      final permissionService = PermissionService(
        authService: authService,
        firestore: MockFirebaseFirestore(),
      );

      expect(() => permissionService.clearCache(), returnsNormally);
    });
  });
}
