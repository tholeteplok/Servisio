import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/sync_worker.dart';
import '../../../core/services/migration_service.dart';
import '../../../core/providers/objectbox_provider.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/providers/pelanggan_provider.dart';
import '../../../core/providers/stok_provider.dart';
import '../../../core/providers/master_providers.dart';
import '../../../core/providers/sale_providers.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/stats_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/constants/app_settings.dart';
import '../../../core/widgets/pin_verify_dialog.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_icons.dart';

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
  bool _isStarted = false;
  String _statusText = '';
  double _progress = 0.0;
  bool _isError = false;
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    appLogger.info('=== SyncRestoreScreen INIT ===', context: 'SyncRestoreScreen');
    appLogger.info('bengkelId: ${widget.bengkelId}', context: 'SyncRestoreScreen');
    // 🎯 TAHAP 4.1: Jangan panggil _startRestore otomatis.
    // Tunggu input user dari tombol "Mulai Pemulihan".
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

  String _getCollectionLabel(String collection) {
    switch (collection) {
      case 'staff': return AppStrings.sync.restoringStaff;
      case 'customers': return AppStrings.sync.restoringCustomers;
      case 'vehicles': return AppStrings.sync.restoringVehicles;
      case 'inventory': return AppStrings.sync.restoringInventory;
      case 'service_master': return AppStrings.sync.restoringServiceMaster;
      case 'transactions': return AppStrings.sync.restoringTransactions;
      case 'inventory_history': return AppStrings.sync.restoringInventoryHistory;
      case 'sales': return AppStrings.sync.restoringSales;
      case 'expenses': return AppStrings.sync.restoringExpenses;
      case 'relinking': return AppStrings.sync.connectingRelations;
      case 'complete': return AppStrings.sync.syncComplete;
      default: return AppStrings.sync.restoreDownloading;
    }
  }

  Future<void> _startRestore() async {
    appLogger.info('=== _startRestore CALLED ===', context: 'SyncRestoreScreen');
    
    // Reset state agar UI kembali ke loading
    setState(() {
      _isStarted = true;
      _isError = false;
      _errorDetail = '';
      _statusText = AppStrings.sync.restoreStarting;
      _progress = 0.05;
    });

    bool dataDownloaded = false;

    try {
      final syncService = ref.read(firestoreSyncServiceProvider);
      final encryption = ref.read(encryptionServiceProvider);
      final db = ref.read(dbProvider);
      final sessionManager = ref.read(sessionManagerProvider);

      appLogger.info('Step 1: Checking encryption...', context: 'SyncRestoreScreen');
      // Guard: Pastikan EncryptionService sudah siap
      if (!encryption.isInitialized) {
        appLogger.info('Encryption not initialized, initializing...', context: 'SyncRestoreScreen');
        setState(() {
          _statusText = AppStrings.sync.preparingEncryption;
          _progress = 0.1;
        });
        
        await encryption.init();
        
        if (!encryption.isInitialized) {
          appLogger.info('Encryption key missing after reinstall, attempting recovery from Cloud...', 
              context: 'SyncRestoreScreen');
          
          final bengkelService = ref.read(bengkelServiceProvider);
          final wrappedKey = await bengkelService.getWrappedMasterKey(widget.bengkelId);
          
          if (wrappedKey == null) {
            throw Exception('Bengkel ID tidak valid atau tidak memiliki Master Key di Cloud.');
          }

          if (mounted) {
            final pin = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) => PinVerifyDialog(
                bengkelId: widget.bengkelId,
                onVerified: (pin) => Navigator.pop(context, pin),
                title: 'Pemulihan Kunci',
                subtitle: 'Masukkan PIN Workshop untuk memulihkan akses data.',
              ),
            );

            if (pin == null) {
              setState(() => _isStarted = false); // Kembali ke awal
              return;
            }

            if (!encryption.isInitialized) {
              throw Exception('Gagal menginisialisasi kunci enkripsi setelah verifikasi PIN.');
            }
          }
        }
      }
      
      appLogger.info('Encryption initialized: ${encryption.isInitialized}', 
          context: 'SyncRestoreScreen');
      
      setState(() {
        _statusText = 'Menghubungkan ke workshop...';
        _progress = 0.15;
      });
      
      appLogger.info('Step 2: Loading workshops...', context: 'SyncRestoreScreen');
      await sessionManager.loadWorkshops();
      
      if (sessionManager.activeWorkshopOwnerId == null) {
        await sessionManager.resolveAndSelectWorkshop(widget.bengkelId);
      }

      setState(() {
        _statusText = 'Mengunduh data dari Cloud...';
        _progress = 0.2;
      });

      // 1. Pull everything
      appLogger.info('=== Step 3: Starting pullAllData for bengkelId: ${widget.bengkelId} ===', 
          context: 'SyncRestoreScreen');
      
      final allData = await syncService.pullAllData(widget.bengkelId);
      dataDownloaded = true;
      
      setState(() {
        _statusText = 'Membangun ulang database lokal...';
        _progress = 0.3;
      });

      // 2. Perform granular reconstruction
      appLogger.info('Step 4: Calling granular syncDownAll...', context: 'SyncRestoreScreen');
      
      final worker = SyncWorker(
        db: db,
        syncService: syncService,
        sessionManager: ref.read(sessionManagerProvider),
        bengkelId: widget.bengkelId,
      );

      await worker.syncDownAll(
        allData, 
        forceOverwrite: true,
        onProgress: (collection, subProgress) {
          if (mounted) {
            setState(() {
              _statusText = _getCollectionLabel(collection);
              // Scale worker progress (0.0 - 1.0) to range (0.3 - 0.9)
              _progress = 0.3 + (subProgress * 0.6);
            });
          }
        },
      );
      
      // Post-restore migration
      appLogger.info('Step 5: Running post-restore migrations...', context: 'SyncRestoreScreen');
      setState(() {
        _statusText = 'Memigrasi data layanan...';
        _progress = 0.92;
      });
      await _runPostRestoreMigrations();

      // Finalizing & Invalidation
      appLogger.info('Step 6: Finalizing & Invalidation...', context: 'SyncRestoreScreen');
      setState(() {
        _statusText = 'Menyiapkan dashboard...';
        _progress = 0.95;
      });

      // Invalidate providers
      ref.invalidate(pelangganListProvider);
      ref.invalidate(stokListProvider);
      ref.invalidate(serviceMasterListProvider);
      ref.invalidate(staffListProvider);
      ref.invalidate(vehicleListProvider);
      ref.invalidate(saleListProvider);
      ref.invalidate(transactionListProvider);
      ref.invalidate(syncQueueSummaryProvider);
      ref.invalidate(expenseListProvider(widget.bengkelId));
      ref.invalidate(statsProvider);

      if (mounted) {
        setState(() {
          _statusText = 'Pemulihan selesai!';
          _progress = 1.0;
        });
      }

      appLogger.info('=== RESTORE COMPLETE — Updating lastSyncTime ===', context: 'SyncRestoreScreen');
      await ref.read(settingsProvider.notifier).updateLastSyncTime();
      await ref.read(settingsProvider.notifier).setRestoreCompleted(true);
      
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        widget.onFinish();
      }
    } catch (e, stack) {
      appLogger.error('=== RESTORE ERROR ===', context: 'SyncRestoreScreen', error: e);
      appLogger.error('Stack trace: $stack', context: 'SyncRestoreScreen');
      if (mounted) {
        setState(() {
          _isError = true;
          _statusText = 'Gagal memulihkan data.';
          _errorDetail = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      // SAFETY NET: Jika data sudah berhasil diunduh dari cloud,
      // tandai restorasi selesai agar user tidak terjebak loop dialog.
      // Data mungkin tidak sempurna, tapi loop lebih berbahaya.
      if (dataDownloaded) {
        try {
          final notifier = ref.read(settingsProvider.notifier);
          await notifier.setRestoreCompleted(true);
          await notifier.updateLastSyncTime();
          appLogger.info(
            'SAFETY NET: isRestoreCompleted set to true (dataDownloaded=$dataDownloaded)',
            context: 'SyncRestoreScreen',
          );
        } catch (_) {
          // Last resort — jangan biarkan error di sini menghancurkan flow
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0D0B14), const Color(0xFF1A1528)]
                : [const Color(0xFFF3EEFF), const Color(0xFFE8DEFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isStarted) ...[
                  // 🏁 Initial State: Prompt Restore
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.syncRestore,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Satu Langkah Lagi',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1528),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kami menemukan data Anda di Cloud. Ingin memulihkan riwayat transaksi, stok, dan pelanggan sekarang?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _startRestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Mulai Pemulihan',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await ref.read(settingsProvider.notifier).setRestoreCompleted(true);
                      widget.onFinish();
                    },
                    child: Text(
                      'Lewati untuk Sekarang',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ] else if (_isError) ...[
                  // ❌ Error State
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 80,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ups! Ada Masalah',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorDetail,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _startRestore,
                    child: Text(AppStrings.sync.tryAgain),
                  ),
                ] else ...[
                  // ⏳ Progress State
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/illustrations/onboarding_sync.png',
                          width: 200,
                          opacity: const AlwaysStoppedAnimation(0.8),
                        ),
                        CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 4,
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _statusText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.sync.dontCloseApp,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
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

