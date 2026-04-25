import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/firestore_sync_service.dart';
import '../../../core/services/sync_worker.dart';
import '../../../core/services/migration_service.dart';
import '../../../core/providers/objectbox_provider.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/constants/app_settings.dart';
import '../../../core/utils/app_logger.dart';

class SyncRestoreScreen extends ConsumerStatefulWidget {
  final String bengkelId;
  final VoidCallback onFinish;

  const SyncRestoreScreen({
    super.key,
    required this.bengkelId,
    required this.onFinish,
  });

  @override
  ConsumerState<SyncRestoreScreen> createState() => _SyncRestoreScreenState();
}

class _SyncRestoreScreenState extends ConsumerState<SyncRestoreScreen> {
  String _statusText = 'Menyiapkan pemulihan data...';
  double _progress = 0.1;
  bool _isError = false;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRestore();
    });
  }

  Future<void> _runPostRestoreMigrations() async {
    // Cek apakah migrasi sudah pernah dijalankan
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(AppSettings.migrationV122ServiceMasterName) ?? false;
    
    if (alreadyMigrated) {
      appLogger.info('Migration v1.2.2 already completed', 
          context: 'SyncRestoreScreen');
      return;
    }
    
    setState(() {
      _statusText = 'Memigrasi data service...';
      _progress = 0.92;
    });
    
    try {
      final migrationService = MigrationService(
        firestore: ref.read(firestoreProvider),
        encryption: ref.read(encryptionServiceProvider),
      );
      
      final result = await migrationService.migrateServiceMasterNameEncryption(
        widget.bengkelId,
      );
      
      appLogger.info('Migration completed: ${result.successCount}/${result.totalProcessed} success', 
          context: 'SyncRestoreScreen');
      
      // Tandai migrasi selesai (walaupun ada kegagalan parsial)
      await prefs.setBool(AppSettings.migrationV122ServiceMasterName, true);
      
      if (result.failedCount > 0) {
        appLogger.warning('Migration partial failure: ${result.failedCount} items failed',
            context: 'SyncRestoreScreen');
      }
      
    } catch (e) {
      // NON-FATAL: migrasi gagal, restore tetap dianggap selesai
      appLogger.error('Migration failed, but restore continues', 
          context: 'SyncRestoreScreen', error: e);
      // JANGAN set flag agar dicoba ulang di lain waktu
    }
  }

  Future<void> _startRestore() async {
    // Reset state agar UI kembali ke loading saat "Coba Lagi" ditekan
    setState(() {
      _isError = false;
      _errorDetail = '';
      _statusText = 'Menyiapkan pemulihan data...';
      _progress = 0.1;
    });

    try {
      final syncService = FirestoreSyncService(
        firestore: ref.read(firestoreProvider),
        encryption: ref.read(encryptionServiceProvider),
      );
      final encryption = ref.read(encryptionServiceProvider);
      final db = ref.read(dbProvider);

      // Guard: Pastikan EncryptionService sudah siap sebelum menarik data
      // terenkripsi dari Firestore. Coba init ulang dulu sebelum throw.
      if (!encryption.isInitialized) {
        setState(() {
          _statusText = 'Mempersiapkan kunci enkripsi...';
          _progress = 0.15;
        });
        await encryption.init();
        if (!encryption.isInitialized) {
          appLogger.warning('Encryption not ready during restore, attempting init...', context: 'SyncRestoreScreen');
          await encryption.init();
        }
        
        if (!encryption.isInitialized) {
          throw Exception(
            'Kunci enkripsi tidak tersedia (Session Expired). Silakan logout dan login kembali untuk memulihkan kunci.',
          );
        }
      }
      
      setState(() {
        _statusText = 'Mengunduh data dari Cloud...';
        _progress = 0.3;
      });

      // 1. Pull everything
      final allData = await syncService.pullAllData(widget.bengkelId);
      
      setState(() {
        _statusText = 'Membangun ulang database lokal...';
        _progress = 0.7;
      });

      // 2. Perform reconstruction
      final worker = SyncWorker(
        db: db,
        syncService: syncService,
        sessionManager: ref.read(sessionManagerProvider),
        bengkelId: widget.bengkelId,
      );

      await worker.syncDownAll(allData, forceOverwrite: true); // ← pake forceOverwrite
      
      // FIX: Jalankan post-restore migration
      await _runPostRestoreMigrations();

      if (mounted) {
        setState(() {
          _statusText = 'Pemulihan selesai! Sedang menyiapkan dashboard...';
          _progress = 1.0;
        });
      }

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        widget.onFinish();
      }
    } catch (e) {
      appLogger.error('Restore Error', context: 'SyncRestoreScreen', error: e);
      if (mounted) {
        setState(() {
          _isError = true;
          _statusText = 'Gagal memulihkan data.';
          _errorDetail = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon or Animation
                _isError 
                  ? Icon(Icons.error_outline, size: 80, color: Theme.of(context).colorScheme.error)
                  : SizedBox(
                      height: 200,
                      child: Lottie.network(
                        'https://assets10.lottiefiles.com/packages/lf20_at6mdfbe.json', // Cloud Sync Animation
                        errorBuilder: (context, error, stack) => Icon(
                          Icons.cloud_download_rounded, 
                          size: 80, 
                          color: Theme.of(context).colorScheme.primary
                        ),
                      ),
                    ),
                const SizedBox(height: 40),
                Text(
                  'Pemulihan Data',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                  ),
                ),
                if (_isError && _errorDetail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorDetail,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                if (!_isError) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                if (_isError) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _startRestore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onFinish,
                    child: const Text('Lewati (Mulai dengan data kosong)'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

