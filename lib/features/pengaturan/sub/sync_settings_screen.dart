import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/migration_service.dart';
import '../../../core/models/user_profile.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/services/session_manager.dart';
import '../../../core/widgets/atelier_header.dart';

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
        title: const Text('Migrasi Data ke Cloud'),
        content: const Text(
          'Tindakan ini akan mengenkripsi dan mengunggah data lama Anda ke Firestore untuk pertama kali. '
          'Pastikan Anda memiliki koneksi internet yang stabil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Migrasi Sekarang'),
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
          const SnackBar(
            content: Text(
              'Migrasi Berhasil! Data Anda kini terenkripsi di Cloud.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migrasi Gagal: $e'),
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
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(currentProfileProvider);

    final sessionStatus = ref.watch(sessionStatusStreamProvider).value ?? SessionStatus.full;
    final isActive = settings.bengkelId.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Pusat Data Bengkel',
            subtitle: 'Simpan otomatis ke internet agar data tidak hilang.',
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Status Penyimpanan'),
                  _buildStatusCard(theme, isDark, isActive, sessionStatus),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Informasi Bengkel'),
                  _buildInfoCard(theme, isDark, settings, profile, settings.bengkelId),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Aksi Pemeliharaan'),
                  _buildMigrationButton(theme, isDark),
                  const SizedBox(height: 12),
                  _buildSecurityInfo(theme, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: AppColors.amethyst.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, bool isDark, bool isActive, SessionStatus sessionStatus) {
    var statusColor = isActive ? AppColors.success : AppColors.error;
    var statusTitle = isActive ? 'Sudah Terhubung' : 'Belum Terhubung';
    var statusSubtitle = isActive
        ? 'Semua data bengkel Anda sudah aman di internet.'
        : 'Hubungkan ke bengkel untuk mulai menyimpan data.';
    var statusIcon = isActive ? SolarIconsOutline.cloudCheck : SolarIconsOutline.cloudCross;

    // UX-05: Override UI if session is restricted or blocked
    if (isActive) {
      if (sessionStatus == SessionStatus.blocked || sessionStatus == SessionStatus.invalid) {
        statusColor = AppColors.error;
        statusTitle = 'Sesi Terkunci';
        statusSubtitle = 'Akses ditutup karena terlalu lama offline. Hubungkan internet segera.';
        statusIcon = SolarIconsOutline.shieldWarning;
      } else if (sessionStatus == SessionStatus.warning) {
        statusColor = AppColors.warning;
        statusTitle = 'Sesi Terbatas';
        statusSubtitle = 'Segera hubungkan internet untuk memulihkan akses penuh.';
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

  Widget _buildInfoCard(
    ThemeData theme,
    bool isDark,
    SettingsState settings,
    UserProfile? profile,
    String bengkelId,
  ) {
    final currentRole = profile?.role;
    final role = currentRole != null 
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
            'Nama Bengkel',
            settings.workshopName,
          ),
          Divider(height: 32, color: theme.colorScheme.outlineVariant),
          _buildBengkelIDRow(theme, bengkelId),
          Divider(height: 32, color: theme.colorScheme.outlineVariant),
          _buildInfoRow(
            theme,
            SolarIconsOutline.user,
            'Status Anda',
            role,
          ),
        ],
      ),
    );
  }

  Widget _buildBengkelIDRow(ThemeData theme, String bengkelId) {
    final isEmpty = bengkelId.isEmpty || bengkelId == '-';
    final displayId = isEmpty ? '-' : (_showBengkelId ? bengkelId : '••••••••••••');

    return Row(
      children: [
        const Icon(SolarIconsOutline.key, size: 18, color: AppColors.amethyst),
        const SizedBox(width: 12),
        Text('Bengkel ID',
            style: GoogleFonts.inter(
                fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        const Spacer(),
        GestureDetector(
          onLongPress: isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: bengkelId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bengkel ID disalin ke clipboard'),
                      duration: Duration(seconds: 2),
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
      ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.amethyst),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
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
                  : const Icon(SolarIconsOutline.shieldCheck,
                      color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perkuat Keamanan Data',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.warning : AppColors.warning,
                    ),
                  ),
                  Text(
                    'Gunakan sistem pengunci terbaru agar data pelanggan lebih aman.',
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
        color: AppColors.amethyst.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            SolarIconsOutline.shieldCheck,
            color: AppColors.amethyst,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pelindung Data: Nama dan nomor HP pelanggan disandikan secara rahasia. Hanya Anda yang bisa membukanya.',
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
