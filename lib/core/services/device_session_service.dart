import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/objectbox_provider.dart';
import '../providers/sync_provider.dart';
import 'encryption_service.dart';

// ──────────────────────────────────────────────────────────────
// DATA MODEL
// ──────────────────────────────────────────────────────────────

/// Status validitas sesi perangkat ini
enum DeviceSessionStatus {
  valid,           // Perangkat ini adalah perangkat aktif
  displaced,       // Perangkat lain telah login — sesi ini dicabut
  wipeRequested,   // Owner meminta remote wipe di perangkat ini
  accountDisabled, // Akun dinonaktifkan/dihapus oleh Owner
  unknown,         // Belum dicek / tidak ada koneksi
}

/// Info perangkat yang disimpan di Firestore
class DeviceInfo {
  final String deviceId;
  final String model;
  final String osVersion;
  final DateTime loginAt;
  final String? deviceName;
  final DateTime? lastSeen;

  DeviceInfo({
    required this.deviceId,
    required this.model,
    required this.osVersion,
    required this.loginAt,
    this.deviceName,
    this.lastSeen,
  });

  Map<String, dynamic> toFirestore() => {
    'deviceId': deviceId,
    'model': model,
    'osVersion': osVersion,
    'loginAt': Timestamp.fromDate(loginAt),
    'deviceName': deviceName,
    'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
  };

  factory DeviceInfo.fromFirestore(Map<String, dynamic> data) => DeviceInfo(
    deviceId: data['deviceId'] as String? ?? '',
    model: data['model'] as String? ?? 'Unknown Device',
    osVersion: data['osVersion'] as String? ?? '',
    loginAt: (data['loginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    deviceName: data['deviceName'] as String?,
    lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
  );
}

// ──────────────────────────────────────────────────────────────
// SERVICE
// ──────────────────────────────────────────────────────────────

class DeviceSessionService {
  static const _deviceIdKey = 'device_session_id';
  static const _gracePeriod = Duration(seconds: 3);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final EncryptionService _encryption;

  DeviceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfoPlugin,
    EncryptionService? encryption,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
        _encryption = encryption ?? EncryptionService();

  // ── Device ID (persistent per install) ─────────────────────

  /// Ambil deviceId dari SharedPreferences, generate jika belum ada
  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  // ── Device Info ─────────────────────────────────────────────

  /// Ambil model perangkat yang readable, contoh: "Samsung Galaxy S24"
  Future<DeviceInfo> buildDeviceInfo() async {
    final deviceId = await getOrCreateDeviceId();
    String model = 'Unknown Device';
    String osVersion = '';

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        model = '${info.manufacturer} ${info.model}'.trim();
        osVersion = 'Android ${info.version.release}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        model = info.name;
        osVersion = '${info.systemName} ${info.systemVersion}';
      }
    } catch (e) {
      debugPrint('⚠️ DeviceInfo fetch error: $e');
    }

    return DeviceInfo(
      deviceId: deviceId,
      model: model,
      osVersion: osVersion,
      loginAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );
  }

  // ── Heartbeat Sync ──────────────────────────────────────────

  /// Memperbarui [lastSeen] dan [deviceName] di Firestore. 
  /// Dipanggil secara periodik oleh SyncWorker untuk menandakan perangkat masih aktif.
  Future<void> heartbeatSync(String userId, {String? currentDeviceName}) async {
    try {
      final Map<String, dynamic> updateData = {
        'activeDeviceInfo.lastSeen': FieldValue.serverTimestamp(),
      };
      
      if (currentDeviceName != null) {
        updateData['activeDeviceInfo.deviceName'] = currentDeviceName;
      }
      
      await _firestore.collection('users').doc(userId).update(updateData);
      debugPrint('💓 Heartbeat synced for $userId');
    } catch (e) {
      debugPrint('⚠️ Heartbeat sync error: $e');
    }
  }

  // ── Register Device on Login ────────────────────────────────

