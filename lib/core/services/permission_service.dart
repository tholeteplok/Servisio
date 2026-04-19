import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/permission_models.dart';
import '../models/user_profile.dart';
import '../utils/permission_constants.dart';
import 'auth_service.dart';

/// Provider for PermissionService
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(
    authService: ref.watch(authServiceProvider),
    firestore: FirebaseFirestore.instance,
  );
});

/// Provider for checking a specific permission
final permissionCheckProvider = FutureProvider.family<bool, String>((ref, permissionKey) async {
  final permissionService = ref.watch(permissionServiceProvider);
  return await permissionService.hasPermission(permissionKey);
});

/// Cache entry with TTL
class _CacheEntry<T> {
  final T data;
  final DateTime expiry;

  _CacheEntry(this.data, {required Duration ttl}) 
    : expiry = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Permission Service - Logic untuk cek permission dengan caching
/// SEC-FIX: Dynamic Permission System untuk granular access control
/// N-03: Implementasi TTL (10 menit) untuk mencegah data permission basi
class PermissionService {
  final AuthService _authService;
  final FirebaseFirestore _firestore;

  static const Duration _cacheTtl = Duration(minutes: 10);

  // Cache untuk role templates (bengkelId -> roleId -> _CacheEntry<RoleTemplate>)
  final Map<String, Map<String, _CacheEntry<RoleTemplate>>> _roleTemplateCache = {};
  // Cache untuk staff permissions (bengkelId -> userId -> _CacheEntry<StaffWithPermissions>)
  final Map<String, Map<String, _CacheEntry<StaffWithPermissions>>> _staffCache = {};

  PermissionService({
    required AuthService authService,
    required FirebaseFirestore firestore,
  }) : _authService = authService,
       _firestore = firestore;

  /// Cek apakah current user memiliki permission tertentu
  Future<bool> hasPermission(String permissionKey) async {
    final currentUser = _authService.currentUser;

    if (currentUser == null) return false;

    // Get user profile for role and bengkelId
    final tokenResult = await _authService.getIdTokenResult();
    if (tokenResult?.claims == null) return false;

    final claims = tokenResult!.claims!;
    final bengkelId = claims['bengkelId'] as String?;
    final role = claims['role'] as String? ?? 'teknisi';

    if (bengkelId == null) return false;

    // Owner memiliki semua permission
    if (role == 'owner') return true;

    // Ambil data staff dengan permissions
    final staff = await _getStaffWithPermissions(bengkelId, currentUser.uid);
    if (staff == null) return false;

    // Cek custom permission (override)
    if (staff.customPermissions.containsKey(permissionKey)) {
      return staff.customPermissions[permissionKey] ?? false;
    }

    // Cek role template
    if (staff.roleTemplateId != null) {
      final roleTemplate = await _getRoleTemplate(bengkelId, staff.roleTemplateId!);
      if (roleTemplate != null) {
        return roleTemplate.permissions[permissionKey] ?? false;
      }
    }

    return false;
  }

  /// Cek multiple permissions (semua harus true)
  Future<bool> hasAllPermissions(List<String> permissionKeys) async {
    for (final key in permissionKeys) {
      if (!await hasPermission(key)) return false;
    }
    return true;
  }

  /// Cek multiple permissions (salah satu true)
  Future<bool> hasAnyPermission(List<String> permissionKeys) async {
    for (final key in permissionKeys) {
      if (await hasPermission(key)) return true;
    }
    return false;
  }

  /// Check permission menggunakan Permission enum (backward compatibility)
  Future<bool> can(Permission permission) async {
    // Map Permission enum ke string keys
    final permissionKey = _mapPermissionToKey(permission);
    if (permissionKey == null) return false;
    return await hasPermission(permissionKey);
  }

