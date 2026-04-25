import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// User Profile model — bisa dibuat dari Custom Claims atau Firestore.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String bengkelId;
  final String role;
  final List<String> permissions;
  final String status;
  final DateTime joinedAt;
  final String? invitedBy;
  final DateTime? lastActive;
  final List<String> deviceTokens;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.bengkelId,
    required this.role,
    this.permissions = const [],
    this.status = 'active',
    required this.joinedAt,
    this.invitedBy,
    this.lastActive,
    this.deviceTokens = const [],
  });

  /// ✅ NEW: Empty/unauthenticated profile
  static final UserProfile empty = UserProfile(
    uid: '',
    name: '',
    email: '',
    bengkelId: '',
    role: '',
    joinedAt: DateTime(1970),
  );

  /// Factory dari Custom Claims (prioritas utama — zero Firestore read).
  factory UserProfile.fromCustomClaims(User user, IdTokenResult tokenResult) {
    final claims = tokenResult.claims ?? {};
    return UserProfile(
      uid: user.uid,
      name: user.displayName ?? claims['name'] ?? '',
      email: user.email ?? claims['email'] ?? '',
      bengkelId: claims['bengkelId'] ?? '',
      role: claims['role'] ?? 'teknisi',
      permissions: List<String>.from(claims['permissions'] ?? []),
      status: 'active',
      joinedAt: DateTime.now(),
    );
  }

  /// Factory dari Firestore document (fallback untuk first login).
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      bengkelId: data['bengkelId'] ?? '',
      role: data['role'] ?? 'teknisi',
      permissions: List<String>.from(data['permissions'] ?? []),
      status: data['status'] ?? 'active',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invitedBy: data['invitedBy'],
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      deviceTokens: List<String>.from(data['deviceTokens'] ?? []),
    );
  }

  /// ✅ NEW: Factory from JSON for local caching
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      bengkelId: json['bengkelId'] as String,
      role: json['role'] as String,
      permissions: List<String>.from(json['permissions'] ?? []),
      status: json['status'] as String? ?? 'active',
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      invitedBy: json['invitedBy'] as String?,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : null,
      deviceTokens: List<String>.from(json['deviceTokens'] ?? []),
    );
  }

  /// Convert to Map untuk Firestore write.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'bengkelId': bengkelId,
      'role': role,
      'permissions': permissions,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'invitedBy': invitedBy,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'deviceTokens': deviceTokens,
    };
  }

  /// ✅ NEW: Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'bengkelId': bengkelId,
      'role': role,
      'permissions': permissions,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy,
      'lastActive': lastActive?.toIso8601String(),
      'deviceTokens': deviceTokens,
    };
  }

  /// ✅ NEW: Copy with method for immutability
  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? bengkelId,
    String? role,
    List<String>? permissions,
    String? status,
    DateTime? joinedAt,
    String? invitedBy,
    DateTime? lastActive,
    List<String>? deviceTokens,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      bengkelId: bengkelId ?? this.bengkelId,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      lastActive: lastActive ?? this.lastActive,
      deviceTokens: deviceTokens ?? this.deviceTokens,
    );
  }

  /// ✅ NEW: Check if profile is valid (not empty)
  bool get isValid => uid.isNotEmpty && bengkelId.isNotEmpty && role.isNotEmpty;

  /// ✅ NEW: Check if profile is empty (unauthenticated)
  bool get isEmpty => uid.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// ✅ IMPROVED: Permission check with role-based inheritance
  /// Owner gets all permissions automatically
  /// Admin gets all except owner-specific
  bool can(Permission permission) {
    // Owner has all permissions
    if (isOwner) return true;

    // Admin permissions
    if (isAdmin) {
      // Admin cannot delete transactions or manage staff (owner only)
      if (permission == Permission.deleteTransaction) return false;
      if (permission == Permission.manageStaff) return false;
      return true;
    }

    // Check explicit permissions for teknisi
    return permissions.contains(permission.name);
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isTeknisi => role == 'teknisi';

  /// ✅ NEW: Get role priority (higher number = more access)
  int get rolePriority {
    switch (role) {
      case 'owner':
        return 3;
      case 'admin':
        return 2;
      case 'teknisi':
        return 1;
      default:
        return 0;
    }
  }

  /// ✅ NEW: Check if this profile has higher role than another
  bool hasHigherRoleThan(UserProfile other) {
    return rolePriority > other.rolePriority;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'UserProfile(uid: $uid, role: $role, bengkelId: $bengkelId)';
}

/// Daftar permission yang tersedia.
enum Permission {
  viewOmzet,
  deleteTransaction,
  manageInventory,
  backupData,
  manageStaff,
  sendReminder,
}

/// Extension untuk mendapatkan display name permission
extension PermissionExtension on Permission {
  String get displayName {
    switch (this) {
      case Permission.viewOmzet:
        return 'Lihat Omzet';
      case Permission.deleteTransaction:
        return 'Hapus Transaksi';
      case Permission.manageInventory:
        return 'Kelola Inventaris';
      case Permission.backupData:
        return 'Backup Data';
      case Permission.manageStaff:
        return 'Kelola Staff';
      case Permission.sendReminder:
        return 'Kirim Pengingat';
    }
  }

  String get description {
    switch (this) {
      case Permission.viewOmzet:
        return 'Melihat laporan pendapatan dan statistik keuangan';
      case Permission.deleteTransaction:
        return 'Menghapus transaksi yang sudah tersimpan';
      case Permission.manageInventory:
        return 'Menambah, mengubah, atau menghapus stok dan layanan';
      case Permission.backupData:
        return 'Melakukan backup dan restore data';
      case Permission.manageStaff:
        return 'Menambah, mengubah, atau menghapus akun staff';
      case Permission.sendReminder:
        return 'Mengirim notifikasi pengingat ke pelanggan';
    }
  }
}

/// Auth State enum — menentukan routing di app.
enum AuthState {
  unauthenticated, // Belum login
  authenticating, // Sedang login
  missingProfile, // Login tapi belum punya profile (first time)
  authenticated, // Login + profile lengkap
}

/// ✅ NEW: Extension for AuthState
extension AuthStateExtension on AuthState {
  bool get isAuthenticated => this == AuthState.authenticated;
  bool get isUnauthenticated => this == AuthState.unauthenticated;
  bool get isLoading => this == AuthState.authenticating;
  bool get needsProfile => this == AuthState.missingProfile;
}

