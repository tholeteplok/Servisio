// 🛡️ ServisLog+ Hybrid Security Policy — Critical Action Guard
// Wrapper untuk critical actions yang wajib re-auth
// Actions: delete, editPaid, export, viewFinancials, manageStaff, changeSettings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_manager.dart';
import '../services/biometric_service.dart';
import '../providers/pengaturan_provider.dart';
import 'security_dialogs.dart';

// 🛡️ Critical Action Guard Widget
class CriticalActionGuard extends ConsumerStatefulWidget {
  final VoidCallback onVerified;
  final CriticalActionType actionType;
  final Widget child;
  final String? customReason;
  final bool showTooltip;
  final bool forceGuard; // If true, ignore requireBiometricSensitive toggle
  
  const CriticalActionGuard({
    required this.onVerified,
    required this.actionType,
    required this.child,
    this.customReason,
    this.showTooltip = true,
    this.forceGuard = false,
    super.key,
  });
  
  @override
  ConsumerState<CriticalActionGuard> createState() => _CriticalActionGuardState();

  /// 🛡️ Static Imperative Guard
  static Future<bool> check(
    WidgetRef ref,
    BuildContext context,
    CriticalActionType actionType, {
    String? customReason,
    bool forceGuard = false,
  }) async {
    final settings = ref.read(settingsProvider);
    final sessionManager = ref.read(sessionManagerProvider);
    final biometricService = ref.read(biometricServiceProvider);

    // 0. QUICK CHECK (REACTIVE/CACHED)
    // Avoid blocking UI if access is already known to be blocked.
    final currentAccess = ref.read(accessLevelProvider);
    if (currentAccess == AccessLevel.blocked) {
      if (context.mounted) showBlockedDialog(context);
      return false;
    }

    // 1. VALIDATE SESSION (WITH TIMEOUT)
    // Ensure we don't hang forever on network handshake.
    AccessLevel accessLevel;
    try {
      accessLevel = await sessionManager.getAccessLevel().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ CriticalActionGuard: Session validation timeout');
          // If timeout, fallback to current cached state
          return ref.read(accessLevelProvider);
        },
      );
    } catch (e) {
      debugPrint('❌ CriticalActionGuard: Session validation error: $e');
      accessLevel = ref.read(accessLevelProvider);
    }

    if (accessLevel == AccessLevel.blocked) {
      if (context.mounted) showBlockedDialog(context);
      return false;
    }

    // 2. Check if action is allowed (Zone check)
    final canPerform = await sessionManager.canPerformAction(actionType);
    if (!canPerform) {
      if (context.mounted) showRestrictedDialog(context);
      return false;
    }

    // 🛡️ SECURITY TOGGLE CHECK:
    if (!forceGuard) {
      if (!settings.isBiometricEnabled || !settings.requireBiometricSensitive) {
        return true;
      }
    }

    // 3. Re-auth dengan biometric (UI Wrapper)
    final reason = customReason ?? getAuthReason(actionType);
    
    // ✅ Use SecurityDialogs for centralized premium UI & fallback
    // instead of calling service directly for better UX.
    try {
      if (!context.mounted) return false;
      final verified = await SecurityDialogs.verify(context, reason: reason).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ CriticalActionGuard: Security verification timeout');
          return false;
        },
      );
      
      if (verified) {
        await biometricService.resetFailures();
        return true;
      }
    } catch (e) {
      debugPrint('❌ CriticalActionGuard: Verification error: $e');
    }

    return false;
  }

  static String getAuthReason(CriticalActionType actionType) {
    switch (actionType) {
      case CriticalActionType.deleteTransaction:
        return 'Verifikasi untuk menghapus transaksi';
      case CriticalActionType.editPaidFee:
        return 'Verifikasi untuk edit biaya lunas';
      case CriticalActionType.exportData:
        return 'Verifikasi untuk export data';
      case CriticalActionType.viewFinancials:
        return 'Verifikasi untuk akses laporan keuangan';
      case CriticalActionType.manageStaff:
        return 'Verifikasi untuk kelola tim';
      case CriticalActionType.changeSettings:
        return 'Verifikasi untuk ubah pengaturan';
      case CriticalActionType.manageInventory:
        return 'Verifikasi untuk modifikasi inventori';
      case CriticalActionType.editCustomer:
        return 'Verifikasi untuk edit data pelanggan';
      case CriticalActionType.deleteCustomer:
        return 'Verifikasi untuk hapus pelanggan';
      case CriticalActionType.manageBackup:
        return 'Verifikasi untuk kelola cadangan data';
    }
  }

  static void showBlockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: Colors.red, size: 48),
        title: const Text('Aksi Ditolak'),
        content: const Text(
            'Perangkat offline terlalu lama. Sila perbarui sesi Anda dengan menghubungkan ke internet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  static void showRestrictedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.amber, size: 48),
        title: const Text('Akses Dibatasi'),
        content: const Text(
            'Mode Baca Saja (Offline > 8 jam). Fitur ini sementara tidak dapat digunakan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  static Future<bool> showMasterPasswordDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    bool isVisible = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.admin_panel_settings,
              color: Colors.indigo, size: 48),
          title: const Text('Master Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gunakan PIN 6-Digit Master Password Anda sebagai fallback verifikasi harian.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: !isVisible,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => isVisible = !isVisible),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final manager = ref.read(sessionManagerProvider);
                final isValid =
                    await manager.verifyMasterPassword(controller.text);
                if (context.mounted) {
                  Navigator.pop(context, isValid);
                }
              },
              child: const Text('Verifikasi'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }
}

