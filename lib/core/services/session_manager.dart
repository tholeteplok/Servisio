import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'device_session_service.dart';
import 'encryption_service.dart';
import '../utils/app_logger.dart';
import '../config/app_config.dart';

// 🎯 Policy Constants
class SessionPolicy {
  // Grace Periods (Three Zones)
  static const Duration ownerGracePeriod = Duration(hours: 24);
  static const Duration staffGracePeriod = Duration(hours: 9);
  
  // Warning Thresholds
  static const Duration ownerWarningThreshold = Duration(hours: 12);
  static const Duration staffWarningThreshold = Duration(hours: 8);
  
  // Handshake Configuration
  static const Duration handshakeCacheTtl = Duration(minutes: 2);
  static const int handshakeMaxRetry = 3;
  static const Duration handshakeTimeout = Duration(seconds: 10);
  
  // Master Password
  static const String masterPasswordKey = 'master_password_hash';
}

// 📊 Session Status Enum
enum SessionStatus {
  full,       // Zone 1: Full access (Online / < warningThreshold)
  warning,    // Zone 2: Restricted access (< gracePeriod)
  blocked,    // Zone 3: No access (> gracePeriod)
  valid,      // Alias for full
  invalid,    // Alias for blocked
}

extension SessionStatusX on SessionStatus {
  int get zone {
    switch (this) {
      case SessionStatus.valid:
      case SessionStatus.full:
        return 1;
      case SessionStatus.warning:
        return 2;
      case SessionStatus.blocked:
      case SessionStatus.invalid:
        return 3;
    }
  }

  String get zoneLabel {
    switch (zone) {
      case 1:
        return 'Terlindungi';
      case 2:
        return 'Terbatas';
      case 3:
      default:
        return 'Terkunci';
    }
  }
}

// 🔐 Access Level Enum
enum AccessLevel {
  full,               // Create, Read, Update, Delete*
  readOnly,           // Read only (all)
  readOnlyFinancial,  // Read only (non-financial)
  blocked,            // No access
}

// 🎯 Critical Action Types
enum CriticalActionType {
  deleteTransaction,
  editPaidFee,
  exportData,
  viewFinancials,
  manageStaff,
  changeSettings,
  manageInventory,
  editCustomer,
  deleteCustomer,
  manageBackup,
}

