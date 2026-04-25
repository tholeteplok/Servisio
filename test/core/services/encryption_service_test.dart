import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/encryption_service.dart';
import '../../mocks/manual_mocks.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  late EncryptionService encryptionService;
  late FakeFlutterSecureStorage mockStorage;

  setUp(() {
    mockStorage = FakeFlutterSecureStorage();
    encryptionService = EncryptionService(secureStorage: mockStorage);
  });

  group('EncryptionService - PIN Hashing & Key Derivation', () {
    test('hashPin produces consistent hash for same input', () {
      const pin = '123456';
      const salt = 'bengkel_123';
      
      final hash1 = encryptionService.hashPin(pin, salt);
      final hash2 = encryptionService.hashPin(pin, salt);
      
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex length
    });

    test('hashPin produces different hash for different salt', () {
      const pin = '123456';
      
      final hash1 = encryptionService.hashPin(pin, 'salt1');
      final hash2 = encryptionService.hashPin(pin, 'salt2');
      
      expect(hash1, isNot(equals(hash2)));
    });

    test('deriveKey produces valid 32-byte key', () async {
      const pin = '123456';
      const salt = 'bengkel_123';
      
      final key = await encryptionService.deriveKey(pin, salt);
      
      expect(key.bytes.length, equals(32)); // 256-bit
    });
  });

  group('EncryptionService - Text Encryption/Decryption', () {
    test('Round trip encryption/decryption with master key', () async {
      // 1. Generate and activate key
      await encryptionService.generateNewMasterKey();
      
      const originalText = 'Rahasia Pelanggan';
      
      // 2. Encrypt
      final encrypted = encryptionService.encryptText(originalText);
      expect(encrypted, startsWith(EncryptionService.encryptionPrefix));
      expect(encrypted, isNot(equals(originalText)));
      
      // 3. Decrypt
      final result = encryptionService.decryptText(encrypted);
      expect(result.isSuccess, true);
      expect(result.data, equals(originalText));
    });

    test('decryptText handles unencrypted text gracefully', () async {
      await encryptionService.generateNewMasterKey();
      const plainText = 'Bukan Rahasia';
      
      final result = encryptionService.decryptText(plainText);
      
      expect(result.status, equals(DecryptionStatus.unencrypted));
      expect(result.data, equals(plainText));
    });

    test('decryptText returns failed status when not initialized', () {
      const encrypted = 'enc:v1:iv:cipher';
      
      final result = encryptionService.decryptText(encrypted);
      
      expect(result.status, equals(DecryptionStatus.notInitialized));
      expect(result.isFailure, true);
    });

    test('Round trip with specific key (Backup/Restore scenario)', () async {
      final key = encrypt.Key.fromSecureRandom(32);
      const text = 'Data Backup';
      
      final encrypted = encryptionService.encryptTextWithKey(text, key);
      final decrypted = encryptionService.decryptTextWithKey(encrypted, key);
      
      expect(decrypted, equals(text));
    });
  });

  group('EncryptionService - Key Wrapping', () {
    test('wrapMasterKey and unwrapAndSaveMasterKey cycle', () async {
      const pin = '123456';
      const bengkelId = 'bengkel_001';
      
      // 1. Setup master key
      await encryptionService.generateNewMasterKey();
      
      // 2. Wrap
      final wrappedKey = await encryptionService.wrapMasterKey(pin, bengkelId);
      expect(wrappedKey, isNotNull);
      expect(wrappedKey, startsWith(EncryptionService.encryptionPrefix));
      
      // 3. Lock/Reset service memory
      encryptionService.lock();
      expect(encryptionService.isInitialized, false);
      
      // 4. Unwrap
      final success = await encryptionService.unwrapAndSaveMasterKey(
        wrappedKey!,
        pin,
        bengkelId,
      );
      
      expect(success, true);
      expect(encryptionService.isInitialized, true);
    });

    test('unwrapAndSaveMasterKey fails with wrong PIN', () async {
      const pin = '123456';
      const wrongPin = '654321';
      const bengkelId = 'bengkel_001';
      
      await encryptionService.generateNewMasterKey();
      final wrappedKey = await encryptionService.wrapMasterKey(pin, bengkelId);
      
      encryptionService.lock();
      
      final success = await encryptionService.unwrapAndSaveMasterKey(
        wrappedKey!,
        wrongPin,
        bengkelId,
      );
      
      expect(success, false);
      expect(encryptionService.isInitialized, false);
    });
  });

  group('EncryptionService - Lifecycle & Migration', () {
    test('init migrates legacy persistent key to memory', () async {
      // 1. Simulate legacy key in storage
      final legacyKey = base64Encode(encrypt.Key.fromSecureRandom(32).bytes);
      await mockStorage.write(key: 'servisio_master_key', value: legacyKey);
      
      // 2. Init
      await encryptionService.init();
      
      // 3. Verify
      expect(encryptionService.isInitialized, true);
      
      // 4. Verify storage is cleared (SEC-01)
      final storedKey = await mockStorage.read(key: 'servisio_master_key');
      expect(storedKey, isNull);
    });

    test('lock clears memory correctly', () async {
      await encryptionService.generateNewMasterKey();
      expect(encryptionService.isInitialized, true);
      
      encryptionService.lock();
      
      expect(encryptionService.isInitialized, false);
      // Decrypt should fail now
      final result = encryptionService.decryptText('enc:v1:any:data');
      expect(result.status, equals(DecryptionStatus.notInitialized));
    });

    test('clearSessionDataOnly wipes storage and memory', () async {
      await encryptionService.generateNewMasterKey();
      await mockStorage.write(key: 'other_data', value: 'secret');
      
      await encryptionService.clearSessionDataOnly();
      
      expect(encryptionService.isInitialized, false);
      expect(await mockStorage.readAll(), isEmpty);
    });
  });
}
