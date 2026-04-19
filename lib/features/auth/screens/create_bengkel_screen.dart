import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/bengkel_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/encryption_service.dart';

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
  final _bengkelService = BengkelService();
  final _biometricService = BiometricService();
  final _encryptionService = EncryptionService();

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
    final available = await _biometricService.isAvailable();
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
    if (name.length >= 3) {
      // Auto-generate preview ID
      final previewId = _bengkelService.generateBengkelId(name);
      _bengkelIdController.text = previewId;

      // Debounce availability check
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
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
    setState(() => _isChecking = true);
    try {
      final available = await _bengkelService.isBengkelIdAvailable(bengkelId);
      if (mounted) {
        setState(() {
          _isAvailable = available;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAvailable = null;
          _isChecking = false;
        });
      }
    }
  }

  void _regenerateId() {
    final name = _nameController.text.trim();
    if (name.length >= 3) {
      final newId = _bengkelService.generateBengkelId(name);
      _bengkelIdController.text = newId;
      _checkAvailability(newId);
    }
  }

  Future<void> _claimBengkel() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAvailable != true) return;

    setState(() => _isClaiming = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final bengkelId = _bengkelIdController.text.trim();
      final bengkelName = _nameController.text.trim();
      final pin = _pinController.text.trim();

      // 0. Generate fresh master key for the new bengkel
      await _encryptionService.generateNewMasterKey();

      // 1. Claim the Bengkel ID
      await _bengkelService.claimBengkelId(
        bengkelId: bengkelId,
        ownerUid: user.uid,
        bengkelName: bengkelName,
        pin: pin,
      );

      // 2. Join the newly created bengkel
      await _bengkelService.joinBengkel(
        bengkelId: bengkelId,
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        pin: pin,
        role: 'owner',
      );

      // 3. Save derived key for Biometric if enabled
      if (_biometricEnabled) {
        final authOk = await _biometricService.authenticate(
          reason: 'Verifikasi identitas untuk mengaktifkan akses cepat',
        );

        if (authOk) {
          await _encryptionService.saveDerivedKeyForBiometric(pin, bengkelId);
          await _biometricService.savePin(pin, bengkelId);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sidik jari diperlukan untuk mengaktifkan akses cepat'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // Refresh auth state to pick up new profile
      if (mounted) {
        ref.invalidate(authStateProvider);
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
          'Buat Bengkel Baru',
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
                  'Nama Bengkel',
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
                    hintText: 'Contoh: Bengkel Tentrem Auto',
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
                      return 'Nama bengkel minimal 3 karakter';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Bengkel ID
                Row(
                  children: [
                    Text(
                      'Bengkel ID',
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
                        color: Color(0xFF7C3AED),
                      ),
                      label: Text(
                        'Generate Ulang',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF7C3AED),
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
                    hintText: 'Auto-generated dari nama',
                    prefixIcon: Icon(
                      SolarIconsOutline.key,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    suffixIcon: _buildAvailabilityIndicator(),
                    // Inline helper/error text
                    helperText: _isAvailable == true ? 'ID Bengkel tersedia' : null,
                    helperStyle: GoogleFonts.inter(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                    errorText: _isAvailable == false ? 'ID sudah digunakan, coba generate ulang' : null,
                    errorStyle: GoogleFonts.inter(
                      color: Colors.redAccent,
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
                  'PIN Bengkel (6-angka)',
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
                    hintText: 'Masukkan 6 angka PIN',
                    prefixIcon: Icon(
                      SolarIconsOutline.lock,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    counterText: '',
                    // Inline error feedback
                    errorText: _pinController.text.isNotEmpty && _pinController.text.length < 6 
                        ? 'PIN harus 6 digit' 
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
                      return 'PIN harus 6 digit angka';
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
                        'Gunakan Biometrik',
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
                        color: _biometricEnabled ? const Color(0xFF7C3AED) : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      activeThumbColor: const Color(0xFF7C3AED),
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
                          'PENTING: Ingat PIN Bengkel Anda. PIN ini digunakan untuk mengenkripsi data penting dan login di perangkat baru.',
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
                        color: Color(0xFF7C3AED),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bengkel ID digunakan staff untuk bergabung. Bagikan ID ini ke tim Anda.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFa855f7)
                                : const Color(0xFF7C3AED),
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
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.3),
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
                            'Buat Bengkel',
                            style: GoogleFonts.inter(
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
            color: Color(0xFF7C3AED),
          ),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: Color(0xFF10B981));
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel, color: Colors.redAccent);
    }
    return const SizedBox.shrink();
  }

}
