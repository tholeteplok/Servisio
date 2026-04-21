import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/encryption_service.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeSecureStorage fakeStorage;
  late EncryptionService service;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    service = EncryptionService(secureStorage: fakeStorage);
  });

  group('EncryptionService Security Hardening Tests', () {
    test('generateNewMasterKey() should initialize service in memory only', () async {
      await service.generateNewMasterKey();
      expect(service.isInitialized, isTrue);
      
      // Should NOT be in secure storage yet
      expect(await fakeStorage.containsKey(key: 'servislog_master_key'), isFalse);
    });

    test('hashPin should ensure cross-bengkel isolation (Salt validation)', () {
      const pin = '123456';
      final h1 = service.hashPin(pin, 'bengkel-A');
      final h2 = service.hashPin(pin, 'bengkel-B');
      final h3 = service.hashPin(pin, 'bengkel-A');
      
      expect(h1, isNot(h2), reason: 'Same PIN for different bengkel must yield different hashes');
      expect(h1, equals(h3), reason: 'Hash must be deterministic for the same PIN and bengkelId');
    });

    test('decryptText should handle invalid formats gracefully', () async {
      await service.generateNewMasterKey();
      
      // 1. Invalid prefix
      final res1 = service.decryptText('wrong:prefix:data');
      expect(res1.status, DecryptionStatus.unencrypted);
      expect(res1.data, equals('wrong:prefix:data'));
      expect(res1.displayValue, equals('wrong:prefix:data'));

      // 2. Missing IV part
      final res2 = service.decryptText('${EncryptionService.encryptionPrefix}no_iv_delim');
      expect(res2.status, DecryptionStatus.invalidFormat);
      expect(res2.displayValue, contains('Gagal Membaca'));

      // 3. Empty string
      final res3 = service.decryptText('');
      expect(res3.status, DecryptionStatus.empty);
    });

    test('init() should migrate legacy persistent key to memory and delete it', () async {
      final legacyKeyBase64 = base64Encode(List.generate(32, (i) => i));
      await fakeStorage.write(key: 'servislog_master_key', value: legacyKeyBase64);
      
      await service.init();
      
      expect(service.isInitialized, isTrue);
      // Key should be deleted from storage after migration (Session-only security)
      expect(await fakeStorage.containsKey(key: 'servislog_master_key'), isFalse);
    });

    test('wrap and unwrap with WRONG PIN should fail', () async {
      await service.generateNewMasterKey();
      
      final wrapped = await service.wrapMasterKey('123456', 'b-1');
      expect(wrapped, isNotNull);
      
      service.lock();
      expect(service.isInitialized, isFalse);
      
      // Try unwrap with WRONG PIN
      final success = await service.unwrapAndSaveMasterKey(wrapped!, 'wrong_pin', 'b-1');
      expect(success, isFalse);
      expect(service.isInitialized, isFalse);
    });

    test('clearSessionDataOnly should wipe memory keys', () async {
      await service.generateNewMasterKey();
      expect(service.isInitialized, isTrue);
      
      await service.clearSessionDataOnly();
      expect(service.isInitialized, isFalse);
    });

    test('decryptTextWithKey should return error placeholder on failure', () async {
      final key = await service.deriveKey('123456', 'salt');
      final wrongKey = await service.deriveKey('wrong', 'salt');
      
      final encrypted = service.encryptTextWithKey('secret', key);
      final result = service.decryptTextWithKey(encrypted, wrongKey);
      
      expect(result, equals('[Gagal Dekripsi]'));
    });
  });
}
