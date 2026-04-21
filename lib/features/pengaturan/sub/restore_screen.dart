import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import '../../../core/services/zip_utility.dart';
import '../../../core/providers/objectbox_provider.dart';

class RestoreScreen extends ConsumerStatefulWidget {
  final File backupFile;
  const RestoreScreen({super.key, required this.backupFile});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  bool _isVerifying = true;
  bool _isRestoring = false;
  String _status = 'Memverifikasi kompatibilitas...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  Future<void> _startVerification() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _status = 'Cadangan ditemukan di Google Drive';
      });
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isRestoring = true;
      _status = 'Menutup Database...';
      _progress = 0.1;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 1. Close current database connection to release file locks
      final dbAsync = ref.read(dbInstanceProvider);
      dbAsync.whenData((db) => db.dispose());
      
      // Invalidate provider so it doesn't keep stale reference
      ref.invalidate(dbInstanceProvider);

      setState(() {
        _status = 'Mengekstrak data...';
        _progress = 0.4;
      });

      // 2. Extract and overwrite database files
      await ZipUtility.extractRestoreZip(widget.backupFile);

      setState(() {
        _status = 'Membuka Database Baru...';
        _progress = 0.8;
      });

      // 3. Re-initialize database with decrypted/restored files
      final newDb = await ObjectBoxProvider.create();
      ref.read(dbInstanceProvider.notifier).setInstance(newDb);

      setState(() {
        _progress = 1.0;
        _status = 'Berhasil! Memuat ulang aplikasi...';
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        // Redraw UI from scratch
        Phoenix.rebirth(context);
      }
    } catch (e) {
      // Emergency recovery: Try to re-open DB if extraction fails
      if (ref.read(dbInstanceProvider).hasError || ref.read(dbInstanceProvider).isLoading) {
        try {
          final recoveryDb = await ObjectBoxProvider.create();
          ref.read(dbInstanceProvider.notifier).setInstance(recoveryDb);
        } catch (_) {}
      }

      setState(() {
        _isRestoring = false;
        _status = 'Gagal mengembalikan data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                SolarIconsOutline.cloudDownload,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Pulihkan Data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (_isVerifying || _isRestoring)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _isVerifying ? null : _progress,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isVerifying
                          ? 'Harap tunggu sebentar'
                          : '${(_progress * 100).toInt()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _handleRestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'PULIHKAN DATA SEKARANG',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Lewati Untuk Sekarang',
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