  /// Dipanggil segera setelah login berhasil.
  /// Menuliskan deviceId aktif ke Firestore → mencabut sesi perangkat lama.
  /// Juga mencatat histori login (maks 5 entri).
  Future<void> registerDevice(String userId) async {
    try {
      final info = await buildDeviceInfo();

      // 1. Ambil data lama untuk history
      final doc = await _firestore.collection('users').doc(userId).get();
      List<dynamic> history = [];
      if (doc.exists) {
        history = doc.data()?['loginHistory'] as List<dynamic>? ?? [];
      }

      // 2. Tambah ke history (paling baru di atas)
      history.insert(0, info.toFirestore());
      if (history.length > 5) {
        history = history.sublist(0, 5);
      }

      // 3. Update Firestore
      await _firestore.collection('users').doc(userId).set({
        'activeDeviceId': info.deviceId,
        'activeDeviceInfo': info.toFirestore(),
        'loginHistory': history,
        'pendingRemoteWipe': false,
      }, SetOptions(merge: true));

      debugPrint('📱 Device registered: ${info.model} (${info.deviceId})');
    } catch (e) {
      debugPrint('❌ registerDevice error: $e');
    }
  }

  // ── Watch Session Validity (Real-time) ──────────────────────

  /// Stream yang REAKTIF — perangkat ini akan tahu SEGERA jika sesi dicabut.
  /// Emit [DeviceSessionStatus.displaced] jika perangkat lain login.
  /// Emit [DeviceSessionStatus.wipeRequested] jika remote wipe diminta.
  Stream<DeviceSessionStatus> watchSessionValidity(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) return DeviceSessionStatus.unknown;

      final data = snapshot.data()!;
      
      // 1. Cek status akun (Prioritas Utama)
      final status = data['status'] as String? ?? 'active';
      if (status == 'disabled' || status == 'deleted') {
        return DeviceSessionStatus.accountDisabled;
      }

      final activeDeviceId = data['activeDeviceId'] as String?;
      final pendingWipe = data['pendingRemoteWipe'] as bool? ?? false;
      final myDeviceId = await getOrCreateDeviceId();

      // 2. Cek remote wipe request
      if (pendingWipe && activeDeviceId != myDeviceId) {
        return DeviceSessionStatus.wipeRequested;
      }

      // 3. Cek session displacement
      if (activeDeviceId != null && activeDeviceId != myDeviceId) {
        return DeviceSessionStatus.displaced;
      }