class _CriticalActionGuardState extends ConsumerState<CriticalActionGuard> {
  bool _isProcessing = false;
  
  @override
  Widget build(BuildContext context) {
    if (widget.showTooltip) {
      return Tooltip(
        message: _getActionDescription(),
        child: _buildGestureDetector(),
      );
    }
    return _buildGestureDetector();
  }
  
  Widget _buildGestureDetector() {
    return GestureDetector(
      onTap: _isProcessing ? null : _handleTap,
      child: widget.child,
    );
  }
  
  Future<void> _handleTap() async {
    setState(() => _isProcessing = true);
    
    try {
      await _requireCriticalAuth();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  Future<void> _requireCriticalAuth() async {
    final verified = await CriticalActionGuard.check(
      ref,
      context,
      widget.actionType,
      customReason: widget.customReason,
      forceGuard: widget.forceGuard,
    );
    
    if (verified && mounted) {
      widget.onVerified();
    } else if (!verified && mounted) {
      // CriticalActionGuard.check() internally handles showing blocked/error dialogs.
    }
  }


  String _getActionDescription() {
    switch (widget.actionType) {
      case CriticalActionType.deleteTransaction:
        return 'Hapus Transaksi (Verifikasi Required)';
      case CriticalActionType.editPaidFee:
        return 'Edit Biaya Lunas (Verifikasi Required)';
      case CriticalActionType.exportData:
        return 'Export Data (Verifikasi Required)';
      case CriticalActionType.viewFinancials:
        return 'Laporan Keuangan (Verifikasi Required)';
      case CriticalActionType.manageStaff:
        return 'Kelola Tim (Verifikasi Required)';
      case CriticalActionType.changeSettings:
        return 'Ubah Pengaturan (Verifikasi Required)';
      case CriticalActionType.manageInventory:
        return 'Modifikasi Inventori (Verifikasi Required)';
      case CriticalActionType.editCustomer:
        return 'Edit Pelanggan (Verifikasi Required)';
      case CriticalActionType.deleteCustomer:
        return 'Hapus Pelanggan (Verifikasi Required)';
      case CriticalActionType.manageBackup:
        return 'Kelola Cadangan Data (Verifikasi Required)';
    }
  }
}

