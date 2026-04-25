import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/services/migration_service.dart';
import '../../../core/models/user_profile.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/services/session_manager.dart';
import '../../../core/widgets/atelier_header.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/app_logger.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _migrationService = MigrationService();
  bool _isMigrating = false;
  bool _showBengkelId = false;

  Future<void> _handleMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.dataCenter.migrationTitle),
        content: Text(AppStrings.dataCenter.migrationDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.common.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text(AppStrings.dataCenter.migrationAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isMigrating = true);
    try {
      final settings = ref.read(settingsProvider);
      await _migrationService.migrateToEncryption(settings.bengkelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.dataCenter.migrationSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.error.generic}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $e',
                style: GoogleFonts.plusJakartaSans(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (container) => _buildBody(theme, isDark, container),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark, dynamic container) {
    // Error boundary untuk mencegah white screen
    try {
      final profile = container.profile;
      final settings = ref.watch(settingsProvider);

      // Async providers dengan error handling
      final summary = ref.watch(syncQueueSummaryProvider);
      final sessionStatusAsync = ref.watch(currentSessionStatusProvider);

      // Extract values dengan fallback
      final sessionStatus = sessionStatusAsync.value ?? SessionStatus.full;

      final isActive = settings.bengkelId.isNotEmpty && settings.bengkelId != '-';

      // Log untuk debugging
      appLogger.debug(
        'SyncSettingsScreen build - isActive: $isActive, sessionStatus: $sessionStatus',
        context: 'SyncSettingsScreen',
      );

      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            SliverAtelierHeaderSub(
              title: AppStrings.dataCenter.title,
              subtitle: AppStrings.dataCenter.subtitle,
              showBackButton: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(AppStrings.dataCenter.storageStatus),
                    _buildStatusCard(theme, isDark, isActive, sessionStatus),
                    const SizedBox(height: 16),
                    _buildQueueSummary(theme, isDark, summary),
                    const SizedBox(height: 24),
                    _buildSectionHeader(AppStrings.dataCenter.workshopInfo),
                    _buildInfoCard(theme, isDark, settings, profile, settings.bengkelId),
                    const SizedBox(height: 32),
                    _buildSectionHeader(AppStrings.dataCenter.maintenanceActions),
                    _buildMigrationButton(theme, isDark),
                    const SizedBox(height: 12),
                    _buildSecurityInfo(theme, isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      appLogger.error(
        'SyncSettingsScreen build error',
        context: 'SyncSettingsScreen',
        error: e,
        stackTrace: stack,
      );
      return _buildErrorWidget(e.toString(), theme);
    }
  }

  Widget _buildErrorWidget(String message, ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Terjadi Kesalahan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(authStateProvider);
                        ref.invalidate(settingsProvider);
                        ref.invalidate(syncQueueSummaryProvider);
                        ref.invalidate(currentSessionStatusProvider);
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Muat Ulang'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Kembali'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    ThemeData theme,
    bool isDark,
    bool isActive,
    SessionStatus sessionStatus,
  ) {
    var statusColor = isActive ? AppColors.success : AppColors.error;
    var statusTitle = isActive
        ? AppStrings.dataCenter.connected
        : AppStrings.dataCenter.notConnected;
    var statusSubtitle = isActive
        ? AppStrings.dataCenter.connectedDesc
        : AppStrings.dataCenter.notConnectedDesc;
    var statusIcon = isActive
        ? SolarIconsOutline.cloudCheck
        : SolarIconsOutline.cloudCross;

    // Override UI if session is restricted or blocked
    if (isActive) {
      if (sessionStatus == SessionStatus.blocked ||
          sessionStatus == SessionStatus.invalid) {
        statusColor = AppColors.error;
        statusTitle = AppStrings.dataCenter.sessionLocked;
        statusSubtitle = AppStrings.dataCenter.sessionLockedDesc;
        statusIcon = SolarIconsOutline.shieldWarning;
      } else if (sessionStatus == SessionStatus.warning) {
        statusColor = AppColors.warning;
        statusTitle = AppStrings.dataCenter.sessionRestricted;
        statusSubtitle = AppStrings.dataCenter.sessionRestrictedDesc;
        statusIcon = SolarIconsOutline.shieldMinimalistic;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  statusSubtitle,
                  style: GoogleFonts.plusJakartaSans(
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

  Widget _buildQueueSummary(
    ThemeData theme,
    bool isDark,
    Map<String, int> summary,
  ) {
    final hasFailed = (summary['failed'] ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildQueueItem(theme, 'Pending', summary['pending'] ?? 0, Colors.blue),
              _buildQueueItem(theme, 'Synced', summary['synced'] ?? 0, AppColors.success),
              _buildQueueItem(theme, 'Failed', summary['failed'] ?? 0, AppColors.error),
            ],
          ),
          if (hasFailed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  try {
                    ref.read(syncStatusProvider.notifier).retryFailed();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Memproses ulang item yang gagal...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    appLogger.error('Retry failed error: $e', context: 'SyncSettingsScreen');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memproses: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(SolarIconsOutline.restart, size: 18),
                label: Text(
                  'Coba Lagi Item Gagal',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueItem(ThemeData theme, String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: count > 0
                  ? color
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    bool isDark,
    SettingsState settings,
    UserProfile? profile,
    String bengkelId,
  ) {
    final currentRole = profile?.role ?? '';
    final role = currentRole.isNotEmpty
        ? (currentRole[0].toUpperCase() + currentRole.substring(1).toLowerCase())
        : 'Owner (Local)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            theme,
            SolarIconsOutline.shop,
            AppStrings.dataCenter.workshopName,
            settings.workshopName.isEmpty ? '-' : settings.workshopName,
          ),
          Divider(height: 32, color: theme.colorScheme.outlineVariant),
          _buildBengkelIDRow(theme, bengkelId),
          Divider(height: 32, color: theme.colorScheme.outlineVariant),
          _buildInfoRow(
            theme,
            SolarIconsOutline.user,
            AppStrings.dataCenter.yourStatus,
            role,
          ),
        ],
      ),
    );
  }

  Widget _buildBengkelIDRow(ThemeData theme, String bengkelId) {
    final isEmpty = bengkelId.isEmpty || bengkelId == '-';
    final displayId = isEmpty
        ? '-'
        : (_showBengkelId ? bengkelId : '••••••••••••');

    return Row(
      children: [
        Icon(SolarIconsOutline.key, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          'Bengkel ID',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onLongPress: isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: bengkelId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.dataCenter.idCopied),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
          child: Text(
            displayId,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
              letterSpacing: _showBengkelId ? 1.0 : 2.0,
            ),
          ),
        ),
        if (!isEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showBengkelId = !_showBengkelId),
            child: Icon(
              _showBengkelId ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value.isEmpty ? '-' : value,
          style: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMigrationButton(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: _isMigrating ? null : _handleMigration,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
              child: _isMigrating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      SolarIconsOutline.shieldCheck,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.dataCenter.perkuatKeamanan,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.warning : AppColors.warning,
                    ),
                  ),
                  Text(
                    AppStrings.dataCenter.perkuatKeamananDesc,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.warning),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityInfo(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            SolarIconsOutline.shieldCheck,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppStrings.dataCenter.pelindungData,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
