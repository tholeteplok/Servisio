import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/services/device_session_service.dart';
import '../../../core/widgets/standard_dialog.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/providers/objectbox_provider.dart';
import '../../../core/services/sync_worker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/widgets/atelier_header.dart';
import '../../../core/constants/app_strings.dart';

class SecurityDataCenterScreen extends ConsumerWidget {
  const SecurityDataCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAtelierHeaderSub(
            title: AppStrings.security.title,
            subtitle: AppStrings.security.subtitle,
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const HealthDashboard(),
                const SizedBox(height: 24),
                const ShieldSection(),
                const SizedBox(height: 24),
                const SyncSection(),
                const SizedBox(height: 24),
                const AccountInfoSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }


}

// 🛡️ SECTION 1: SHIELD v2.0
class ShieldSection extends ConsumerWidget {
  const ShieldSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sessionStatus = ref.watch(deviceSessionStatusProvider);
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.security.shieldProtection,
          icon: LucideIcons.shieldCheck,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.4
                        : 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              sessionStatus.when(
                data: (status) => StatusBanner(status: status),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const StatusBanner(status: DeviceSessionStatus.unknown),
              ),
              const SizedBox(height: 20),
              SettingToggle(
                title: AppStrings.security.autoLock30m,
                subtitle: AppStrings.security.autoLockDesc,
                value: settings.autoLock30m,
                icon: LucideIcons.timer,
                onChanged: (v) => ref.read(settingsProvider.notifier).setAutoLock30m(v),
              ),
              const Divider(height: 32),
              const ActiveDeviceTile(),
              const SizedBox(height: 12),
              const LoginHistoryList(),
            ],
          ),
        ),
      ],
    );
  }
}

