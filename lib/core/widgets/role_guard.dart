import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/system_providers.dart';
import '../models/user_profile.dart';

/// Widget untuk hide/show berdasarkan permission.
/// Jika user tidak punya permission, tampilkan [fallback] atau SizedBox.shrink().
class PermissionGuard extends ConsumerWidget {
  final Widget child;
  final Permission permission;
  final Widget? fallback;

  const PermissionGuard({
    required this.child,
    required this.permission,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(permissionProvider(permission));

    if (!hasPermission) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

/// Widget untuk disable + tooltip edukasi berdasarkan permission.
/// User bisa tap → muncul dialog "(Role) tidak memiliki akses".
class PermissionEnabled extends ConsumerWidget {
  final Widget child;
  final Permission permission;
  final String? disabledTooltip;
  final VoidCallback? onDisabledTap;

  const PermissionEnabled({
    required this.child,
    required this.permission,
    this.disabledTooltip,
    this.onDisabledTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(permissionProvider(permission));
    final profile = ref.watch(currentProfileProvider);

    if (!hasPermission) {
      return Tooltip(
        message:
            disabledTooltip ?? _getDefaultMessage(permission, profile?.role),
        child: GestureDetector(
          onTap:
              onDisabledTap ??
              () => _showUpgradeMessage(context, permission, profile?.role),
          child: IgnorePointer(
            ignoring: true,
            child: Opacity(opacity: 0.5, child: child),
          ),
        ),
      );
    }
    return child;
  }

  String _getDefaultMessage(Permission permission, String? role) {
    switch (permission) {
      case Permission.viewOmzet:
        return 'Hanya Owner yang bisa melihat laporan omzet';
      case Permission.deleteTransaction:
        return 'Hanya Owner yang bisa menghapus transaksi';
      case Permission.manageStaff:
        return 'Hanya Owner yang bisa mengelola tim';
      case Permission.manageInventory:
        return 'Hanya Owner/Admin yang bisa mengelola inventaris';
      case Permission.backupData:
        return 'Hanya Owner yang bisa backup data';
      case Permission.sendReminder:
        return 'Hanya Owner/Admin yang bisa mengirim pengingat';
    }
  }

  void _showUpgradeMessage(
    BuildContext context,
    Permission permission,
    String? role,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: isDark ? Colors.amberAccent : Colors.deepPurple,
            ),
            const SizedBox(width: 8),
            const Text('Akses Dibatasi'),
          ],
        ),
        content: Text(_getDefaultMessage(permission, role)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Mengerti',
              style: TextStyle(
                color: isDark ? Colors.amberAccent : Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget untuk show/hide berdasarkan role.
class RoleGuard extends ConsumerWidget {
  final Widget child;
  final String role;
  final Widget? fallback;

  const RoleGuard({
    required this.child,
    required this.role,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRole = ref.watch(roleProvider(role));

    if (!isRole) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

