import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_strings.dart';
import '../providers/system_providers.dart';
import '../providers/pengaturan_provider.dart';

class PinVerifyDialog extends ConsumerStatefulWidget {
  final Function(String pin) onVerified;
  final String title;
  final String subtitle;
  final String? bengkelId;

  const PinVerifyDialog({
    super.key,
    required this.onVerified,
    this.title = 'Verifikasi PIN Workshop',
    this.subtitle = 'Masukkan 6 digit PIN untuk melanjutkan.',
    this.bengkelId,
  });

  @override
  ConsumerState<PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends ConsumerState<PinVerifyDialog> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String _errorText = '';

  Future<void> _verify() async {
    final pin = _pinController.text;
    if (pin.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      final encryption = ref.read(encryptionServiceProvider);
      final bengkel = ref.read(bengkelServiceProvider);
      final settings = ref.read(settingsProvider);
      final bengkelId = widget.bengkelId ?? settings.bengkelId;

      if (bengkelId.isEmpty) {
        setState(() => _errorText = 'ID Bengkel tidak ditemukan.');
        return;
      }

      // Ambil wrapped key untuk verifikasi
      final wrappedKey = await bengkel.getWrappedMasterKey(bengkelId);
      if (wrappedKey == null) {
        setState(() => _errorText = 'Data keamanan tidak ditemukan.');
        return;
      }

      // Coba unwrap (tanpa simpan, karena kita cuma mau verifikasi PIN)
      // Kita butuh method verifikasi yang tidak mengubah state internal EncryptionService
      // Tapi kita bisa gunakan unwrapAndSaveMasterKey karena jika berhasil dia cuma menimpa memory key yang sama.
      final success = await encryption.unwrapAndSaveMasterKey(
        wrappedKey,
        pin,
        bengkelId,
      );

      if (success) {
        widget.onVerified(pin);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _errorText = AppStrings.auth.pinIncorrect);
        _pinController.clear();
      }
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1A1528) : Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, color: theme.colorScheme.primary, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(color: theme.colorScheme.outlineVariant),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) {
              if (val.length == 6) _verify();
            },
          ),
          if (_errorText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _errorText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.common.cancel),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
