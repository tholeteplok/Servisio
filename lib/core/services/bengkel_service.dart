import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'encryption_service.dart';
import '../sync/sync_telemetry.dart';
import 'device_session_service.dart';

/// Service untuk mengelola Bengkel: generate ID, claim, join, dan lookup.
class BengkelService {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryption;
  final DeviceSessionService _deviceSession;

  BengkelService({
    FirebaseFirestore? firestore,
    EncryptionService? encryption,
    DeviceSessionService? deviceSession,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryption = encryption!,
        _deviceSession = deviceSession ?? DeviceSessionService();

  /// Generate unique BengkelID dengan prefix dari nama bengkel.
  /// Contoh: "Tentrem Auto" → "TENTREMAUTO-A1B2C3"
  String generateBengkelId(String prefix) {
    final cleanPrefix = prefix.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final truncated = cleanPrefix.length > 10
        ? cleanPrefix.substring(0, 10)
        : cleanPrefix;
    final random = const Uuid().v4().substring(0, 6).toUpperCase();
    return '$truncated-$random';
  }

  /// Claim BengkelID dengan atomic transaction (mencegah duplicate).
  /// Throws Exception if failed.
  Future<void> claimBengkelId({
    required String bengkelId,
    required String ownerUid,
    required String bengkelName,
    required String pin,
  }) async {
    final ref = _firestore.collection('bengkel').doc(bengkelId);

    // 1. Wrap the local master key with the provided password
    final wrappedKey = await _encryption.wrapMasterKey(
      pin,
      bengkelId,
    );
    if (wrappedKey == null) {
      throw Exception('Sistem enkripsi belum siap. Coba restart aplikasi.');
    }

    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (doc.exists) {
        throw Exception('Bengkel ID "$bengkelId" sudah digunakan.');
      }

      // 1. Set bengkel metadata (no sensitive keys here)
      transaction.set(ref, {
        'ownerUid': ownerUid,
        'name': bengkelName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'plan': 'solo',
        'settings': {
          'allowStaffInvite': true,
          'requireBiometricForDelete': true,
        },
      });

      // 2. Set masterKey in protected 'secrets' sub-collection
      final secretRef = ref.collection('secrets').doc('masterKey');
      transaction.set(secretRef, {
        'value': wrappedKey,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 'v1',
      });

      // 3. Record security audit event (Audit K-3)
      // Get device ID asynchronously
      final deviceId = await _getDeviceId();
      SyncTelemetry().securityEvent(
        'bengkel_claimed',
        userId: ownerUid,
        extra: {'bengkelId': bengkelId, 'deviceId': deviceId},
      );
    });
  }

  /// Real-time availability check (untuk debounce UI).
  Stream<bool> isBengkelIdAvailableStream(String bengkelId) {
    if (bengkelId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('bengkel')
        .doc(bengkelId)
        .snapshots()
        .map((snapshot) => !snapshot.exists);
  }

  /// One-time availability check (untuk validation sebelum submit).
  Future<bool> isBengkelIdAvailable(String bengkelId) async {
    final doc = await _firestore.collection('bengkel').doc(bengkelId).get();
    return !doc.exists;
  }

  /// Get bengkel data by ID.
  Future<DocumentSnapshot> getBengkel(String bengkelId) async {
    return await _firestore.collection('bengkel').doc(bengkelId).get();
  }

  /// Recover the Master Key (Check new sub-collection first, then fallback to root)
  Future<String?> getWrappedMasterKey(String bengkelId) async {
    final bengkelRef = _firestore.collection('bengkel').doc(bengkelId);
    
    // 1. Check new sub-collection (protected)
    final secretDoc = await bengkelRef.collection('secrets').doc('masterKey').get();
    if (secretDoc.exists) {
      return secretDoc.data()?['value'] as String?;
    }

    // 2. Fallback to legacy root storage
    final bengkelDoc = await bengkelRef.get();
    if (bengkelDoc.exists) {
      return bengkelDoc.data()?['masterKey'] as String?;
    }

    return null;
  }

  /// Join existing bengkel (untuk staff).
  Future<void> joinBengkel({
    required String bengkelId,
    required String uid,
    required String name,
    required String email,
    required String pin,
    String role = 'teknisi',
  }) async {
    final bengkelRef = _firestore.collection('bengkel').doc(bengkelId);
    final bengkelDoc = await bengkelRef.get();

    if (!bengkelDoc.exists) {
      throw Exception('Bengkel tidak ditemukan');
    }

    // 1. Recover the Master Key using centralized helper
    final wrappedKey = await getWrappedMasterKey(bengkelId);

    if (wrappedKey == null) {
      throw Exception('Bengkel tidak memiliki Master Key yang valid');
    }

    final success = await _encryption.unwrapAndSaveMasterKey(
      wrappedKey,
      pin,
      bengkelId,
    );
    if (!success) {
      SyncTelemetry().securityEvent(
        'join_failed',
        userId: uid,
        extra: {'bengkelId': bengkelId, 'reason': 'invalid_pin'},
      );
      throw Exception('PIN Workshop salah atau tidak valid');
    }

    SyncTelemetry().securityEvent(
      'join_success',
      userId: uid,
      extra: {'bengkelId': bengkelId},
    );

    // 2. Register user in bengkel
    final userRef = _firestore.collection('users').doc(uid);
    await userRef.set({
      'uid': uid,
      'name': name,
      'email': email,
      'bengkelId': bengkelId,
      'role': role,
      'permissions': _getDefaultPermissions(role),
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'deviceTokens': [],
    }, SetOptions(merge: true));
  }

  /// Default permissions sesuai role.
  List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'owner':
        return [
          'viewOmzet',
          'deleteTransaction',
          'manageInventory',
          'backupData',
          'manageStaff',
          'sendReminder',
        ];
      case 'admin':
        return ['manageInventory', 'sendReminder'];
      case 'teknisi':
        return [];
      default:
        return [];
    }
  }

  Future<String> _getDeviceId() async {
    try {
      return await _deviceSession.getOrCreateDeviceId();
    } catch (e) {
      return 'unknown';
    }
  }

  /// Update Master Key and migrate to sub-collection.
  /// This encapsulates the rotation logic and prevents direct Firestore manipulation.
  Future<void> updateMasterKey({
    required String bengkelId,
    required String wrappedKey,
    required String userId,
  }) async {
    final bengkelRef = _firestore.collection('bengkel').doc(bengkelId);
    final secretRef = bengkelRef.collection('secrets').doc('masterKey');

    await _firestore.runTransaction((transaction) async {
      // 1. Delete legacy key from root if it exists
      transaction.update(bengkelRef, {
        'masterKey': FieldValue.delete(),
      });

      // 2. Write new key to sub-collection
      transaction.set(secretRef, {
        'value': wrappedKey,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 'v1',
      }, SetOptions(merge: true));
    });

    // 🛡️ Log migration event
    SyncTelemetry().securityEvent(
      'master_key_migrated',
      userId: userId,
      extra: {'bengkelId': bengkelId},
    );
  }
}


