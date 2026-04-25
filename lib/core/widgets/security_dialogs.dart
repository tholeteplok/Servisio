import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';
import '../utils/app_logger.dart';

class SecurityDialogs {
  /// Dialog for setup 6-digit PIN
  static Future<String?> showPINSetup(BuildContext context) async {
    String? pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PINInputSheet(
        title: 'Buat PIN Keamanan',
        subtitle: 'Gunakan 6 angka unik untuk mengamankan data bengkel Anda.',
      ),
    );

    if (pin == null || pin.length < 6) return null;

    if (!context.mounted) return null;

    // Confirm PIN
    String? confirmPin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PINInputSheet(
        title: 'Konfirmasi PIN',
        subtitle: 'Masukkan ulang 6 angka PIN Anda.',
      ),
    );

    if (pin == confirmPin) {
      return pin;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN tidak cocok. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Verify Biometric with PIN Fallback
  static Future<bool> verify(
    BuildContext context, {
    required String bengkelId,
    String reason = 'Verifikasi Keamanan',
  }) async {
    final bio = BiometricService();

    try {
      // 1. Coba biometric dengan timeout 5 detik
      // Jika biometrik sub-system hang, kita tidak ingin user menunggu selamanya.
      final authenticated = await bio
          .verify(reason: reason)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              appLogger.warning('Biometric timeout (5s)', context: 'SecurityDialogs');
              return false;
            },
          );

      if (authenticated) return true;
    } catch (e) {
      appLogger.error('Biometric error', context: 'SecurityDialogs', error: e);
      // Lanjut ke fallback PIN jika error
    }

    // 2. Fallback to PIN
    if (context.mounted) {
      appLogger.info('Falling back to PIN verification', context: 'SecurityDialogs');
      final res = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PINVerifySheet(reason: reason, bengkelId: bengkelId),
      );
      return res ?? false;
    }

    return false;
  }
}

class _PINInputSheet extends StatefulWidget {
  final String title;
  final String subtitle;

  const _PINInputSheet({required this.title, required this.subtitle});

  @override
  State<_PINInputSheet> createState() => _PINInputSheetState();
}

class _PINInputSheetState extends State<_PINInputSheet> {
  String _code = '';

  void _onKeyTap(String key) {
    if (_code.length < 6) {
      HapticFeedback.lightImpact();
      setState(() => _code += key);
      if (_code.length == 6) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) Navigator.pop(context, _code);
        });
      }
    }
  }

  void _onBackspace() {
    if (_code.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _code = _code.substring(0, _code.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              bool active = index < _code.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  border: Border.all(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
              );
            }),
          ),
          const SizedBox(height: 48),
          _buildNumPad(theme),
        ],
      ),
    );
  }

  Widget _buildNumPad(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '1',
            '2',
            '3',
          ].map((n) => _NumButton(n, onTap: () => _onKeyTap(n))).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '4',
            '5',
            '6',
          ].map((n) => _NumButton(n, onTap: () => _onKeyTap(n))).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '7',
            '8',
            '9',
          ].map((n) => _NumButton(n, onTap: () => _onKeyTap(n))).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80),
            _NumButton('0', onTap: () => _onKeyTap('0')),
            SizedBox(
              width: 80,
              child: IconButton(
                onPressed: _onBackspace,
                icon: const Icon(Icons.backspace_outlined, size: 28),
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PINVerifySheet extends StatefulWidget {
  final String reason;
  final String bengkelId;
  const _PINVerifySheet({required this.reason, required this.bengkelId});

  @override
  State<_PINVerifySheet> createState() => _PINVerifySheetState();
}

class _PINVerifySheetState extends State<_PINVerifySheet>
    with SingleTickerProviderStateMixin {
  String _code = '';
  bool _error = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) async {
    if (_code.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _code += key;
        _error = false;
      });
      if (_code.length == 6) {
        final success = await BiometricService().verifyPin(_code, widget.bengkelId);
        if (success) {
          HapticFeedback.mediumImpact();
          if (mounted) Navigator.pop(context, true);
        } else {
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0);
          setState(() {
            _code = '';
            _error = true;
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_code.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _code = _code.substring(0, _code.length - 1);
        _error = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_person_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            widget.reason,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error
                ? 'PIN salah. Silakan coba lagi.'
                : 'Masukkan 6 angka PIN keamanan Anda.',
            style: TextStyle(
              color: _error ? Colors.red : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              // Simple shake animation using a sine wave
              double offset = 0;
              if (_shakeController.isAnimating) {
                // Sine wave shake: 10 pixels max, 5 cycles
                offset = math.sin(_shakeController.value * 5 * math.pi) * 10;
              }
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                bool active = index < _code.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    border: Border.all(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 48),
          _buildNumPad(theme),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumPad(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '1',
            '2',
            '3',
          ].map((n) => _NumButton(n, onTap: () => _onKeyTap(n))).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '4',
            '5',
            '6',
          ].map((n) => _NumButton(n, onTap: () => _onKeyTap(n))).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '7',
            '8',
            '9',
          ].map((n) => _NumButton(n, onTap: () => _onKeyTap(n))).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80),
            _NumButton('0', onTap: () => _onKeyTap('0')),
            SizedBox(
              width: 80,
              child: IconButton(
                onPressed: _onBackspace,
                icon: const Icon(Icons.backspace_outlined, size: 28),
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumButton(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3,),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

