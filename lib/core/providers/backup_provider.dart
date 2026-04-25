import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/drive_backup_service.dart';
import '../services/auth_service.dart';
import 'pengaturan_provider.dart';
import '../utils/app_logger.dart';

class BackupState {
  final bool isUploading;
  final double progress; // 0.0 to 1.0
  final String? statusMessage;
  final String? error;
  final DateTime? lastAttempt;

  BackupState({
    this.isUploading = false,
    this.progress = 0.0,
    this.statusMessage,
    this.error,
    this.lastAttempt,
  });

  BackupState copyWith({
    bool? isUploading,
    double? progress,
    String? statusMessage,
    String? error,
    DateTime? lastAttempt,
  }) {
    return BackupState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final Ref _ref;
  final DriveBackupService _driveService = DriveBackupService();
  final AuthService _authService = AuthService();

  BackupNotifier(this._ref) : super(BackupState());

  /// Checks if an auto-backup is required based on frequency and last backup time.
  Future<void> checkAndRunAutoBackup() async {
    final settings = _ref.read(settingsProvider);
    if (settings.backupFrequency == 'off') return;

    // UX-08 FIX: Gunakan signInSilently() — tidak menampilkan dialog Google
    // Sign-In secara tiba-tiba saat app sedang digunakan. Jika silent sign-in
    // gagal (token kedaluwarsa, belum pernah sign-in), skip auto-backup dan
    // catat di log — jangan trigger interactive flow secara otomatis.
    if (_authService.currentUser == null) {
      try {
        final result = await _authService.signInSilently();
        if (result == null) {
          appLogger.info('Auto-backup dilewati — silent sign-in gagal (user perlu login manual)', context: 'BackupProvider');
          return;
        }
      } catch (_) {
        return; // Skip auto-backup jika tidak bisa silent auth
      }
    }

    final lastBackup = settings.lastBackupTimestamp;
    final now = DateTime.now().millisecondsSinceEpoch;

    bool shouldBackup = false;
    if (lastBackup == null) {
      shouldBackup = true;
    } else {
      final diff = now - lastBackup;
      const dayInMillis = 24 * 60 * 60 * 1000;

      if (settings.backupFrequency == 'daily' && diff >= dayInMillis) {
        shouldBackup = true;
      } else if (settings.backupFrequency == 'weekly' &&
          diff >= 7 * dayInMillis) {
        shouldBackup = true;
      }
    }

    if (shouldBackup) {
      await runBackup();
    }
  }

  /// Manually trigger a backup.
  Future<void> runBackup() async {
    state = state.copyWith(
      isUploading: true,
      progress: 0.1,
      statusMessage: 'Menyiapkan data...',
      error: null,
    );

    try {
      // 1. Check Auth
      if (_authService.currentUser == null) {
        state = state.copyWith(statusMessage: 'Menghubungkan ke Google...');
        await _authService.signIn();
      }

      state = state.copyWith(progress: 0.3, statusMessage: 'Mengompresi data...');
      // 2. Upload with progress update via delay or better logic if available
      // For now, we manually step through known phases
      await _driveService.uploadBackup();

      state = state.copyWith(progress: 0.8, statusMessage: 'Sinkronisasi selesai...');
      await _ref.read(settingsProvider.notifier).updateLastBackup();

      state = state.copyWith(
        isUploading: false,
        progress: 1.0,
        statusMessage: 'Backup berhasil diunggah!',
        lastAttempt: DateTime.now(),
      );
    } catch (e) {
      String errorMessage = 'Terjadi kesalahan saat backup';
      if (e.toString().contains('network') || e.toString().contains('SocketException')) {
        errorMessage = 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
      } else if (e.toString().contains('quota')) {
        errorMessage = 'Penyimpanan Google Drive penuh.';
      }

      state = state.copyWith(
        isUploading: false,
        progress: 0.0,
        statusMessage: null,
        error: errorMessage,
        lastAttempt: DateTime.now(),
      );
      rethrow;
    }
  }
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((
  ref,
) {
  return BackupNotifier(ref);
});

