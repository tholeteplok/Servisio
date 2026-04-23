import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/models/user_profile.dart';

void main() {
  group('UserProfile Tests', () {
    final now = DateTime.now();
    
    test('Constructor should set values correctly', () {
      final profile = UserProfile(
        uid: '123',
        name: 'Test',
        email: 'test@example.com',
        bengkelId: 'b-1',
        role: 'owner',
        joinedAt: now,
      );
      
      expect(profile.uid, '123');
      expect(profile.name, 'Test');
      expect(profile.email, 'test@example.com');
      expect(profile.bengkelId, 'b-1');
      expect(profile.role, 'owner');
      expect(profile.joinedAt, now);
      expect(profile.isValid, isTrue);
      expect(profile.isEmpty, isFalse);
    });

    test('UserProfile.empty should be empty', () {
      final profile = UserProfile.empty;
      expect(profile.isEmpty, isTrue);
      expect(profile.isValid, isFalse);
    });

    test('UserProfile.fromJson and toJson should work', () {
      final json = {
        'uid': '123',
        'name': 'Test',
        'email': 'test@example.com',
        'bengkelId': 'b-1',
        'role': 'owner',
        'permissions': ['p1'],
        'status': 'active',
        'joinedAt': now.toIso8601String(),
        'invitedBy': 'tester',
        'lastActive': now.toIso8601String(),
        'deviceTokens': ['t1'],
      };
      
      final profile = UserProfile.fromJson(json);
      expect(profile.uid, '123');
      expect(profile.name, 'Test');
      
      final backToJson = profile.toJson();
      expect(backToJson['uid'], '123');
      expect(backToJson['role'], 'owner');
    });

    test('copyWith should work', () {
      final profile = UserProfile(
        uid: '123',
        name: 'Test',
        email: 'test@example.com',
        bengkelId: 'b-1',
        role: 'owner',
        joinedAt: now,
      );
      
      final updated = profile.copyWith(name: 'New Name', role: 'admin');
      expect(updated.name, 'New Name');
      expect(updated.role, 'admin');
      expect(updated.uid, '123');
    });

    test('Role checks should work', () {
      final owner = UserProfile(uid: '1', name: 'O', email: 'o', bengkelId: 'b', role: 'owner', joinedAt: now);
      final admin = UserProfile(uid: '2', name: 'A', email: 'a', bengkelId: 'b', role: 'admin', joinedAt: now);
      final teknisi = UserProfile(uid: '3', name: 'T', email: 't', bengkelId: 'b', role: 'teknisi', joinedAt: now);
      
      expect(owner.isOwner, isTrue);
      expect(admin.isAdmin, isTrue);
      expect(teknisi.isTeknisi, isTrue);
      
      expect(owner.rolePriority, 3);
      expect(admin.rolePriority, 2);
      expect(teknisi.rolePriority, 1);
      
      expect(owner.hasHigherRoleThan(admin), isTrue);
      expect(admin.hasHigherRoleThan(teknisi), isTrue);
      expect(teknisi.hasHigherRoleThan(owner), isFalse);
    });

    test('Permission check (can) should work', () {
      final owner = UserProfile(uid: '1', name: 'O', email: 'o', bengkelId: 'b', role: 'owner', joinedAt: now);
      final admin = UserProfile(uid: '2', name: 'A', email: 'a', bengkelId: 'b', role: 'admin', joinedAt: now);
      final teknisi = UserProfile(uid: '3', name: 'T', email: 't', bengkelId: 'b', role: 'teknisi', permissions: ['manageInventory'], joinedAt: now);
      
      expect(owner.can(Permission.deleteTransaction), isTrue);
      expect(admin.can(Permission.deleteTransaction), isFalse);
      expect(admin.can(Permission.manageInventory), isTrue);
      expect(teknisi.can(Permission.manageInventory), isTrue);
      expect(teknisi.can(Permission.viewOmzet), isFalse);
    });

    test('operator == and hashCode', () {
      final p1 = UserProfile(uid: '1', name: 'A', email: 'a', bengkelId: 'b', role: 'r', joinedAt: now);
      final p2 = UserProfile(uid: '1', name: 'B', email: 'b', bengkelId: 'c', role: 's', joinedAt: now);
      expect(p1 == p2, isTrue);
      expect(p1.hashCode, p2.hashCode);
    });
  });

  group('Permission Enums and Extensions', () {
    test('Permission display name and description', () {
      expect(Permission.viewOmzet.displayName, isA<String>());
      expect(Permission.viewOmzet.description, isA<String>());
    });

    test('AuthState extensions', () {
      expect(AuthState.authenticated.isAuthenticated, isTrue);
      expect(AuthState.unauthenticated.isUnauthenticated, isTrue);
      expect(AuthState.authenticating.isLoading, isTrue);
      expect(AuthState.missingProfile.needsProfile, isTrue);
    });
  });
}
