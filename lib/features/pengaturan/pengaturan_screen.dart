import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_icons.dart';
import '../../core/providers/pengaturan_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import './sub/profil_screen.dart';
import './sub/tampilan_screen.dart';
import './sub/backup_screen.dart';
import './sub/sync_settings_screen.dart';
import './sub/teknisi_screen.dart';
import './sub/fitur_screen.dart';
import './sub/tentang_screen.dart';
import './sub/faq_screen.dart';
import './sub/security_data_center_screen.dart';
import '../../core/widgets/atelier_header.dart';
import '../../core/widgets/atelier_list_card.dart';

class PengaturanScreen extends ConsumerWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Pengaturan',
            subtitle: 'Kelola akun, data, dan preferensi aplikasi.',
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AtelierListGroup(
                  label: 'Akun & Keamanan',
                  children: [
                    AtelierListTile(
                      icon: AppIcons.profile,
                      iconColor: Colors.blue,
                      title: 'Profil & Bengkel',
                      subtitle: settings.workshopName,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilScreen()),
                      ),
                    ),
                    AtelierListTile(
                      icon: LucideIcons.shieldCheck,
                      iconColor: Colors.greenAccent,
                      title: 'Pusat Keamanan & Data',
                      subtitle: 'Proteksi Shield v2.0 & Sync v1.4',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SecurityDataCenterScreen()),
                      ),
                    ),
                  ],
                ),
                AtelierListGroup(
                  label: 'Data & Sinkronisasi',
                  children: [
                    AtelierListTile(
                      icon: Icons.backup_outlined,
                      iconColor: Colors.indigo,
                      title: 'Backup & Restore',
                      subtitle: settings.lastBackupAt == null
                          ? 'Belum pernah backup'
                          : 'Terakhir: ${settings.lastBackupAt}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BackupScreen()),
                      ),
                    ),
                    AtelierListTile(
                      icon: Icons.sync_rounded,
                      iconColor: Colors.blue,
                      title: 'Sinkronisasi Cloud',
                      subtitle: settings.bengkelId.isEmpty
                          ? 'Hubungkan ke Cloud'
                          : 'Status: Sinkron',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
                      ),
                    ),
                  ],
                ),
                AtelierListGroup(
                  label: 'Operasional',
                  children: [
                    AtelierListTile(
                      icon: AppIcons.service,
                      iconColor: Colors.blueGrey,
                      title: 'Daftar Teknisi',
                      subtitle: 'Kelola tim teknisi',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeknisiScreen()),
                      ),
                    ),
                    AtelierListTile(
                      icon: Icons.extension_outlined,
                      iconColor: Colors.purple,
                      title: 'Fitur Tambahan',
                      subtitle: settings.barcodeEnabled ? 'Barcode Aktif' : 'Opsi tambahan',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FiturScreen()),
                      ),
                    ),
                    AtelierSwitchTile(
                      icon: Icons.bug_report_outlined,
                      iconColor: Colors.orange,
                      title: 'Mode Demo',
                      subtitle: 'Tandai data sebagai latihan',
                      value: settings.isDemoMode,
                      onChanged: (v) => ref.read(settingsProvider.notifier).setDemoMode(v),
                    ),
                  ],
                ),
                AtelierListGroup(
                  label: 'Aplikasi',
                  children: [
                    AtelierListTile(
                      icon: AppIcons.appearance,
                      iconColor: Colors.pink,
                      title: 'Tampilan',
                      subtitle: settings.themeMode[0].toUpperCase() + settings.themeMode.substring(1).toLowerCase(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TampilanScreen()),
                      ),
                    ),
                    AtelierListTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: Colors.orange,
                      title: 'Bantuan & FAQ',
                      subtitle: 'Pusat solusi & panduan',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FAQScreen()),
                      ),
                    ),
                    AtelierListTile(
                      icon: Icons.info_outline,
                      iconColor: Colors.grey,
                      title: 'Tentang ServisLog',
                      subtitle: 'Versi 1.0.0',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TentangScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

}



