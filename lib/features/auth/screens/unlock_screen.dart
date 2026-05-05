import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_logger.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  final String bengkelId;
  final VoidCallback onUnlocked;

  const UnlockScreen({
    super.key,
    required this.bengkelId,
    required this.onUnlocked,
  });

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pinController = TextEditingController();
  bool _isUnwrapping = false;
  bool _hasBiometric = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    appLogger.info('UnlockScreen initState', context: 'UnlockScreen');
    _checkBiometric();
  }

  @override
  void dispose() {
    appLogger.info('UnlockScreen dispose', context: 'UnlockScreen');
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final encryption = ref.read(encryptionServiceProvider);
    final biometric = ref.read(biometricServiceProvider);
    final savedKey = await encryption.getSavedDerivedKey(widget.bengkelId);
    if (savedKey != null) {
      final available = await biometric.isAvailable();
      if (available) {
        setState(() => _hasBiometric = true);
        _tryBiometricUnlock();
      }
    }
  }


  Future<void> _handleSuccessfulUnlock() async {
    appLogger.info('=== _handleSuccessfulUnlock STARTED ===', context: 'UnlockScreen');
    
    final sessionManager = ref.read(sessionManagerProvider);
    await sessionManager.forceRefreshAuthTimestamp();

    // Pastikan workshop aktif ter-set di SessionManager.
    // Sangat krusial untuk Fresh Install di mana SessionManager masih kosong.
    await sessionManager.ensureWorkshopResolved();
    
    appLogger.info(
      'Workshop resolved: id=${sessionManager.activeWorkshopId}, ownerId=${sessionManager.activeWorkshopOwnerId}',
      context: 'UnlockScreen',
    );

    appLogger.info('Unlock successful, calling onUnlocked', context: 'UnlockScreen');
    widget.onUnlocked();
  }



  Future<void> _tryBiometricUnlock() async {
    final encryption = ref.read(encryptionServiceProvider);
    final biometric = ref.read(biometricServiceProvider);
    final bengkel = ref.read(bengkelServiceProvider);

    final success = await biometric.authenticate(
      reason: AppStrings.auth.reasonUnlock,
    );

    if (success) {
      setState(() => _isUnwrapping = true);
      try {
        final savedKey = await encryption.getSavedDerivedKey(widget.bengkelId);
        final wrappedKey = await bengkel.getWrappedMasterKey(widget.bengkelId);

        if (savedKey != null && wrappedKey != null) {
          final ok = await encryption.unwrapWithSavedKey(wrappedKey, savedKey);
          if (ok) {
            // SEC-02: Reset failures on success
            await biometric.resetFailures();
            
            await encryption.init(); // LGK-07: Ensure in-memory encrypter is ready
            
            // Call handleSuccessfulUnlock and wait for it to complete
            await _handleSuccessfulUnlock();
            return;
          }
        }
        if (mounted) setState(() => _errorText = AppStrings.error.keyRecoveryFailed);
      } catch (e) {
        appLogger.error('Biometric unlock error', context: 'UnlockScreen', error: e);
        if (mounted) setState(() => _errorText = AppStrings.error.specific(e.toString()));
      } finally {
        if (mounted) setState(() => _isUnwrapping = false);
      }
    }
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text;
    if (pin.length != 6) return;

    final encryption = ref.read(encryptionServiceProvider);
    final biometric = ref.read(biometricServiceProvider);
    final bengkel = ref.read(bengkelServiceProvider);

    setState(() {
      _isUnwrapping = true;
      _errorText = '';
    });

    try {
      final wrappedKey = await bengkel.getWrappedMasterKey(widget.bengkelId);

      if (wrappedKey == null) {
        throw Exception(AppStrings.auth.bengkelNoMasterKey);
      }

      final success = await encryption.unwrapAndSaveMasterKey(
        wrappedKey,
        pin,
        widget.bengkelId,
        onMigrationComplete: (newWrappedKey) async {
          try {
            final uid = ref.read(authServiceProvider).currentUser?.uid ?? 'unknown';
            await bengkel.updateMasterKey(
              bengkelId: widget.bengkelId,
              wrappedKey: newWrappedKey,
              userId: uid,
            );
          } catch (e) {
            appLogger.warning('Firestore migration push gagal', context: 'UnlockScreen', error: e);
          }
        },
      );

      if (success) {
        // SEC-02: Reset failures on success
        await biometric.resetFailures();

        // Auto-link biometric for next time if enabled and supported
        final settings = ref.read(settingsProvider);
        if (settings.isBiometricEnabled) {
          final isSupported = await biometric.isAvailable();
          if (isSupported) {
            // SEC-03: Check if key exists first to prevent unnecessary overwrites
            final existingKey = await encryption.getSavedDerivedKey(widget.bengkelId);
            if (existingKey == null) {
              await encryption.saveDerivedKeyForBiometric(pin, widget.bengkelId);
              appLogger.info('Biometric auto-linked for workshop', context: 'UnlockScreen');
            }
          }
        }

        await encryption.init(); // LGK-07: Ensure in-memory encrypter is ready
        await _handleSuccessfulUnlock();
      } else {
        if (mounted) setState(() => _errorText = AppStrings.auth.pinIncorrect);
        _pinController.clear();
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = AppStrings.error.specific(e.toString().replaceAll('Exception: ', '')));
    } finally {
      if (mounted) setState(() => _isUnwrapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0D0B14), const Color(0xFF1A1528)]
                : [const Color(0xFFF3EEFF), const Color(0xFFE8DEFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsOutline.lock,
                    size: 48,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.auth.workshopLocked,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1528),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.auth.enterPinDesc,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),

                // PIN Input (JetBrains Mono for numbers)
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 32,
                    letterSpacing: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1528),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    if (val.length == 6) _unlockWithPin();
                  },
                ),

                if (_errorText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorText,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                if (_isUnwrapping)
                  const CircularProgressIndicator(color: Color(0xFF7C3AED))
                else if (_hasBiometric)
                  TextButton.icon(
                    onPressed: _tryBiometricUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(AppStrings.common.useBiometric),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                    ),
                  ),
                
                const Spacer(),
                
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: Text(
                    AppStrings.common.logout,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

