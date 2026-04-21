import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/drive_backup_service.dart';
import '../../../core/widgets/standard_dialog.dart';
import 'restore_screen.dart';
import '../../../core/widgets/atelier_header.dart';
import '../../../core/widgets/critical_action_guard.dart';
import '../../../core/services/session_manager.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final AuthService _authService = AuthService();
  final DriveBackupService _driveService = DriveBackupService();

  Future<void> _handleGoogleLogin() async {
    try {
      await _authService.signIn();
      setState(() {}); // Refresh UI for login status
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login Gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleManualBackup() async {
    if (_authService.currentUser == null) {
      await _handleGoogleLogin();
    }
    if (_authService.currentUser == null) return;

    try {
      await ref.read(backupProvider.notifier).runBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup Berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup Gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleManualRestore() async {
    if (_authService.currentUser == null) {
      await _handleGoogleLogin();
    }
    if (!mounted) return;
    if (_authService.currentUser == null) return;

    final verified = await CriticalActionGuard.check(
      ref,
      context,
      CriticalActionType.manageBackup,
    );
    if (!mounted) return;
    if (!verified) return;

    try {
      final backup = await _driveService.downloadLatestBackup();
      if (!mounted) return;

      if (backup != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestoreScreen(backupFile: backup),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada cadangan ditemukan di Google Drive.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengecek cadangan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // SEC-05 FIX: Konfirmasi eksplisit sebelum export data yang mengandung PII
  // (nama, telepon, alamat pelanggan) tanpa enkripsi ke Share Sheet.
  Future<bool> _confirmPiiExport({required String exportType}) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StandardDialog(
        title: 'Ekspor Data Pribadi?',
        message:
            'File "$exportType" yang akan dibagikan berisi data pribadi pelanggan '
            '(nama, nomor telepon, alamat) dalam format TIDAK TERENKRIPSI.\n\n'
            'Pastikan Anda hanya membagikan file ini ke pihak yang berwenang '
            'dan menyimpannya dengan aman.\n\nLanjutkan ekspor?',
        primaryActionLabel: 'Ya, Ekspor',
        secondaryActionLabel: 'Batal',
        primaryActionColor: Colors.orange,
        onPrimaryAction: () => Navigator.of(context).pop(true),
        onSecondaryAction: () => Navigator.of(context).pop(false),
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleDeleteBackup() async {
    if (_authService.currentUser == null) {
      await _handleGoogleLogin();
    }
    if (!mounted) return;
    if (_authService.currentUser == null) return;

    final verified = await CriticalActionGuard.check(
      ref,
      context,
      CriticalActionType.manageBackup,
    );
    if (!mounted) return;
    if (!verified) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StandardDialog(
        title: 'Hapus Cadangan Cloud?',
        message:
            'Tindakan ini akan menghapus SEMUA file cadangan aplikasi Anda dari Google Drive. Data yang sudah dihapus tidak dapat dikembalikan.\n\nApakah Anda yakin?',
        primaryActionLabel: 'Hapus Semua',
        secondaryActionLabel: 'Batal',
        primaryActionColor: Colors.red,
        onPrimaryAction: () async {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          try {
            await _driveService.deleteAllBackups();
            navigator.pop();
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Semua cadangan cloud telah dihapus.'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            navigator.pop();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Gagal menghapus cadangan: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final backupState = ref.watch(backupProvider);
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Cadang & Pulihkan',
            subtitle: 'Cadangkan foto, pengaturan, dan semua catatan Anda.',
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Google Account Section ---
                  _buildSectionHeader('Akun Google'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Icon(
                            SolarIconsOutline.user,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Belum Terhubung',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user?.email ?? 'Hubungkan untuk backup Drive',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: user == null
                              ? _handleGoogleLogin
                              : () async {
                                  await _authService.signOut();
                                  setState(() {});
                                },
                          child: Text(user == null ? 'Hubungkan' : 'Putuskan'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (backupState.isUploading) ...[
                    _buildSectionHeader('Progres Cadangan'),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                backupState.statusMessage ?? 'Sedang memproses...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                '${(backupState.progress * 100).toInt()}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: backupState.progress,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _buildSectionHeader('Jadwal Otomatis'),
                  _buildFrequencySelector(settings),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Tindakan'),
                  _buildActionButton(
                    icon: SolarIconsOutline.cloudUpload,
                    label: 'Backup Sekarang',
                    subtitle: settings.lastBackupAt != null
                        ? 'Terakhir: ${settings.lastBackupAt}'
                        : 'Belum pernah',
                    isLoading: backupState.isUploading,
                    onTap: _handleManualBackup,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: SolarIconsOutline.cloudDownload,
                    label: 'Pulihkan Data Lama',
                    subtitle: 'Ambil kembali data dari cloud',
                    isLoading: false,
                    onTap: _handleManualRestore,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: SolarIconsOutline.trashBinMinimalistic,
                    label: 'Hapus Cadangan Cloud',
                    subtitle: 'Bersihkan semua data dari Drive',
                    isLoading: false,
                    onTap: _handleDeleteBackup,
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader('Ekspor Data (CSV)'),
                  _buildSecurityWarning(theme),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: SolarIconsOutline.fileText,
                    label: 'Ekspor Stok (CSV)',
                    subtitle: 'Buka daftar stok di Excel',
                    isLoading: false,
                    onTap: () async {
                      if (!mounted) return;
                      final verified = await CriticalActionGuard.check(
                        ref,
                        context,
                        CriticalActionType.manageBackup,
                      );
                      if (verified && mounted) {
                        ref.read(localBackupServiceProvider).exportToCsv('STOK');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: SolarIconsOutline.fileText,
                    label: 'Ekspor Transaksi (CSV)',
                    subtitle: 'Laporan keuangan untuk Excel',
                    isLoading: false,
                    onTap: () async {
                      if (!mounted) return;
                      final verified = await CriticalActionGuard.check(
                        ref,
                        context,
                        CriticalActionType.manageBackup,
                      );
                      if (verified && mounted) {
                        ref
                            .read(localBackupServiceProvider)
                            .exportToCsv('TRANS');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: SolarIconsOutline.fileText,
                    label: 'Ekspor Pelanggan (CSV)',
                    subtitle: 'Daftar kontak pelanggan (Excel)',
                    isLoading: false,
                    // SEC-05 FIX: Konfirmasi sebelum export data PII tanpa enkripsi
                    onTap: () async {
                      final verified = await CriticalActionGuard.check(
                        ref,
                        context,
                        CriticalActionType.manageBackup,
                      );
                      if (!mounted) return;
                      if (!verified) return;

                      final ok = await _confirmPiiExport(
                          exportType: 'Daftar Pelanggan.csv');
                      if (ok && mounted) {
                        ref
                            .read(localBackupServiceProvider)
                            .exportToCsv('PELANGGAN');
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SolarIconsOutline.danger, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hati-hati: File hasil ekspor tidak dikunci. Jaga file ini agar tidak disalahgunakan orang lain.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.amber[900],
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
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildFrequencySelector(SettingsState settings) {
    final theme = Theme.of(context);
    final frequencies = [
      {'val': 'off', 'label': 'Mati'},
      {'val': 'daily', 'label': 'Harian'},
      {'val': 'weekly', 'label': 'Mingguan'},
    ];

    return Row(
      children: frequencies.map((f) {
        final isSelected = settings.backupFrequency == f['val'];
        return Expanded(
          child: GestureDetector(
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setBackupFrequency(f['val']!),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isSelected ? 1 : 0.2,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  f['label']!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
