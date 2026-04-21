import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:servisio_core/core/services/biometric_service.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BiometricService service;
  late FakeLocalAuthentication localAuth;
  late FakeFlutterSecureStorage secureStorage;

  setUp(() {
    localAuth = FakeLocalAuthentication();
    secureStorage = FakeFlutterSecureStorage();
    service = BiometricService(
      localAuth: localAuth,
      secureStorage: secureStorage,
    );
  });

  group('BiometricService Tests', () {
    test('isAvailable returns true if hardware supports it', () async {
      localAuth.canCheck = true;
      final available = await service.isAvailable();
      expect(available, isTrue);
    });

    test('authenticate calls verify with correct params', () async {
      localAuth.canCheck = true;
      localAuth.authResult = true;

      final result = await service.authenticate(reason: 'Test Login');
      expect(result, isTrue);
      expect(localAuth.lastReason, equals('Test Login'));
      expect(localAuth.lastOptions?.biometricOnly, isTrue);
    });

    test('verifyWithRetry handles lockout and disable policy', () async {
      localAuth.canCheck = true;
      localAuth.authResult = false;

      // 1. First 3 failures -> Lockout
      final res1 = await service.verifyWithRetry(reason: 'Fail 1', maxRetry: 3);
      expect(res1.success, isFalse);
      expect(res1.retryCount, 3);
      expect(res1.error, contains('Akses terkunci selama 5 menit'));

      // 2. Simulate lockout expiry
      await secureStorage.delete(key: 'biometric_lockout_until');

      // 3. Failure #4 -> Lockout again (triggers at >= 3)
      final res2 = await service.verifyWithRetry(reason: 'Fail 2', maxRetry: 1);
      expect(res2.success, isFalse);
      expect(res2.retryCount, 1);
      expect(res2.error, contains('Akses terkunci selama 5 menit'));

      // 4. Simulate lockout expiry again
      await secureStorage.delete(key: 'biometric_lockout_until');

      // 5. Failure #5 -> Disabled
      final res3 = await service.verifyWithRetry(reason: 'Fail 3', maxRetry: 1);
      expect(res3.success, isFalse);
      expect(res3.retryCount, 1);
      expect(res3.error, contains('dinonaktifkan (5x gagal)'));

      // 6. Try again when disabled
      final res4 = await service.verifyWithRetry(reason: 'Disabled');
      expect(res4.success, isFalse);
      expect(res4.error, contains('dinonaktifkan sementara'));
      
      // 7. Reset works
      await service.resetFailures();
      localAuth.authResult = true;
      final res5 = await service.verifyWithRetry(reason: 'Reset');
      expect(res5.success, isTrue);
    });

    test('PIN storage ensures cross-bengkel isolation', () async {
      const pin = '1234';
      await service.savePin(pin, 'bengkel_A');
      
      // Success for same bengkel
      expect(await service.verifyPin(pin, 'bengkel_A'), isTrue);
      
      // Fail for different bengkel (due to salt mismatch)
      expect(await service.verifyPin(pin, 'bengkel_B'), isFalse);
    });

    test('PlatformException handles fatal hardware errors correctly', () async {
      // Create a specific fake that throws
      final throwingAuth = _ThrowingFakeLocalAuth();
      final experimentalService = BiometricService(
        localAuth: throwingAuth,
        secureStorage: secureStorage,
      );

      // 1. LockedOut from system hardware
      throwingAuth.code = 'LockedOut';
      final res1 = await experimentalService.verifyWithRetry(reason: 'HW Lockout');
      expect(res1.success, isFalse);
      expect(res1.error, equals('LockedOut'));
      expect(res1.retryCount, 0); // Should stop immediately

      // 2. NotAvailable
      throwingAuth.code = 'NotAvailable';
      final res2 = await experimentalService.verifyWithRetry(reason: 'No HW');
      expect(res2.success, isFalse);
      expect(res2.retryCount, 0);
    });
  });
}

class _ThrowingFakeLocalAuth extends FakeLocalAuthentication {
  String code = 'Error';
  
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const <dynamic>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    throw PlatformException(code: code, message: code);
  }
}