      return DeviceSessionStatus.valid;
    });
  }

  // ── Remote Wipe Command ─────────────────────────────────────

  /// Dipanggil dari perangkat BARU (Owner).
  /// Set flag `pendingRemoteWipe: true` di Firestore.
  /// Perangkat lama akan mendeteksi ini dan menghapus data lokalnya.
  Future<void> requestRemoteWipe(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'pendingRemoteWipe': true,
      }, SetOptions(merge: true));
      debugPrint('💣 Remote wipe requested for user: $userId');
    } catch (e) {
      debugPrint('❌ requestRemoteWipe error: $e');
    }
  }

  // ── Nuclear Verification & Execution ───────────────────────

  /// Double-Check: Verifikasi status ke Firebase Auth server.
  /// Return true hanya jika akun CONFIRMED revoked (disabled/not found).
  /// Return false jika network error (Safe Stop).
  Future<bool> verifyAccountStatusBeforeWipe() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return true; // Sudah logout/hilang

      // Reload untuk memaksa sinkronisasi status terbaru dari server
      await user.reload();
      
      // Jika reload berhasil dan user masih ada, cek apakah statusnya berubah (jarang terjadi di reload, biasanya throw)
      return false; 
    } on FirebaseAuthException catch (e) {
      debugPrint('🛡️ Verification check: ${e.code}');
      // Handle confirmed revocation codes
      if (e.code == 'user-disabled' || 
          e.code == 'user-not-found' || 
          e.code == 'invalid-user-token') {
        return true;
      }
      // Network error atau lainnya -> Jangan wipe (Safe Stop)
      return false;
    } catch (e) {
      debugPrint('🛡️ Unexpected verification error: $e');
      return false;
    }
  }

  /// THE NUCLEAR SEQUENCE (8-Step Execution)
  Future<void> executeNuclearSequence(WidgetRef ref) async {
    // 1. Set global state & Stop workers
    ref.read(isWipingProvider.notifier).state = true;
    final syncWorkerProviderRef = ref.read(syncWorkerProvider);
    if (syncWorkerProviderRef != null) {
      ref.invalidate(syncWorkerProvider);
    }
    debugPrint('☢️ NUCLEAR SEQUENCE INITIATED');

    // 2. Buffer & Final Check (Optional logic here)
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 3. Close ObjectBox Store (Critical step)
      // Kita panggil melalui dbProvider
      final db = ref.read(dbProvider);
      db.store.close();
      debugPrint('☢️ Step 3: ObjectBox closed');

      // 4. Delete Database Directory
      await executeLocalWipe();
      debugPrint('☢️ Step 4 & 5: Local data wiped');

      // 5. Clear Secure Storage (Additional wipe)
      // SEC-01 FIX: Gunakan centralized clearSecureStorage dari EncryptionService.
      await _encryption.clearSecureStorage();
      debugPrint('☢️ Step 6: Secure storage cleared');

      // 6. Clear Auth Session in Firestore (Explicitly reset active state)
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'activeDeviceId': FieldValue.delete(),
          'activeDeviceInfo': FieldValue.delete(),
        });
        debugPrint('☢️ Step 7: Firestore active session cleared');
      }

      // 7. Auth Sign Out
      await _auth.signOut();
      debugPrint('☢️ Step 8: FirebaseAuth signed out');

      debugPrint('☢️ NUCLEAR SEQUENCE COMPLETE');
    } catch (e) {
      debugPrint('❌ Nuclear sequence error: $e');
      // Tetap paksa logout sekalipun wipe parsial gagal
      await _auth.signOut();
    }
  }

  // ── Grace Period Sync ───────────────────────────────────────

  /// Tunggu [_gracePeriod] untuk memberi waktu sync terakhir sebelum wipe.
  Future<void> gracePeriodDelay() async {
    await Future.delayed(_gracePeriod);
  }

  // ── Execute Local Wipe ──────────────────────────────────────

  /// Hapus database ObjectBox lokal + SharedPreferences + SecureStorage cache.
  /// TIDAK menghapus foto/media yang tersimpan di Gallery publik.
  Future<void> executeLocalWipe() async {
    try {
      debugPrint('🗑️ Executing local data wipe...');

      // 1. Hapus folder ObjectBox (biasanya di documents/objectbox/)
      final docsDir = await getApplicationDocumentsDirectory();
      final objectboxDir = Directory('${docsDir.path}/objectbox');
      if (await objectboxDir.exists()) {
        await objectboxDir.delete(recursive: true);
        debugPrint('✅ ObjectBox database wiped');
      }

      // 2. Hapus SharedPreferences (kecuali deviceId, agar masih terlacak)
      final prefs = await SharedPreferences.getInstance();
      final myDeviceId = prefs.getString(_deviceIdKey);
      await prefs.clear();
      // Kembalikan deviceId agar audit trail tetap ada
      if (myDeviceId != null) {
        await prefs.setString(_deviceIdKey, myDeviceId);
      }

      debugPrint('✅ Local wipe complete');
    } catch (e) {
      debugPrint('❌ executeLocalWipe error: $e');
    }
  }

  // ── Get Active Device Info ──────────────────────────────────

  /// Ambil info perangkat yang sedang aktif dari Firestore (untuk ditampilkan
  /// di dialog di perangkat yang di-displace)
  Future<DeviceInfo?> getActiveDeviceInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!['activeDeviceInfo'] as Map<String, dynamic>?;
      if (data == null) return null;

      return DeviceInfo.fromFirestore(data);
    } catch (e) {
      debugPrint('❌ getActiveDeviceInfo error: $e');
      return null;
    }
  }

  // ── Clear Wipe Flag (after execution) ──────────────────────

  Future<void> clearWipeFlag(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'pendingRemoteWipe': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ clearWipeFlag error: $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ──────────────────────────────────────────────────────────────

final deviceSessionServiceProvider = Provider<DeviceSessionService>((ref) {
  return DeviceSessionService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    deviceInfoPlugin: DeviceInfoPlugin(),
    encryption: ref.watch(encryptionServiceProvider),
  );
});

/// State global untuk menandai proses penghapusan data sedang berjalan
final isWipingProvider = StateProvider<bool>((ref) => false);

/// Stream validitas sesi perangkat ini.
/// Hanya aktif jika user sudah login.
final deviceSessionStatusProvider = StreamProvider<DeviceSessionStatus>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(DeviceSessionStatus.unknown);

  final service = ref.watch(deviceSessionServiceProvider);
  return service.watchSessionValidity(user.uid);
});

/// Stream histori login pengguna dari Firestore.
final loginHistoryStreamProvider = StreamProvider<List<DeviceInfo>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) return [];
    final history = snapshot.data()?['loginHistory'] as List<dynamic>? ?? [];
    return history
        .map((e) => DeviceInfo.fromFirestore(e as Map<String, dynamic>))
        .toList();
  });
});

/// Provider untuk mengambil Device ID perangkat saat ini.
final currentDeviceIdProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(deviceSessionServiceProvider);
  return service.getOrCreateDeviceId();
});