// 🛠️ Session Manager Class
class SessionManager with ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final EncryptionService _encryptionService;
  final DeviceSessionService _deviceSessionService;
  final http.Client _httpClient;
  final Connectivity _connectivity;

  SessionManager({
    FlutterSecureStorage? secureStorage,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    EncryptionService? encryptionService,
    DeviceSessionService? deviceSessionService,
    http.Client? httpClient,
    Connectivity? connectivity,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock_this_device),
            ),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptionService = encryptionService ?? EncryptionService(secureStorage: secureStorage),
        _deviceSessionService = deviceSessionService ?? DeviceSessionService(),
        _httpClient = httpClient ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  // ─────────────────────────────────────────────────────────────
  // WORKSHOP MANAGEMENT
  // ─────────────────────────────────────────────────────────────

  String? _activeWorkshopId;
  List<WorkshopInfo> _availableWorkshops = [];

  String? get activeWorkshopId => _activeWorkshopId;
  List<WorkshopInfo> get availableWorkshops => _availableWorkshops;

  /// Load workshop list dari Firestore (users/{userId}/accessibleWorkshops)
  Future<void> loadWorkshops() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final data = doc.data();
      final List<dynamic> list = data?['accessibleWorkshops'] ?? [];

      _availableWorkshops = list.map((e) {
        final m = e as Map<String, dynamic>;
        return WorkshopInfo(
          id: m['workshopId'] as String? ?? '',
          name: m['name'] as String? ?? 'Bengkel',
          ownerId: m['ownerId'] as String? ?? user.uid,
          role: m['role'] as String? ?? 'teknisi',
        );
      }).toList();

      // ✅ FIX: Jika list kosong tapi ada bengkel_id di storage (karena baru login/pernah login)
      // Coba resolve agar _availableWorkshops tidak kosong.
      if (_availableWorkshops.isEmpty) {
        final savedId = await _secureStorage.read(key: 'active_workshop_id') 
            ?? await _secureStorage.read(key: 'bengkel_id');
        
        if (savedId != null && savedId.isNotEmpty) {
          appLogger.info('Workshops field missing, attempting to resolve from ID: $savedId', 
              context: 'SessionManager');
          await resolveAndSelectWorkshop(savedId);
          return; // resolveAndSelectWorkshop sudah memanggil notifyListeners
        }
      }

      // Auto-select jika hanya 1 workshop
      if (_availableWorkshops.length == 1) {
        await selectWorkshop(_availableWorkshops.first.id);
      } else {
        // Cek apakah ada workshop tersimpan sebelumnya di secure storage
        final savedId = await _secureStorage.read(key: 'active_workshop_id');
        if (savedId != null &&
            _availableWorkshops.any((w) => w.id == savedId)) {
          _activeWorkshopId = savedId;
        }
      }

      notifyListeners();
      appLogger.info('Workshops loaded: ${_availableWorkshops.length} items', context: 'SessionManager');
    } catch (e) {
      appLogger.error('Gagal load workshops', context: 'SessionManager', error: e);
    }
  }

  /// Pilih workshop aktif
  Future<void> selectWorkshop(String workshopId) async {
    _activeWorkshopId = workshopId;
    await _secureStorage.write(key: 'active_workshop_id', value: workshopId);
    // Juga update legacy bengkel_id untuk kompatibilitas sementara
    await _secureStorage.write(key: 'bengkel_id', value: workshopId);
    notifyListeners();
    appLogger.info('Workshop selected: $workshopId', context: 'SessionManager');
  }

  /// Resolve ownerId dari Firestore registry lalu inject ke _availableWorkshops.
  /// Dipakai saat fresh install dimana accessibleWorkshops belum terisi.
  Future<void> resolveAndSelectWorkshop(String workshopId) async {
    // Sudah ada → cukup activate
    if (_availableWorkshops.any((w) => w.id == workshopId)) {
      await selectWorkshop(workshopId);
      return;
    }

    try {
      // Baca ownerUid dari registry /bengkel/{workshopId}
      final registryDoc = await _firestore
          .collection('bengkel')
          .doc(workshopId)
          .get();

      final data = registryDoc.data();
      final ownerUid = data?['ownerUid'] as String?
          ?? _auth.currentUser?.uid
          ?? '';

      final name = data?['namaUsaha'] as String? ?? 'Bengkel';

      // Inject entry ke _availableWorkshops agar activeWorkshopOwnerId bisa resolve
      _availableWorkshops = [
        WorkshopInfo(id: workshopId, name: name, ownerId: ownerUid, role: 'owner'),
        ..._availableWorkshops.where((w) => w.id != workshopId),
      ];

      _activeWorkshopId = workshopId;
      await _secureStorage.write(key: 'active_workshop_id', value: workshopId);
      await _secureStorage.write(key: 'bengkel_id', value: workshopId);
      notifyListeners();

      appLogger.info(
        'Workshop resolved from registry: $workshopId (owner: $ownerUid)',
        context: 'SessionManager',
      );
    } catch (e) {
      appLogger.error('Gagal resolve workshop dari registry', 
          context: 'SessionManager', error: e);
      // Fallback: tetap coba set ID walaupun ownerId mungkin null
      await selectWorkshop(workshopId);
    }
  }

  /// Dapatkan ownerId dari workshop yang sedang aktif
  String? get activeWorkshopOwnerId {
    if (_activeWorkshopId == null) return null;
    try {
      return _availableWorkshops
          .firstWhere((w) => w.id == _activeWorkshopId)
          .ownerId;
    } catch (_) {
      return null;
    }
  }

  /// FIX: Pastikan workshop ter-resolve dengan ownerId yang valid
  /// Dipanggil sebelum operasi sync untuk memastikan path Firestore benar
  Future<void> ensureWorkshopResolved() async {
    // Jika sudah ada ownerId, tidak perlu melakukan apa-apa
    if (activeWorkshopOwnerId != null && _activeWorkshopId != null) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    // Jika activeWorkshopId ada tapi ownerId tidak, coba resolve
    if (_activeWorkshopId != null && activeWorkshopOwnerId == null) {
      appLogger.info(
        'Resolving ownerId for workshop: $_activeWorkshopId',
        context: 'SessionManager',
      );
      await resolveAndSelectWorkshop(_activeWorkshopId!);
      return;
    }

    // Jika tidak ada sama sekali, coba load dari Firestore
    await loadWorkshops();
    
    // Jika setelah load masih belum ada, coba ambil dari bengkelId di secure storage
    if (_activeWorkshopId == null) {
      final savedBengkelId = await _secureStorage.read(key: 'bengkel_id');
      if (savedBengkelId != null && savedBengkelId.isNotEmpty) {
        await resolveAndSelectWorkshop(savedBengkelId);
      }
    }
  }

  /// Buat workshop baru (TAHAP 3.1)
  Future<String> createWorkshop(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User belum login');

    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workshops')
        .add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'ownerId': user.uid,
    });

    final workshopId = docRef.id;

    // Buat member entry untuk owner
    await docRef.collection('members').doc(user.uid).set({
      'userId': user.uid,
      'role': 'owner',
      'permissions': {'all': true},
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    // Buat settings default
    await docRef.collection('settings').doc('default').set({
      'currency': 'IDR',
      'taxRate': 0.11,
      'invoicePrefix': 'INV',
      'lowStockAlert': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Tambahkan ke accessibleWorkshops user tersebut
    await _firestore.collection('users').doc(user.uid).update({
      'accessibleWorkshops': FieldValue.arrayUnion([{
        'workshopId': workshopId,
        'ownerId': user.uid,
        'name': name,
        'role': 'owner',
      }])
    });

    // Refresh list dan pilih yang baru
    await loadWorkshops();
    await selectWorkshop(workshopId);

    return workshopId;
  }

  // ─────────────────────────────────────────────────────────────
  // CONFIGURATION
  // ─────────────────────────────────────────────────────────────

  /// Cached handshake URL resolved from env var / Firestore / default.
  String? _cachedHandshakeUrl;

  /// Resolve handshake URL with 3-layer priority:
  /// 1. Cache (already resolved)
  /// 2. Compile-time env var (AppConfig.handshakeUrl)
  /// 3. Firestore remote config (_internal/handshake_config)
  /// 4. Default (AppConfig.defaultHandshakeUrl)
  Future<String> _getHandshakeUrl() async {
    // 1. Check cache
    if (_cachedHandshakeUrl != null) {
      return _cachedHandshakeUrl!;
    }

    // 2. Use compile-time env var
    final envUrl = AppConfig.handshakeUrl;
    if (envUrl != AppConfig.defaultHandshakeUrl) {
      _cachedHandshakeUrl = envUrl;
      appLogger.info('Using handshake URL from env: $envUrl', context: 'SessionManager');
      return envUrl;
    }

    // 3. Fallback to Firestore config (only once)
    try {
      final doc = await _firestore
          .collection('_internal')
          .doc('handshake_config')
          .get();

      if (doc.exists) {
        final firestoreUrl = doc.data()?['url'] as String?;
        if (firestoreUrl != null && firestoreUrl.isNotEmpty) {
          _cachedHandshakeUrl = firestoreUrl;
          appLogger.info('Using handshake URL from Firestore: $firestoreUrl', context: 'SessionManager');
          return firestoreUrl;
        }
      }
    } catch (e) {
      appLogger.warning('Failed to fetch handshake config from Firestore', context: 'SessionManager', error: e);
    }

    // 4. Final fallback to default
    _cachedHandshakeUrl = AppConfig.defaultHandshakeUrl;
    return _cachedHandshakeUrl!;
  }
  
  // ─────────────────────────────────────────────────────────────
  // MASTER PASSWORD (OWNER ONLY)
  // ─────────────────────────────────────────────────────────────
  
  /// Hash and save Master Password with a random salt (during registration)
  Future<void> setupMasterPassword(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(pin);
    
    // Hash: SHA-256(salt + pin)
    final hash = sha256.convert([...saltBytes, ...pinBytes]).toString();
    
    // Store as salt:hash
    await _secureStorage.write(
      key: SessionPolicy.masterPasswordKey, 
      value: '$salt:$hash',
    );
    appLogger.info('Master Password setup complete (Salted & Hashed)', context: 'SessionManager');
  }
  
  /// Verify Master Password using constant-time comparison to prevent timing attacks.
  Future<bool> verifyMasterPassword(String pin) async {
    final savedValue = await _secureStorage.read(key: SessionPolicy.masterPasswordKey);
    if (savedValue == null) return false;

    // Handle legacy (unsalted) or new (salted) format
    if (!savedValue.contains(':')) {
      final inputHash = sha256.convert(utf8.encode(pin)).toString();
      return _safeEquals(savedValue, inputHash);
    }

    final parts = savedValue.split(':');
    if (parts.length != 2) return false;

    final salt = parts[0];
    final savedHash = parts[1];
    
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(pin);
    final inputHash = sha256.convert([...saltBytes, ...pinBytes]).toString();

    return _safeEquals(savedHash, inputHash);
  }

  /// Constant-time comparison
  bool _safeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
  
  // ─────────────────────────────────────────────────────────────
  // SESSION MANAGEMENT
  // ─────────────────────────────────────────────────────────────
  
  /// Save session after successful login
  Future<void> saveSession({
    required String token,
    required String userId,
    required String role,
    required String bengkelId,
  }) async {
    try {
      final expiry = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();

      // SEC-04 FIX: Tidak lagi menyimpan 'auth_token' di SecureStorage.
      // Firebase Auth SDK sudah mengelola token-nya sendiri secara aman.
      // Menyimpan duplikat hanya menambah attack surface tanpa manfaat.
      // Gunakan FirebaseAuth.instance.currentUser.getIdToken() jika token diperlukan.
      await _secureStorage.write(key: 'user_id', value: userId);
      await _secureStorage.write(key: 'user_role', value: role);
      await _secureStorage.write(key: 'bengkel_id', value: bengkelId);
      await _secureStorage.write(key: 'last_auth_timestamp', value: now.millisecondsSinceEpoch.toString());
      await _secureStorage.write(key: 'token_expiry', value: expiry.millisecondsSinceEpoch.toString());
      await _secureStorage.write(key: 'session_version', value: '2.0');
      
      appLogger.info('Session saved for user: $userId (role: $role)', context: 'SessionManager');
    } catch (e) {
      appLogger.error('Error saving session', context: 'SessionManager', error: e);
      rethrow;
    }
  }
  
  /// Clear session (logout)
  Future<void> clearSession() async {
    // SEC-01 FIX: Gunakan clearSessionDataOnly agar master key tetap aman.
    await _encryptionService.clearSessionDataOnly();
    
    // LGK-04 FIX: Hapus metadata sesi tambahan
    await _secureStorage.delete(key: 'user_id');
    await _secureStorage.delete(key: 'user_role');
    await _secureStorage.delete(key: 'bengkel_id');
    await _secureStorage.delete(key: 'active_workshop_id');
    await _secureStorage.delete(key: 'token_expiry');
    await _secureStorage.delete(key: 'last_auth_timestamp');
    await _secureStorage.delete(key: 'handshake_cache');
    
    _activeWorkshopId = null;
    _availableWorkshops = [];
    
    await _auth.signOut();
    notifyListeners();
    appLogger.info('Session cleared & Signed out', context: 'SessionManager');
  }

  /// ✅ NEW: Validasi Token ke Firebase Auth Server
  /// Memastikan masa berlaku token disinkronkan langsung dari server.
  Future<bool> _validateFirebaseToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Use cached token by default to avoid redundant network calls
      final tokenResult = await user.getIdTokenResult(false);
      final expirationTime = tokenResult.expirationTime;

      if (expirationTime == null) return false;

      // UPDATE metadata di SecureStorage
      await _secureStorage.write(
        key: 'token_expiry',
        value: expirationTime.millisecondsSinceEpoch.toString(),
      );

      // UPDATE last_auth_timestamp juga agar offline duration tidak blocked prematur
      await _secureStorage.write(
        key: 'last_auth_timestamp',
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Simpan role terbaru dari claims juga
      final role = tokenResult.claims?['role'] as String? ?? 'teknisi';
      await _secureStorage.write(key: 'user_role', value: role);
      
      appLogger.info('Token validated & updated: Expiry ${expirationTime.toIso8601String()}', context: 'SessionManager');
      return true;
    } catch (e) {
      appLogger.error('Token validation failed', context: 'SessionManager', error: e);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REFRESH & HANDSHAKE HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Force refresh the local auth timestamp and clear handshake cache.
  /// Called upon successful local unlock (Biometric/PIN).
  Future<void> forceRefreshAuthTimestamp() async {
    final now = DateTime.now();
    await _secureStorage.write(
      key: 'last_auth_timestamp',
      value: now.millisecondsSinceEpoch.toString(),
    );
    await _secureStorage.delete(key: 'handshake_cache');
    appLogger.info('Local auth timestamp refreshed & handshake cache cleared', context: 'SessionManager');
  }

  /// Check if session needs a background refresh (handshake).
  /// Called periodically by the main layout.
  Future<void> refreshSessionIfNeeded() async {
    final lastAuthStr = await _secureStorage.read(key: 'last_auth_timestamp');
    if (lastAuthStr == null) return;

    final lastAuth = DateTime.fromMillisecondsSinceEpoch(int.parse(lastAuthStr));
    final age = DateTime.now().difference(lastAuth);

    // If age > 30 minutes, attempt a handshake to keep session fresh.
    // 30 mins is safe even for staff (9h grace) and owner (24h grace).
    if (age > const Duration(minutes: 30)) {
      appLogger.info('Session age ${age.inMinutes}m — Triggering background refresh', context: 'SessionManager');
      // Clearing handshake cache to ensure validateSession actually performs a network call
      await _secureStorage.delete(key: 'handshake_cache');
      await validateSession();
    }
  }
  
  // ─────────────────────────────────────────────────────────────
  // SESSION VALIDATION (MAIN ENTRY POINT)
  // ─────────────────────────────────────────────────────────────
  
  /// Validate session (online → handshake, offline → local validation)
  Future<SessionStatus> validateSession() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected) {
        // ✅ USER FIX 1: Validasi token ke server jika ada internet
        // Ini memastikan token_expiry selalu update sebelum handshake/offline check
        await _validateFirebaseToken();
        return await _handshakeOnline();
      } else {
        return await _validateOffline();
      }
    } catch (e) {
      appLogger.error('Session validation error', context: 'SessionManager', error: e);
      return SessionStatus.blocked;
    }
  }
  
  /// Online: Handshake with Firebase Cloud Functions + Audit Sync
  /// ✅ ENHANCED: Now sends device fingerprint data for server-side validation.
  Future<SessionStatus> _handshakeOnline() async {
    // Check cache first (15 minutes TTL)
    final cached = await _secureStorage.read(key: 'handshake_cache');
    if (cached != null) {
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(int.parse(cached));
      if (DateTime.now().difference(cachedTime) < SessionPolicy.handshakeCacheTtl) {
        return SessionStatus.valid;
      }
    }

    // LGK-04 FIX: Cek apakah masih dalam periode rate-limit cooldown.
    // Jika ya, skip handshake dan langsung validasi offline tanpa retry.
    final rateLimitStr = await _secureStorage.read(key: 'rate_limit_until');
    if (rateLimitStr != null) {
      final rateLimitUntil = DateTime.fromMillisecondsSinceEpoch(int.parse(rateLimitStr));
      if (DateTime.now().isBefore(rateLimitUntil)) {
        appLogger.info('Handshake skipped — rate limit cooldown aktif hingga $rateLimitUntil', context: 'SessionManager');
        return await _validateOffline();
      } else {
        // Cooldown sudah lewat, hapus flag
        await _secureStorage.delete(key: 'rate_limit_until');
      }
    }

    // ── PHASE 1.3: Build Device Fingerprint Payload ────────────
    final deviceId = await _deviceSessionService.getOrCreateDeviceId();
    String platform = 'unknown';
    try {
      if (Platform.isAndroid) platform = 'android';
      if (Platform.isIOS) platform = 'ios';
    } catch (_) {}

    String appVersion = 'unknown';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {}

    final requestBody = jsonEncode({
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
    });

    int retry = 0;
    while (retry < SessionPolicy.handshakeMaxRetry) {
      try {
        final user = _auth.currentUser;
        if (user == null) return SessionStatus.invalid;

        final token = await user.getIdToken(true);
        if (token == null) return SessionStatus.invalid;

        final handshakeUrl = await _getHandshakeUrl();

        final response = await _httpClient.post(
          Uri.parse(handshakeUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: requestBody,
        ).timeout(SessionPolicy.handshakeTimeout);

        if (response.statusCode == 200) {
          final now = DateTime.now();
          await _secureStorage.write(key: 'handshake_cache', value: now.millisecondsSinceEpoch.toString());
          await _secureStorage.write(key: 'last_auth_timestamp', value: now.millisecondsSinceEpoch.toString());
          await _syncEmergencyLogs();
          return SessionStatus.valid;

        } else if (response.statusCode == 401) {
          appLogger.warning('Handshake rejected (401): Sesi tidak valid atau token kedaluwarsa. Body: ${response.body}', context: 'SessionManager');
          return SessionStatus.invalid;

        } else if (response.statusCode == 429) {
          // LGK-04 FIX: Simpan timestamp cooldown dengan exponential backoff.
          // Backoff: 5 menit * 2^retry (5m, 10m, 20m, ...) maks 2 jam.
          final backoffMinutes = (5 * (1 << retry)).clamp(5, 120);
          final cooldownUntil = DateTime.now().add(Duration(minutes: backoffMinutes));
          await _secureStorage.write(
            key: 'rate_limit_until',
            value: cooldownUntil.millisecondsSinceEpoch.toString(),
          );
          appLogger.warning('Handshake rate limited (429). Cooldown $backoffMinutes menit hingga $cooldownUntil.', context: 'SessionManager');
          return await _validateOffline();
        }
      } catch (e) {
        if (e is http.ClientException) {
          appLogger.warning('Handshake network error (attempt ${retry + 1}): Periksa koneksi internet.', context: 'SessionManager', error: e);
        } else if (e is SocketException) {
          appLogger.warning('Handshake socket error (attempt ${retry + 1}): Server tidak terjangkau.', context: 'SessionManager', error: e);
        } else {
          appLogger.warning('Handshake attempt ${retry + 1} unexpected error', context: 'SessionManager', error: e);
        }
        retry++;
        if (retry < SessionPolicy.handshakeMaxRetry) {
          // LGK-04 FIX: Exponential backoff antar retry (2s, 4s, 8s)
          final waitSeconds = 2 * (1 << (retry - 1));
          appLogger.info('Retrying handshake in $waitSeconds seconds...', context: 'SessionManager');
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
      }
      break;
    }

    return await _validateOffline();
  }
  
  /// Offline Validation based on last_auth_timestamp
  Future<SessionStatus> _validateOffline() async {
    final lastAuthStr = await _secureStorage.read(key: 'last_auth_timestamp');
    final tokenExpiryStr = await _secureStorage.read(key: 'token_expiry');
    final role = await _secureStorage.read(key: 'user_role');
    
    // LGK-04 FIX: Tambahkan logging yang detail untuk diagnosa
    if (lastAuthStr == null) appLogger.warning('Offline validation: last_auth_timestamp missing', context: 'SessionManager');
    if (tokenExpiryStr == null) appLogger.warning('Offline validation: token_expiry missing', context: 'SessionManager');
    if (role == null) appLogger.warning('Offline validation: user_role missing', context: 'SessionManager');
    
    if (lastAuthStr == null || tokenExpiryStr == null || role == null) {
      // Jika metadata kritis hilang, kita tidak bisa memvalidasi sesi offline.
      // Sesi harus diblokir untuk keamanan.
      return SessionStatus.blocked;
    }
    
    final lastAuth = DateTime.fromMillisecondsSinceEpoch(int.parse(lastAuthStr));
    final tokenExpiry = DateTime.fromMillisecondsSinceEpoch(int.parse(tokenExpiryStr));
    final now = DateTime.now();
    final offlineDuration = now.difference(lastAuth);
    
    // JWT expiry = HARD LIMIT
    if (now.isAfter(tokenExpiry)) {
      appLogger.warning('Offline validation: Token Expired (Expiry: $tokenExpiry)', context: 'SessionManager');
      return SessionStatus.blocked;
    }
    
    final gracePeriod = role == 'owner' ? SessionPolicy.ownerGracePeriod : SessionPolicy.staffGracePeriod;
    final warningThreshold = role == 'owner' ? SessionPolicy.ownerWarningThreshold : SessionPolicy.staffWarningThreshold;
    
    if (offlineDuration < warningThreshold) {
      return SessionStatus.full;
    } else if (offlineDuration < gracePeriod) {
      appLogger.info('Offline validation: Entering Warning Zone (${offlineDuration.inHours}h offline)', context: 'SessionManager');
      return SessionStatus.warning;
    } else {
      appLogger.warning('Offline validation: Blocked — Offline too long (${offlineDuration.inHours}h offline)', context: 'SessionManager');
      return SessionStatus.blocked;
    }
  }
  
  // ─────────────────────────────────────────────────────────────
  // AUDIT LOGS & SYNC
  // ─────────────────────────────────────────────────────────────
  
  /// Sync local emergency logs to Firestore
  Future<void> _syncEmergencyLogs() async {
    try {
      final logsStr = await _secureStorage.read(key: 'emergency_logs');
      if (logsStr == null) return;
      
      final List<dynamic> logs = jsonDecode(logsStr);
      if (logs.isEmpty) return;
      
      final bengkelId = await _secureStorage.read(key: 'bengkel_id');
      if (bengkelId == null) return;
      
      appLogger.info('Syncing ${logs.length} emergency logs to Firestore...', context: 'SessionManager');
      
      final batch = _firestore.batch();
      for (var log in logs) {
        final docRef = _firestore
            .collection('bengkel')
            .doc(bengkelId)
            .collection('security_audit_logs')
            .doc();
        batch.set(docRef, {
          ...Map<String, dynamic>.from(log),
          'syncedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      await _secureStorage.delete(key: 'emergency_logs');
      appLogger.info('Audit logs synced and cleared', context: 'SessionManager');
    } catch (e) {
      appLogger.error('Failed to sync emergency logs', context: 'SessionManager', error: e);
    }
  }
  
  /// Record critical security action locally
  Future<void> recordSecurityEvent(String action, {Map<String, dynamic>? extra}) async {
    try {
      final now = DateTime.now().toIso8601String();
      final userId = await _secureStorage.read(key: 'user_id');
      final bengkelId = await _secureStorage.read(key: 'bengkel_id');
      
      final event = {
        'timestamp': now,
        'action': action,
        'userId': userId,
        'bengkelId': bengkelId,
        'offline': true,
        if (extra != null) ...extra,
      };
      
      final logsStr = await _secureStorage.read(key: 'emergency_logs');
      final List<dynamic> logs = logsStr != null ? jsonDecode(logsStr) : [];
      logs.add(event);

      // SEC-02 FIX: Rolling log — batasi maks 100 entry agar tidak mengisi
      // SecureStorage (limit ~64KB di beberapa implementasi Keychain iOS).
      // Hapus entry paling lama jika melebihi batas.
      const int maxLogEntries = 100;
      final trimmedLogs = logs.length > maxLogEntries
          ? logs.sublist(logs.length - maxLogEntries)
          : logs;
      
      await _secureStorage.write(key: 'emergency_logs', value: jsonEncode(trimmedLogs));
    } catch (e) {
      appLogger.error('Error recording security event', context: 'SessionManager', error: e);
    }
  }
  
  // ─────────────────────────────────────────────────────────────
  // EMERGENCY OVERRIDE (Owner Only)
  // ─────────────────────────────────────────────────────────────
  
  Future<bool> activateEmergencyOverride() async {
    try {
      // SEC-03 FIX: Jangan andalkan role dari SecureStorage saja — nilai ini
      // bisa dimanipulasi pada device yang di-root/jailbreak. Verifikasi
      // langsung dari Firebase token (trusted source) sebelum override aktif.
      final user = _auth.currentUser;
      if (user == null) return false;

      final tokenResult = await user.getIdTokenResult(true); // force refresh
      final claimsRole = tokenResult.claims?['role'] as String?;

      if (claimsRole != 'owner') {
        appLogger.warning('Emergency override ditolak — role dari Firebase: $claimsRole', context: 'SessionManager');
        return false;
      }

      await _secureStorage.write(
        key: 'last_auth_timestamp',
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      
      await recordSecurityEvent('emergency_override_activated', extra: {
        'verified_via': 'firebase_token',
        'claimed_role': claimsRole,
      });
      return true;
    } catch (e) {
      appLogger.error('Emergency override failed', context: 'SessionManager', error: e);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACCESS CONTROL
  // ─────────────────────────────────────────────────────────────
  
  Future<AccessLevel> getAccessLevel() async {
    final status = await validateSession();
    final role = await _secureStorage.read(key: 'user_role');
    
    switch (status) {
      case SessionStatus.valid:
      case SessionStatus.full:
        return AccessLevel.full;
      case SessionStatus.warning:
        return role == 'owner' ? AccessLevel.readOnlyFinancial : AccessLevel.readOnly;
      case SessionStatus.blocked:
      case SessionStatus.invalid:
        return AccessLevel.blocked;
    }
  }
  
  Future<bool> canPerformAction(CriticalActionType action, [AccessLevel? currentLevel]) async {
    final level = currentLevel ?? await getAccessLevel();
    if (level == AccessLevel.blocked) return false;
    if (level == AccessLevel.readOnly) return false;
    
    if (level == AccessLevel.readOnlyFinancial) {
      if (action == CriticalActionType.viewFinancials || action == CriticalActionType.exportData) {
        return false;
      }
    }
    return true;
  }
}

// ────────────────────────────────────────────
// WORKSHOP INFO MODEL
// ────────────────────────────────────────────

class WorkshopInfo {
  final String id;
  final String name;
  final String ownerId;
  final String role;
  const WorkshopInfo({
    required this.id,
    required this.name,
    required this.ownerId,
    this.role = 'teknisi',
  });
}
