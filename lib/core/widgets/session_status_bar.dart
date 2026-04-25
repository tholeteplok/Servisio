// 📊 ServisLog+ Hybrid Security Policy — Session Status Bar
// Visual indicator untuk status sesi (Tiga Zona)
// Green (Zone 1), Yellow/Orange (Zone 2), Red (Zone 3)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_manager.dart';
import '../providers/system_providers.dart';

// 📊 Status Configuration Model
class StatusConfig {
  final Color color;
  final String label;
  final IconData icon;
  final String description;
  
  const StatusConfig({
    required this.color,
    required this.label,
    required this.icon,
    required this.description,
  });
}

// 🛡️ Session Status Bar Widget
class SessionStatusBar extends ConsumerWidget {
  const SessionStatusBar({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessLevel = ref.watch(currentAccessLevelProvider);
    
    if (accessLevel == AccessLevel.full) return const SizedBox.shrink();
    
    final config = _getStatusConfig(accessLevel);
    
    return GestureDetector(
      onTap: () => _showStatusDetails(context, config, accessLevel),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: config.color.withValues(alpha: 0.1),
        child: Row(
          children: [
            Icon(config.icon, color: config.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                config.description,
                style: TextStyle(
                  color: config.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: config.color, size: 20),
          ],
        ),
      ),
    );
  }
  
  StatusConfig _getStatusConfig(AccessLevel level) {
    switch (level) {
      case AccessLevel.full:
        return const StatusConfig(
          color: Colors.green,
          label: 'Sesi Aktif',
          icon: Icons.check_circle,
          description: 'Sesi valid — Akses penuh tersedia.',
        );
      case AccessLevel.readOnly:
        return const StatusConfig(
          color: Colors.amber,
          label: 'Mode Baca Saja',
          icon: Icons.visibility,
          description: 'Offline > 8 jam — Perlu koneksi untuk edit data.',
        );
      case AccessLevel.readOnlyFinancial:
        return const StatusConfig(
          color: Colors.orange,
          label: 'Akses Terbatas',
          icon: Icons.warning_amber_rounded,
          description: 'Offline > 12 jam — Fitur keuangan dibatasi.',
        );
      case AccessLevel.blocked:
        return const StatusConfig(
          color: Colors.red,
          label: 'Sesi Kedaluwarsa',
          icon: Icons.lock_clock,
          description: 'Sesi habis — Hubungkan internet untuk lanjut.',
        );
    }
  }
  
  void _showStatusDetails(BuildContext context, StatusConfig config, AccessLevel level) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(config.icon, color: config.color, size: 32),
                const SizedBox(width: 16),
                Text(
                  config.label,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getLongDescription(level),
              style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Trigger reauth flow logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hubungkan & Perbarui Sesi'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getLongDescription(AccessLevel level) {
    switch (level) {
      case AccessLevel.full:
        return 'Aplikasi berjalan normal dengan akses penuh ke semua fitur.';
      case AccessLevel.readOnly:
        return 'Perangkat telah offline lebih dari 8 jam. Untuk keamanan data, Anda hanya diperbolehkan membaca data sampai sesi diperbarui secara online.';
      case AccessLevel.readOnlyFinancial:
        return 'Perangkat telah offline lebih dari 12 jam (Owner). Fitur laporan keuangan dan edit biaya lunas dibatasi sementara.';
      case AccessLevel.blocked:
        return 'Sesi keamanan Anda telah berakhir karena perangkat offline terlalu lama (> 24 jam). Silakan hubungkan ke internet untuk melakukan verifikasi ulang.';
    }
  }
}

