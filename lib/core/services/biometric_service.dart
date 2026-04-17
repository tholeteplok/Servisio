// 🛡️ ServisLog+ Hybrid Security Policy — Biometric Service Wrapper
// Future-proof abstraction layer untuk biometric authentication
// Support: 3x retry, PIN fallback, emergency mode

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 📊 Biometric Verification Result
class BiometricResult {
  final bool success;
  final int retryCount;
  final String? error;
  
  BiometricResult({
    required this.success,
    required this.retryCount,
    this.error,
  });
  
  bool get hasRetries => retryCount < 3;
}

// 🛠️ Biometric Service Class
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _pinKey = 'biometric_pin';
  static const _failureCountKey = 'biometric_fail_count';
  static const _lockoutKey = 'biometric_lockout_until';
  static const _disabledKey = 'biometric_temp_disabled';
  
  // ─────────────────────────────────────────────────────────────
  // AVAILABILITY CHECK
  // ─────────────────────────────────────────────────────────────
  
  /// Check if biometric is available on device
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('❌ Biometric availability check failed: $e');
      return false;
    }
  }
  
  /// Check if device has biometric hardware
  Future<bool> canCheckBiometricHardware() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }
  
  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  /// Check if biometric is enrolled
  Future<bool> isBiometricEnrolled() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }
  
  // ─────────────────────────────────────────────────────────────
  // VERIFICATION (MAIN METHODS)
  // ─────────────────────────────────────────────────────────────
  
  /// Simple verify (for critical actions)
  Future<bool> verify({
    required String reason,
    bool biometricOnly = true,
  }) async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        debugPrint('⚠️ Biometric not available');
        return false;
      }
      
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('❌ Biometric verification error: $e');
      return false;
    }
  }
  
  /// Verify with retry (for emergency mode) — 3x retry
  /// ✅ ENHANCED: Integrated with Anti-Brute Force Policy
  Future<BiometricResult> verifyWithRetry({
    required String reason,
    int maxRetry = 3,
  }) async {
    // 1. Check Global Lockout
    final lockoutStr = await _secureStorage.read(key: _lockoutKey);
    if (lockoutStr != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutStr));
      if (DateTime.now().isBefore(until)) {
        final diff = until.difference(DateTime.now()).inMinutes + 1;
        return BiometricResult(
          success: false,
          retryCount: 0,
          error: 'Terlalu banyak percobaan. Sila tunggu $diff menit lagi.',
        );
      } else {
        await _secureStorage.delete(key: _lockoutKey);
      }
    }

    // 2. Check if disabled (5th failure)
    final isDisabled = await _secureStorage.read(key: _disabledKey) == 'true';
    if (isDisabled) {
      return BiometricResult(
        success: false,
        retryCount: 0,
        error: 'Biometrik dinonaktifkan sementara. Gunakan PIN Master.',
      );
    }

    int retry = 0;
    String? lastError;

    while (retry < maxRetry) {
      try {
        final canCheck = await canCheckBiometrics();
        if (!canCheck) {
          return BiometricResult(
            success: false,
            retryCount: retry,
            error: 'Biometric tidak tersedia',
          );
        }

        final verified = await _localAuth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );

        if (verified) {
          debugPrint('✅ Biometric verified (retry: $retry)');
          await resetFailures(); // Success resets all counters
          return BiometricResult(
            success: true,
            retryCount: retry,
          );
        }

        lastError = 'Verifikasi gagal';
      } on PlatformException catch (e) {
        lastError = e.message ?? e.code;
        debugPrint('❌ Biometric PlatformException (attempt ${retry + 1}): ${e.code}');
        
        // 🛑 Stop retrying if user cancelled or hardware isn't available
        if (e.code == 'NotAvailable' || 
            e.code == 'NotEnrolled' || 
            e.code == 'LockedOut' || 
            e.code == 'PermanentlyLockedOut') {
          return BiometricResult(
            success: false,
            retryCount: retry,
            error: lastError,
          );
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('⚠️ Biometric unexpected error (attempt ${retry + 1}): $e');
      }

      // ─────────────────────────────────────────────────────────────
      // ANTI-BRUTE FORCE LOGIC (Triggered on any failure)
      // ─────────────────────────────────────────────────────────────
      retry++;
      final currentTotalFails = await _incrementFailure();

      if (currentTotalFails >= 5) {
        await _secureStorage.write(key: _disabledKey, value: 'true');
        return BiometricResult(
          success: false,
          retryCount: retry,
          error: 'Biometrik dinonaktifkan (5x gagal). Sila gunakan PIN.',
        );
      }

      if (currentTotalFails >= 3) {
        final until = DateTime.now().add(const Duration(minutes: 5));
        await _secureStorage.write(
          key: _lockoutKey,
          value: until.millisecondsSinceEpoch.toString(),
        );
        return BiometricResult(
          success: false,
          retryCount: retry,
          error: '3x Gagal. Akses terkunci selama 5 menit.',
        );
      }

      // Delay between retries
      if (retry < maxRetry) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint('❌ Biometric max retry reached ($maxRetry)');
    return BiometricResult(
      success: false,
      retryCount: retry,
      error: lastError,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FAILURE TRACKING
  // ─────────────────────────────────────────────────────────────

  Future<int> _incrementFailure() async {
    final countStr = await _secureStorage.read(key: _failureCountKey) ?? '0';
    final count = int.parse(countStr) + 1;
    await _secureStorage.write(key: _failureCountKey, value: count.toString());
    debugPrint('🛑 Biometric failure count incremented: $count');
    return count;
  }

  Future<void> resetFailures() async {
    await _secureStorage.delete(key: _failureCountKey);
    await _secureStorage.delete(key: _lockoutKey);
    await _secureStorage.delete(key: _disabledKey);
    debugPrint('🧹 Biometric failure counters reset');
  }
  
  // ─────────────────────────────────────────────────────────────
  // PIN STORAGE
  // ─────────────────────────────────────────────────────────────
  
  /// Save PIN to secure storage (called after biometric enrollment)
  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
    debugPrint('🔐 Biometric PIN saved');
  }

  /// Clear stored PIN (called when disabling biometric)
  Future<void> clearPin() async {
    await _secureStorage.delete(key: _pinKey);
    debugPrint('🗑️ Biometric PIN cleared');
  }
  
  /// Verify PIN against the stored PIN
  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: _pinKey);
    return stored != null && stored == pin;
  }
  
  /// Check if PIN is set
  Future<bool> isPinSet() async {
    final stored = await _secureStorage.read(key: _pinKey);
    return stored != null;
  }

  // ─────────────────────────────────────────────────────────────
  // COMPATIBILITY ALIASES
  // (used by screens that predate the v2 API rename)
  // ─────────────────────────────────────────────────────────────

  /// Alias for [canCheckBiometrics] — checks hardware + enrolled status
  Future<bool> isAvailable() => canCheckBiometrics();

  /// Alias for [verify] with a default reason string
  Future<bool> authenticate({String reason = 'Verifikasi identitas Anda'}) =>
      verify(reason: reason);
  
  // ─────────────────────────────────────────────────────────────
  // EMERGENCY MODE HELPER
  // ─────────────────────────────────────────────────────────────
  
  /// Emergency verification: 3x biometric → return result for PIN fallback
  Future<BiometricResult> emergencyVerify() async {
    return await verifyWithRetry(
      reason: 'Verifikasi Emergency Override',
      maxRetry: 3,
    );
  }
}

// 🔄 Riverpod Providers
final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(biometricServiceProvider);
  return await service.canCheckBiometrics();
});

final biometricTypesProvider = FutureProvider<List<BiometricType>>((ref) async {
  final service = ref.read(biometricServiceProvider);
  return await service.getAvailableBiometrics();
});

