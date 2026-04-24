import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/utils/app_logger.dart';

class CreateBengkelScreen extends ConsumerStatefulWidget {
  const CreateBengkelScreen({super.key});

  @override
  ConsumerState<CreateBengkelScreen> createState() =>
      _CreateBengkelScreenState();
}

class _CreateBengkelScreenState extends ConsumerState<CreateBengkelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bengkelIdController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isChecking = false;
  bool? _isAvailable;
  bool _isClaiming = false;
  bool _obscurePin = true;
  bool _biometricEnabled = false;
  bool _canCheckBiometric = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await ref.read(biometricServiceProvider).isAvailable();
    if (mounted) setState(() => _canCheckBiometric = available);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _bengkelIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final name = _nameController.text.trim();
    final bengkelService = ref.read(bengkelServiceProvider);
    if (name.length >= 3) {
      // Auto-generate preview ID
      final previewId = bengkelService.generateBengkelId(name);
      _bengkelIdController.text = previewId;

      // Reset state before checking
      setState(() {
        _isAvailable = null;
        _isChecking = true;
      });

      // Debounce availability check
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 700), () {
        _checkAvailability(previewId);
      });
    } else {
      setState(() {
        _isAvailable = null;
        _bengkelIdController.text = '';
      });
    }
  }

  Future<void> _checkAvailability(String bengkelId) async {
    if (!mounted) return;
    setState(() => _isChecking = true);
    
    try {
      final bengkelService = ref.read(bengkelServiceProvider);
      final available = await bengkelService.isBengkelIdAvailable(bengkelId);
      if (mounted) {
        setState(() {
          _isAvailable = available;
          _isChecking = false;
        });
      }
    } catch (e) {
      appLogger.error('Check Availability Error', context: 'CreateBengkelScreen', error: e);
      if (mounted) {
        setState(() {
          _isAvailable = null;
          _isChecking = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.error.failedToCheckId}: ${e.toString().contains('permission') ? 'Masalah perizinan' : 'Koneksi bermasalah'}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _regenerateId() {
    final name = _nameController.text.trim();
    if (name.length >= 3) {
      final bengkelService = ref.read(bengkelServiceProvider);
      final newId = bengkelService.generateBengkelId(name);
      _bengkelIdController.text = newId;
      _checkAvailability(newId);
    }
  }

  Future<void> _claimBengkel() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Safety check: ensure ID is still available before claiming
    if (_isAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.auth.idUnavailable),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isClaiming = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Sesi tidak valid. Silakan login ulang.');

      final encryption = ref.read(encryptionServiceProvider);
      final bengkelService = ref.read(bengkelServiceProvider);
      final biometric = ref.read(biometricServiceProvider);

      final bengkelId = _bengkelIdController.text.trim();
      final bengkelName = _nameController.text.trim();
      final pin = _pinController.text.trim();

      // 1. Setup master key di memory (session-only)
      await encryption.generateNewMasterKey();
      
      // 2. Claim ID di Firestore & Register Owner
      await bengkelService.claimBengkelId(
        bengkelId: bengkelId,
        ownerUid: user.uid,
        bengkelName: bengkelName,
        pin: pin,
      );

      // 3. Setup Biometric if enabled
      if (_biometricEnabled) {
        final authOk = await biometric.authenticate(
          reason: 'Verifikasi identitas untuk mengaktifkan akses cepat',
        );

        if (authOk) {
          await encryption.saveDerivedKeyForBiometric(pin, bengkelId);
          await biometric.savePin(pin, bengkelId);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.error.biometricRequired),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // Refresh auth state to pick up new profile
      // Memberi waktu untuk Cloud Function meng-assign custom claims 'owner'
      await Future.delayed(const Duration(seconds: 3));
      await user.getIdTokenResult(true); // Force refresh token dari server
      
      if (mounted) {
        ref.invalidate(authStateProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.success.bengkelCreated),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate will happen automatically via auth state listener
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.auth.createBengkelTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Bengkel
                Text(
                  AppStrings.auth.workshopNameLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: AppStrings.auth.workshopNameHint,
                    prefixIcon: Icon(
                      SolarIconsOutline.shop,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1A1528),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return AppStrings.error.minChars(3);
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Bengkel ID
                Row(
                  children: [
                    Text(
                      AppStrings.auth.workshopIdLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _regenerateId,
                      icon: const Icon(
                        SolarIconsOutline.refresh,
                        size: 16,
                        color: AppColors.precisionViolet,
                      ),
                      label: Text(
                        'Generate Ulang',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.precisionViolet,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bengkelIdController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: AppStrings.auth.workshopIdHint,
                    prefixIcon: Icon(
                      SolarIconsOutline.key,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    suffixIcon: _buildAvailabilityIndicator(),
                    // Inline helper/error text
                    helperText: _isAvailable == true ? AppStrings.auth.idAvailable : null,
                    helperStyle: GoogleFonts.inter(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                    errorText: _isAvailable == false ? AppStrings.auth.idUnavailable : null,
                    errorStyle: GoogleFonts.inter(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1528),
                  ),
                ),


                const SizedBox(height: 24),

                // Workshop PIN
                Text(
                  '${AppStrings.auth.enterPin} (6-angka)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pinController,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'PIN 6 digit',
                    prefixIcon: Icon(
                      SolarIconsOutline.lock,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    counterText: '',
                    // Inline error feedback
                    errorText: _pinController.text.isNotEmpty && _pinController.text.length < 6 
                        ? AppStrings.error.pinTooShort 
                        : null,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                      icon: Icon(
                        _obscurePin
                            ? SolarIconsOutline.eyeClosed
                            : SolarIconsOutline.eye,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1528),
                  ),
                  onChanged: (val) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.length != 6 || int.tryParse(value) == null) {
                      return AppStrings.error.pinInvalid;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Biometric Toggle
                if (_canCheckBiometric)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      value: _biometricEnabled,
                      onChanged: (val) => setState(() => _biometricEnabled = val),
                      title: Text(
                        AppStrings.common.useBiometric,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF1A1528),
                        ),
                      ),
                      subtitle: Text(
                        'Buka akses dengan Fingerprint/FaceID',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      secondary: Icon(
                        Icons.fingerprint,
                        color: _biometricEnabled ? AppColors.precisionViolet : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      activeThumbColor: AppColors.precisionViolet,
                      activeTrackColor: AppColors.precisionViolet.withValues(alpha: 0.2),
                    ),
                  ),

                const SizedBox(height: 12),

                // Info Password
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        SolarIconsOutline.shieldWarning,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PENTING: ${AppStrings.auth.setPinDesc} PIN ini digunakan untuk login di perangkat lain.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        SolarIconsOutline.infoCircle,
                        color: AppColors.precisionViolet,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ID Bengkel digunakan staff untuk bergabung. Bagikan ID ini ke tim Anda.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.precisionViolet.withValues(alpha: 0.8)
                                : AppColors.precisionViolet,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isAvailable == true && !_isClaiming)
                        ? _claimBengkel
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.precisionViolet,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.precisionViolet.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: _isClaiming
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            AppStrings.auth.registerNow,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityIndicator() {
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.precisionViolet,
          ),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: AppColors.success);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel, color: AppColors.error);
    }
    
    // Fallback/Error state indicator
    if (_isAvailable == null && !_isChecking && _nameController.text.length >= 3) {
      return Tooltip(
        message: 'Gagal memverifikasi ID. Coba ubah nama atau cek koneksi.',
        child: Icon(SolarIconsOutline.infoCircle, color: AppColors.warning.withValues(alpha: 0.7)),
      );
    }
    
    return const SizedBox.shrink();
  }

}
