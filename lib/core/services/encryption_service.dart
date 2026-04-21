import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';

/// Service untuk encrypt/decrypt PII (Personally Identifiable Information)
/// seperti nama dan no HP pelanggan sebelum disimpan ke database lokal/cloud.
class EncryptionService {
  final FlutterSecureStorage _storage;
  encrypt.Encrypter? _encrypter;

  EncryptionService({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage();

  /// Kunci master dalam memory (plaintext). Tidak disimpan permanen untuk
  /// mencegah PIN bypass saat restart app (Session-only).
  String? _masterKeyBase64;

  final String _keyAlias = 'servisio_master_key';
  static const String encryptionPrefix = 'enc:v1:';
  static const int pbkdf2Iterations = 100000;

  /// Inisialisasi: Generate key if not exists, and store to Secure Storage.
  bool get isInitialized => _encrypter != null;

  /// Check if the master key exists in secure storage
  Future<bool> isMasterKeySet() async {
    return await _storage.containsKey(key: _keyAlias);
  }

  /// Inisialisasi encrypter.
  /// Mendukung migrasi: jika kunci ditemukan di SecureStorage (legacy), 
  /// pindahkan ke memory dan hapus dari storage.
  Future<void> init() async {
    try {
      // 1. Cek memory dulu (prioritas session aktif)
      String? keyBase64 = _masterKeyBase64;

      // 2. Fallback ke SecureStorage (legacy/migration support)
      if (keyBase64 == null) {
        keyBase64 = await _storage.read(key: _keyAlias);
        
        if (keyBase64 != null) {
          appLogger.info('Migrating legacy persistent key to memory', context: 'EncryptionService');
          _masterKeyBase64 = keyBase64;
          // Hapus dari storage agar restart berikutnya WAJIB lewat PIN screen
          await _storage.delete(key: _keyAlias);
        }
      }

      if (keyBase64 != null) {
        _activateMasterKey(keyBase64);
        appLogger.info('Initialized (Session-only mode)', context: 'EncryptionService');
      } else {
        appLogger.warning('NOT initialized (Session key missing)', context: 'EncryptionService');
      }
    } catch (e, stack) {
      appLogger.error('Init error', context: 'EncryptionService', error: e, stackTrace: stack);
    }
  }

  /// Helper untuk mengaktifkan encrypter dari key string
  void _activateMasterKey(String keyBase64) {
    _masterKeyBase64 = keyBase64;
    final keyBytes = base64Decode(keyBase64);
    final key = encrypt.Key(keyBytes);
    
    _encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
  }

  /// Generate a brand new master key. 
  /// ONLY call this during brand new workshop creation.
  Future<void> generateNewMasterKey() async {
    final key = encrypt.Key.fromSecureRandom(32);
    final keyBase64 = base64Encode(key.bytes);
    
    // SEC-01 FIX: Simpan di memory saja, JANGAN tulis ke _storage.write
    _activateMasterKey(keyBase64);
    appLogger.info('New master key generated (Memory-only)', context: 'EncryptionService');
  }

  /// Hash PIN with SHA-256 + salt before any further processing.
  /// SEC-FIX: Reduces plaintext PIN exposure — the raw PIN is never passed
  /// directly into PBKDF2. Instead, a SHA-256 hash (with bengkelId as salt)
  /// is used as the PBKDF2 input.
  String hashPin(String pin, String bengkelId) {
    final saltedPin = '$bengkelId:$pin';
    final bytes = utf8.encode(saltedPin);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Derive a 256-bit key from a 6-digit PIN using PBKDF2-HMAC-SHA256.
  /// Standard: OWASP 2023 (100,000 iterations minimum).
  /// SEC-FIX: PIN is hashed with SHA-256 + salt before PBKDF2 derivation.
  Future<encrypt.Key> deriveKey(String pin, String salt) async {
    // Step 1: Hash PIN with SHA-256 + bengkelId salt
    final hashedPin = hashPin(pin, salt);

    // Step 2: PBKDF2 key derivation from hashed PIN
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final params = Pbkdf2Parameters(
      Uint8List.fromList(utf8.encode(salt)),
      pbkdf2Iterations,
      32,
    );
    pbkdf2.init(params);
    
    final keyBytes = pbkdf2.process(Uint8List.fromList(utf8.encode(hashedPin)));
    return encrypt.Key(keyBytes);
  }


  /// Save derived key securely (for Biometric Auto-Unlock)
  Future<void> saveDerivedKeyForBiometric(String pin, String bengkelId) async {
    final key = await deriveKey(pin, bengkelId);
    await _storage.write(
      key: 'biometric_derived_key_$bengkelId',
      value: key.base64,
    );
  }

  /// Get saved derived key after Biometric success
  Future<encrypt.Key?> getSavedDerivedKey(String bengkelId) async {
    final keyBase64 = await _storage.read(key: 'biometric_derived_key_$bengkelId');
    if (keyBase64 == null) return null;
    return encrypt.Key.fromBase64(keyBase64);
  }

  /// Clear saved derived key (Disable Biometric)
  Future<void> clearSavedDerivedKey(String bengkelId) async {
    await _storage.delete(key: 'biometric_derived_key_$bengkelId');
  }

  /// Lock the service by clearing the in-memory encrypter.
  /// This forces the app to re-authenticate via AuthGate -> UnlockScreen.
  void lock() {
    _encrypter = null;
    _masterKeyBase64 = null;
    appLogger.info('Locked', context: 'EncryptionService');
  }

  /// Clear specific session data (biometrics, derived keys) but KEEP Master Key.
  /// Used for standard logout to allow fast re-unlock (UX-11).
  Future<void> clearSessionDataOnly() async {
    final keys = await _storage.readAll();
    for (final key in keys.keys) {
      // Hapus data biometrik/session
      await _storage.delete(key: key);
    }
    // Hapus paksa in-memory key
    _encrypter = null;
    _masterKeyBase64 = null;
    appLogger.info('Session data cleared & Locked (Memory wiped)', context: 'EncryptionService');
  }

  /// Hapus semua key dari secure storage
  Future<void> clearSecureStorage() async {
    await _storage.deleteAll();
    _encrypter = null;
    _masterKeyBase64 = null;
    appLogger.info('Secure storage cleared', context: 'EncryptionService');
  }


  /// Encrypt string text using AES-GCM with a secure random IV and prefix.
  String encryptText(String plainText) {
    if (_encrypter == null || plainText.isEmpty) return plainText;
    
    // Prevent double encryption
    if (plainText.startsWith(encryptionPrefix)) return plainText;

    // Use Secure Random IV (12 bytes is standard for GCM)
    final iv = encrypt.IV.fromSecureRandom(12);

    final encrypted = _encrypter!.encrypt(plainText, iv: iv);

    // Store as prefix:IV:Ciphertext
    return '$encryptionPrefix${iv.base64}:${encrypted.base64}';
  }
  /// Encrypt string text using a provided key. Useful for secure backups (Audit K-1).
  String encryptTextWithKey(String plainText, encrypt.Key key) {
    if (plainText.isEmpty) return plainText;
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final iv = encrypt.IV.fromSecureRandom(12);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '$encryptionPrefix${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt string text using a provided key. Useful for restoring backups (Audit K-1).
  String decryptTextWithKey(String encryptedText, encrypt.Key key) {
    if (encryptedText.isEmpty) return encryptedText;
    if (!encryptedText.startsWith(encryptionPrefix)) return encryptedText;
    
    try {
      final body = encryptedText.substring(encryptionPrefix.length);
      final parts = body.split(':');
      if (parts.length != 2) return encryptedText;

      final iv = encrypt.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      
      return encrypter.decrypt64(ciphertext, iv: iv);
    } catch (_) {
      return '[Gagal Dekripsi]';
    }
  }

  /// Decrypt string text with structured result handling.
  DecryptionResult decryptText(String encryptedText) {
    if (_encrypter == null) return DecryptionResult.failed(status: DecryptionStatus.notInitialized);
    if (encryptedText.isEmpty) return DecryptionResult.empty();

    // Check for our prefix
    bool hasPrefix = encryptedText.startsWith(encryptionPrefix);
    String workingText = hasPrefix 
        ? encryptedText.substring(encryptionPrefix.length) 
        : encryptedText;

    if (!hasPrefix) {
      return DecryptionResult.unencrypted(encryptedText);
    }

    if (!workingText.contains(':')) {
       return DecryptionResult.failed(status: DecryptionStatus.invalidFormat);
    }

    try {
      final parts = workingText.split(':');
      if (parts.length != 2) return DecryptionResult.failed(status: DecryptionStatus.invalidFormat);

      final iv = encrypt.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];

      final decrypted = _encrypter!.decrypt64(ciphertext, iv: iv);
      return DecryptionResult.success(decrypted);
    } catch (e, stack) {
      appLogger.error('Decrypt error', context: 'EncryptionService', error: e, stackTrace: stack);
      return DecryptionResult.failed(status: DecryptionStatus.failed);
    }
  }

  /// Encrypt primary master key with a PIN using PBKDF2 and AES-GCM.
  Future<String?> wrapMasterKey(String pin, String bengkelId) async {
    // SEC-01: Prioritaskan memory key
    final masterKeyBase64 = _masterKeyBase64 ?? await _storage.read(key: _keyAlias);
    if (masterKeyBase64 == null) return null;

    final secondaryKey = await deriveKey(pin, bengkelId);
    // Use GCM for authenticated key wrapping
    final secondaryEncrypter = encrypt.Encrypter(
      encrypt.AES(secondaryKey, mode: encrypt.AESMode.gcm),
    );

    final iv = encrypt.IV.fromSecureRandom(12);
    final encrypted = secondaryEncrypter.encrypt(masterKeyBase64, iv: iv);

    // Format: prefix:base64(IV):base64(Ciphertext)
    return '$encryptionPrefix${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt primary master key using a PIN.
  /// Handles migration from legacy key derivation if needed.
  ///
  /// [onMigrationComplete] — callback dipanggil dengan wrapped key baru
  /// setelah migrasi legacy → PBKDF2 berhasil. Caller bertanggung jawab
  /// untuk push key ini ke Firestore (LGK-06).
  Future<bool> unwrapAndSaveMasterKey(
    String wrappedKey,
    String pin,
    String bengkelId, {
    Future<void> Function(String newWrappedKey)? onMigrationComplete,
  }) async {
    try {
      // 1. Try with new PBKDF2 derivation
      final secondaryKey = await deriveKey(pin, bengkelId);
      final success = await _unwrapWithKey(wrappedKey, secondaryKey);
      
      if (success) return true;

      return success;
    } catch (e, stack) {
      appLogger.error('Unwrap master key error', context: 'EncryptionService', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Decrypt primary master key using a saved derived key (Biometric)
  Future<bool> unwrapWithSavedKey(String wrappedKey, encrypt.Key key) async {
    return await _unwrapWithKey(wrappedKey, key);
  }

  Future<bool> _unwrapWithKey(
    String wrappedKey,
    encrypt.Key secondaryKey,
  ) async {
    try {
      // Handle optional prefix
      String body = wrappedKey.startsWith(encryptionPrefix)
          ? wrappedKey.substring(encryptionPrefix.length)
          : wrappedKey;

      final parts = body.split(':');
      if (parts.length != 2) return false;

      final iv = encrypt.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];

      // Use GCM mode to match wrapping
      final secondaryEncrypter = encrypt.Encrypter(
        encrypt.AES(secondaryKey, mode: encrypt.AESMode.gcm),
      );

      final masterKeyBase64 = secondaryEncrypter.decrypt64(ciphertext, iv: iv);
      
      // SEC-01 FIX: Tulis ke memori saja, JANGAN tulis ke _storage.write
      _activateMasterKey(masterKeyBase64);
      return true;
    } catch (e) {
      // Silently fail as this is used in fallback logic
      appLogger.debug('Unwrap with key failed (fallback)', context: 'EncryptionService');
      return false;
    }
  }
}

/// Structured result for decryption operations to prevent ciphertext leakage in UI.
enum DecryptionStatus { success, empty, unencrypted, wrongKey, corrupted, invalidFormat, failed, notInitialized }

class DecryptionResult {
  final String? data;
  final DecryptionStatus status;

  const DecryptionResult({this.data, required this.status});

  factory DecryptionResult.success(String data) => DecryptionResult(data: data, status: DecryptionStatus.success);
  factory DecryptionResult.empty() => const DecryptionResult(data: '', status: DecryptionStatus.empty);
  factory DecryptionResult.unencrypted(String data) => DecryptionResult(data: data, status: DecryptionStatus.unencrypted);
  factory DecryptionResult.failed({DecryptionStatus status = DecryptionStatus.failed}) => DecryptionResult(data: null, status: status);

  bool get isSuccess => status == DecryptionStatus.success || status == DecryptionStatus.empty || status == DecryptionStatus.unencrypted;
  bool get isFailure => !isSuccess;

  /// Returns a safe display string for the UI. NEVER returns ciphertext.
  String get displayValue {
    if (isSuccess) return data ?? '';
    switch (status) {
      case DecryptionStatus.wrongKey: return '[Data Terkunci - PIN Salah]';
      case DecryptionStatus.corrupted: return '[Data Corrupt]';
      case DecryptionStatus.notInitialized: return '[Menunggu Aktivasi...]';
      default: return '[Gagal Membaca Data]';
    }
  }
}

