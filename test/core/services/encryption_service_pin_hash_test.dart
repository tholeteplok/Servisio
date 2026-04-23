import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/encryption_service.dart';

void main() {
  group('EncryptionService - PIN Hashing (SEC-FIX)', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    group('hashPin', () {
      test('should hash PIN with SHA-256 using bengkelId as salt', () {
        const pin = '123456';
        const bengkelId = 'bengkel-abc-123';

        final hashedPin = encryptionService.hashPin(pin, bengkelId);

        expect(hashedPin, isNotEmpty);
        expect(hashedPin, isNot(equals(pin))); // Hash should be different from original PIN
        expect(hashedPin.length, equals(64)); // SHA-256 produces 64 hex characters
      });

      test('should produce different hashes for different PINs', () {
        const bengkelId = 'bengkel-abc-123';

        final hash1 = encryptionService.hashPin('123456', bengkelId);
        final hash2 = encryptionService.hashPin('654321', bengkelId);

        expect(hash1, isNot(equals(hash2)));
      });

      test('should produce different hashes for same PIN with different bengkelId', () {
        const pin = '123456';

        final hash1 = encryptionService.hashPin(pin, 'bengkel-1');
        final hash2 = encryptionService.hashPin(pin, 'bengkel-2');

        expect(hash1, isNot(equals(hash2)));
      });

      test('should produce consistent hashes for same PIN and bengkelId', () {
        const pin = '123456';
        const bengkelId = 'bengkel-abc-123';

        final hash1 = encryptionService.hashPin(pin, bengkelId);
        final hash2 = encryptionService.hashPin(pin, bengkelId);

        expect(hash1, equals(hash2));
      });

      test('should handle empty PIN', () {
        const pin = '';
        const bengkelId = 'bengkel-abc-123';

        final hashedPin = encryptionService.hashPin(pin, bengkelId);

        expect(hashedPin, isNotEmpty);
        expect(hashedPin.length, equals(64));
      });

      test('should handle empty bengkelId', () {
        const pin = '123456';
        const bengkelId = '';

        final hashedPin = encryptionService.hashPin(pin, bengkelId);

        expect(hashedPin, isNotEmpty);
        expect(hashedPin.length, equals(64));
      });

      test('should handle special characters in bengkelId', () {
        const pin = '123456';
        const bengkelId = 'bengkel-123_test.456';

        final hashedPin = encryptionService.hashPin(pin, bengkelId);

        expect(hashedPin, isNotEmpty);
        expect(hashedPin.length, equals(64));
      });
    });

    group('deriveKey with PIN Hashing', () {
      test('should derive key using hashed PIN', () async {
        const pin = '123456';
        const bengkelId = 'bengkel-abc-123';

        // This will hash the PIN first, then use PBKDF2
        final key = await encryptionService.deriveKey(pin, bengkelId);

        expect(key, isNotNull);
        expect(key.bytes.length, equals(32)); // 256-bit key
      });

      test('should produce different keys for different PINs', () async {
        const bengkelId = 'bengkel-abc-123';

        final key1 = await encryptionService.deriveKey('123456', bengkelId);
        final key2 = await encryptionService.deriveKey('654321', bengkelId);

        expect(key1.bytes, isNot(equals(key2.bytes)));
      });

      test('should produce different keys for same PIN with different bengkelId', () async {
        const pin = '123456';

        final key1 = await encryptionService.deriveKey(pin, 'bengkel-1');
        final key2 = await encryptionService.deriveKey(pin, 'bengkel-2');

        expect(key1.bytes, isNot(equals(key2.bytes)));
      });

      test('should produce consistent keys for same PIN and bengkelId', () async {
        const pin = '123456';
        const bengkelId = 'bengkel-abc-123';

        final key1 = await encryptionService.deriveKey(pin, bengkelId);
        final key2 = await encryptionService.deriveKey(pin, bengkelId);

        expect(key1.bytes, equals(key2.bytes));
      });
    });

    group('Security Properties', () {
      test('hash should not reveal original PIN length', () {
        const bengkelId = 'bengkel-abc-123';

        final hash4 = encryptionService.hashPin('1234', bengkelId);
        final hash6 = encryptionService.hashPin('123456', bengkelId);
        final hash8 = encryptionService.hashPin('12345678', bengkelId);

        // All hashes should have same length (64 characters for SHA-256 hex)
        expect(hash4.length, equals(hash6.length));
        expect(hash6.length, equals(hash8.length));
      });

      test('hash should be deterministic', () {
        const pin = '123456';
        const bengkelId = 'test-bengkel';

        final hashes = List.generate(10, (_) => encryptionService.hashPin(pin, bengkelId));

        // All 10 hashes should be identical
        for (final hash in hashes) {
          expect(hash, equals(hashes.first));
        }
      });

      test('bengkelId acts as salt preventing rainbow table attacks', () {
        const pin = '123456';

        final hash1 = encryptionService.hashPin(pin, 'bengkel-satu');
        final hash2 = encryptionService.hashPin(pin, 'bengkel-dua');
        final hash3 = encryptionService.hashPin(pin, 'bengkel-tiga');

        // Different salts should produce completely different hashes
        expect(hash1, isNot(equals(hash2)));
        expect(hash2, isNot(equals(hash3)));
        expect(hash1, isNot(equals(hash3)));
      });
    });
  });
}
