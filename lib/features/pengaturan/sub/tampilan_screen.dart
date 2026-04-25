import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/widgets/atelier_header.dart';
import '../../../core/widgets/atelier_list_card.dart';

class TampilanScreen extends ConsumerWidget {
  const TampilanScreen({super.key});

  Future<void> _selectTime(
      BuildContext context, WidgetRef ref, bool isStart) async {
    final settings = ref.read(settingsProvider);
    final currentTimeStr =
        isStart ? settings.themeStartTime : settings.themeEndTime;
    final parts = currentTimeStr.split(':');
    final time =
        TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: time,
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        await ref.read(settingsProvider.notifier).setThemeStartTime(formatted);
      } else {
        await ref.read(settingsProvider.notifier).setThemeEndTime(formatted);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final currentMode = settings.themeMode;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Kustomisasi Tema',
            subtitle: 'Personalisasi tampilan aplikasi sesuai selera Anda.',
            showBackButton: true,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              AtelierListGroup(
                label: 'Sistem Tema',
                children: [
                  _ThemeTile(
                    title: 'Terang',
                    icon: SolarIconsOutline.sun,
                    isSelected: currentMode == 'light',
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode('light'),
                  ),
                  _ThemeTile(
                    title: 'Gelap',
                    icon: SolarIconsOutline.moon,
                    isSelected: currentMode == 'dark',
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode('dark'),
                  ),
                  _ThemeTile(
                    title: 'Otomatis (Ikuti Sistem)',
                    icon: SolarIconsOutline.settings,
                    isSelected: currentMode == 'system',
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode('system'),
                  ),
                  _ThemeTile(
                    title: 'Berdasarkan Waktu',
                    icon: SolarIconsOutline.clockCircle,
                    isSelected: currentMode == 'time',
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode('time'),
                  ),
                ],
              ),
              if (currentMode == 'time')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AtelierListGroup(
                    label: 'Jadwal Tema Terang',
                    children: [
                      AtelierListTile(
                        icon: SolarIconsOutline.sunrise,
                        iconColor: Colors.orange,
                        title: 'Mulai',
                        subtitle: 'Pindah ke mode terang pada jam ini',
                        trailing: Text(
                          settings.themeStartTime,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        onTap: () => _selectTime(context, ref, true),
                      ),
                      AtelierListTile(
                        icon: SolarIconsOutline.sunset,
                        iconColor: Colors.deepPurple,
                        title: 'Selesai',
                        subtitle: 'Pindah ke mode gelap kembali pada jam ini',
                        trailing: Text(
                          settings.themeEndTime,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        onTap: () => _selectTime(context, ref, false),
                      ),
                    ],
                  ),
                ),
              AtelierListGroup(
                label: 'Desain Visual',
                children: [
                  AtelierSwitchTile(
                    icon: SolarIconsOutline.globus,
                    iconColor: Colors.blue,
                    title: 'Aktifkan Animasi',
                    subtitle: 'Gunakan transisi halus antar layar',
                    value: true,
                    onChanged: (v) {},
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