  /// Update permission untuk staff
  Future<void> updateStaffPermissions(
    String bengkelId,
    String staffId,
    Map<String, bool> permissions,
  ) async {
    // Validasi hanya owner yang bisa
    if (!await _isOwner()) {
      throw Exception('Hanya owner yang bisa mengubah permission');
    }

    await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('staff')
        .doc(staffId)
        .update({
      'customPermissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Clear cache
    _staffCache[bengkelId]?.remove(staffId);
  }

  /// Membuat role template baru
  Future<String> createRoleTemplate({
    required String bengkelId,
    required String name,
    required String description,
    required Map<String, bool> permissions,
  }) async {
    if (!await _isOwner()) {
      throw Exception('Hanya owner yang bisa membuat role template');
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final docRef = _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('role_templates')
        .doc();

    final roleTemplate = RoleTemplate(
      id: docRef.id,
      name: name,
      description: description,
      permissions: permissions,
      createdAt: DateTime.now(),
      createdBy: currentUser.uid,
    );

    await docRef.set(roleTemplate.toMap());
    return docRef.id;
  }

  /// Update role template permissions
  Future<void> updateRoleTemplatePermissions(
    String bengkelId,
    String roleId,
    Map<String, bool> permissions,
  ) async {
    if (!await _isOwner()) {
      throw Exception('Hanya owner yang bisa mengubah role template');
    }

    await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('role_templates')
        .doc(roleId)
        .update({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Clear cache
    _roleTemplateCache[bengkelId]?.remove(roleId);
  }

  /// Mendapatkan daftar permission yang dimiliki staff
  Future<Set<String>> getStaffPermissions(String bengkelId, String staffId) async {
    final staff = await _getStaffWithPermissions(bengkelId, staffId);
    if (staff == null) return {};

    final permissions = <String>{};

    // Tambahkan dari role template
    if (staff.roleTemplateId != null) {
      final roleTemplate = await _getRoleTemplate(bengkelId, staff.roleTemplateId!);
      if (roleTemplate != null) {
        roleTemplate.permissions.forEach((key, value) {
          if (value) permissions.add(key);
        });
      }
    }

    // Override dengan custom permissions
    staff.customPermissions.forEach((key, value) {
      if (value) {
        permissions.add(key);
      } else {
        permissions.remove(key);
      }
    });

    return permissions;
  }

  /// Get all role templates for a bengkel
  Future<List<RoleTemplate>> getRoleTemplates(String bengkelId) async {
    final snapshot = await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('role_templates')
        .get();

    return snapshot.docs.map((doc) => RoleTemplate.fromMap(doc.id, doc.data())).toList();
  }

  /// Get all staff for a bengkel
  Future<List<StaffWithPermissions>> getStaffList(String bengkelId) async {
    final snapshot = await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('staff')
        .get();

    return snapshot.docs.map((doc) => StaffWithPermissions.fromMap(doc.id, doc.data())).toList();
  }

  /// Assign role template ke staff
  Future<void> assignRoleTemplate(
    String bengkelId,
    String staffId,
    String? roleTemplateId,
  ) async {
    if (!await _isOwner()) {
      throw Exception('Hanya owner yang bisa assign role');
    }

    await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('staff')
        .doc(staffId)
        .update({
      'roleTemplateId': roleTemplateId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Clear cache
    _staffCache[bengkelId]?.remove(staffId);
  }

  // ============ Private Methods ============

  /// Check if current user is owner
  Future<bool> _isOwner() async {
    final tokenResult = await _authService.getIdTokenResult();
    if (tokenResult?.claims == null) return false;
    return tokenResult!.claims!['role'] == 'owner';
  }

  /// Get staff with permissions (with caching and TTL)
  Future<StaffWithPermissions?> _getStaffWithPermissions(String bengkelId, String userId) async {
    // Check cache
    if (_staffCache.containsKey(bengkelId) && _staffCache[bengkelId]!.containsKey(userId)) {
      final entry = _staffCache[bengkelId]![userId]!;
      if (!entry.isExpired) {
        return entry.data;
      }
      _staffCache[bengkelId]!.remove(userId);
    }

    final doc = await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('staff')
        .doc(userId)
        .get();

    if (!doc.exists) return null;

    final staff = StaffWithPermissions.fromMap(doc.id, doc.data()!);

    // Cache result with TTL
    _staffCache.putIfAbsent(bengkelId, () => {});
    _staffCache[bengkelId]![userId] = _CacheEntry(staff, ttl: _cacheTtl);

    return staff;
  }

  /// Get role template (with caching and TTL)
  Future<RoleTemplate?> _getRoleTemplate(String bengkelId, String roleId) async {
    // Check cache
    if (_roleTemplateCache.containsKey(bengkelId) && _roleTemplateCache[bengkelId]!.containsKey(roleId)) {
      final entry = _roleTemplateCache[bengkelId]![roleId]!;
      if (!entry.isExpired) {
        return entry.data;
      }
      _roleTemplateCache[bengkelId]!.remove(roleId);
    }

    final doc = await _firestore
        .collection('bengkels')
        .doc(bengkelId)
        .collection('role_templates')
        .doc(roleId)
        .get();

    if (!doc.exists) return null;

    final roleTemplate = RoleTemplate.fromMap(doc.id, doc.data()!);

    // Cache result with TTL
    _roleTemplateCache.putIfAbsent(bengkelId, () => {});
    _roleTemplateCache[bengkelId]![roleId] = _CacheEntry(roleTemplate, ttl: _cacheTtl);

    return roleTemplate;
  }

  /// Map Permission enum ke string key (backward compatibility)
  String? _mapPermissionToKey(Permission permission) {
    switch (permission) {
      case Permission.viewOmzet:
        return PermissionConstants.keuanganView;
      case Permission.deleteTransaction:
        return PermissionConstants.transaksiDelete;
      case Permission.manageInventory:
        return PermissionConstants.stokUpdateJumlah;
      case Permission.backupData:
        return PermissionConstants.backupRestore;
      case Permission.manageStaff:
        return PermissionConstants.staffCreate;
      case Permission.sendReminder:
        return null;
    }
  }

  /// Clear all caches
  void clearCache() {
    _roleTemplateCache.clear();
    _staffCache.clear();
  }
}