// 🔄 SECTION 2: SYNC v1.4
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusState = ref.watch(syncStatusProvider);
    final settings = ref.watch(settingsProvider);

    String lastSyncText = AppStrings.security.lastSyncNever;
    if (syncStatusState.lastSyncedAt != null) {
      final now = DateTime.now();
      final diff = now.difference(syncStatusState.lastSyncedAt!);
      if (diff.inMinutes < 1) {
        lastSyncText = AppStrings.security.lastSyncJustNow;
      } else if (diff.inHours < 1) {
        lastSyncText = AppStrings.security.lastSyncMinutesAgo(diff.inMinutes);
      } else {
        lastSyncText = AppStrings.security.lastSyncAt(
            DateFormat('HH:mm').format(syncStatusState.lastSyncedAt!));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.security.syncCloud,
          icon: LucideIcons.refreshCw,
          color: AppColors.info,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.4
                        : 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SyncPulseIndicator(state: syncStatusState.state),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSyncLabel(syncStatusState.state),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          lastSyncText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              SettingToggle(
                title: 'Hanya via Wi-Fi',
                subtitle: 'Hemat kuota data seluler Anda.',
                value: settings.syncWifiOnly,
                icon: LucideIcons.wifi,
                onChanged: (v) => ref.read(settingsProvider.notifier).setSyncWifiOnly(v),
              ),
              const SizedBox(height: 16),
              SettingToggle(
                title: 'Kompresi Gambar',
                subtitle: 'Optimalkan ukuran media saat upload.',
                value: settings.syncCompressionMax,
                icon: LucideIcons.image,
                onChanged: (v) => ref.read(settingsProvider.notifier).setSyncCompressionMax(v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSyncLabel(SyncWorkerState state) {
    switch (state) {
      case SyncWorkerState.syncing:
        return 'Sedang Sinkronisasi...';
      case SyncWorkerState.warning:
        return 'Ada Antrean Tertunda';
      case SyncWorkerState.error:
        return 'Sinkronisasi Gagal';
      case SyncWorkerState.success:
      case SyncWorkerState.idle:
        return 'Data Tersinkronisasi';
    }
  }
}

// 📦 SECTION 3: DEVICE INFO
class AccountInfoSection extends ConsumerWidget {
  const AccountInfoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceIdAsync = ref.watch(currentDeviceIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'IDENTITAS PERANGKAT',
          icon: LucideIcons.info,
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.4
                        : 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              deviceIdAsync.when(
                data: (id) => _InfoRow(
                  label: 'Device Signature ID',
                  value: id.toUpperCase().substring(0, 12),
                  fullValue: id,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID Berhasil disalin')),
                    );
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Gagal memuat ID'),
              ),
              const Divider(height: 32),
              const _InfoRow(
                label: 'Security Stack',
                value: 'SL+ Core v1.4 (Amethyst)',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── HELPER WIDGETS ──────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class StatusBanner extends StatelessWidget {
  final DeviceSessionStatus status;

  const StatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHealthy = status == DeviceSessionStatus.valid;
    final color = isHealthy ? AppColors.success : AppColors.error;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(isHealthy ? LucideIcons.shieldCheck : LucideIcons.shieldAlert, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Proteksi Berjalan' : 'Sesi Bermasalah',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  isHealthy 
                    ? 'Akses perangkat ini tervalidasi.' 
                    : 'Segera periksa otoritas akses.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const SettingToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class ActiveDeviceTile extends ConsumerWidget {
  const ActiveDeviceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(loginHistoryStreamProvider);
    final myIdAsync = ref.watch(currentDeviceIdProvider);
    
    return historyAsync.when(
      data: (history) {
        final myId = myIdAsync.value ?? '';
        final currentDevice = history.firstWhere(
          (d) => d.deviceId == myId,
          orElse: () => DeviceInfo(
            deviceId: myId,
            model: 'Unknown',
            osVersion: 'Unknown',
            loginAt: DateTime.now(),
          ),
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                currentDevice.osVersion.toLowerCase().contains('ios') 
                    ? LucideIcons.smartphone 
                    : LucideIcons.smartphone,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERANGKAT AKTIF',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      currentDevice.model,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              _SecondaryButton(
                label: AppStrings.common.logout,
                onPressed: () => _showNuclearDialog(context, ref),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
      error: (e, s) => const SizedBox(),
    );
  }

  void _showNuclearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.54),
      builder: (ctx) => StandardDialog(
        icon: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.logOut,
            color: AppColors.error,
            size: 36,
          ),
        ),
        title: AppStrings.security.logoutConfirmTitle,
        message: AppStrings.security.logoutConfirmMessage,
        primaryActionLabel: AppStrings.common.logout,
        primaryActionColor: AppColors.error,
        onPrimaryAction: () async {
          Navigator.pop(ctx);
          final service = ref.read(deviceSessionServiceProvider);
          await service.executeNuclearSequence(
            onWipeStarted: () => ref.read(isWipingProvider.notifier).state = true,
            onCloseDatabase: () async => ref.read(dbProvider).store.close(),
            onComplete: () async {
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          );
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        },
        secondaryActionLabel: AppStrings.common.cancel,
      ),
    );
  }
}

class LoginHistoryList extends ConsumerWidget {
  const LoginHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(loginHistoryStreamProvider);
    final myIdAsync = ref.watch(currentDeviceIdProvider);

    return historyAsync.when(
      data: (history) {
        final myId = myIdAsync.value ?? '';
        final otherDevices = history.where((d) => d.deviceId != myId).toList();

        if (otherDevices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Text(
              'Belum ada riwayat perangkat lain.',
              style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
              child: Text(
                'RIWAYAT AKSES LAIN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, 
                  fontWeight: FontWeight.w900, 
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...otherDevices.map((d) => _HistoryItem(
              model: d.model, 
              time: DateFormat('dd MMM, HH:mm').format(d.loginAt),
            )),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String model;
  final String time;

  const _HistoryItem({required this.model, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(LucideIcons.history, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(model, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(time, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? fullValue;
  final VoidCallback? onCopy;

  const _InfoRow({required this.label, required this.value, this.onCopy, this.fullValue});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(
                value, 
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            onPressed: onCopy,
            icon: const Icon(LucideIcons.copy, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }
}

class HealthDashboard extends ConsumerWidget {
  const HealthDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusState = ref.watch(syncStatusProvider);
    final sessionStatus = ref.watch(deviceSessionStatusProvider);

    final isHealthy = syncStatusState.state != SyncWorkerState.error && 
                      sessionStatus.maybeWhen(
                        data: (s) => s == DeviceSessionStatus.valid,
                        orElse: () => true,
                      );

    final theme = Theme.of(context);
    final color = isHealthy ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.4
                    : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHealthy ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Sistem Terproteksi' : 'Perlu Perhatian',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  isHealthy 
                    ? 'Data Anda aman dan tersinkronisasi.' 
                    : 'Terjadi kendala pada sinkronisasi cloud.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class SyncPulseIndicator extends StatefulWidget {
  final SyncWorkerState state;
  const SyncPulseIndicator({super.key, required this.state});

  @override
  State<SyncPulseIndicator> createState() => SyncPulseIndicatorState();
}

class SyncPulseIndicatorState extends State<SyncPulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant SyncPulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.state == SyncWorkerState.syncing || 
        widget.state == SyncWorkerState.error || 
        widget.state == SyncWorkerState.warning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.state) {
      SyncWorkerState.syncing => AppColors.success,
      SyncWorkerState.warning => AppColors.warning,
      SyncWorkerState.error => AppColors.error,
      _ => AppColors.textSecondary,
    };
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * (1 - _controller.value)),
                blurRadius: 10 * _controller.value,
                spreadRadius: 4 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

