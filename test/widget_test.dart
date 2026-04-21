// ─────────────────────────────────────────────────────────────
// Widget Tests: ServisLog Core App
// Phase 3 — Testing
//
// Testing SettingsState without complex provider setup.
// Jalankan dengan: flutter test test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/providers/pengaturan_provider.dart';

void main() {
  group('SettingsState Tests', () {
    test('SettingsState has correct default values', () {
      final settings = SettingsState(
        workshopName: 'Bengkel Saya',
        workshopAddress: 'Jl. Merdeka No. 1',
        workshopWhatsapp: '081234567890',
        ownerName: 'Pak Budi',
        ownerPhone: '081234567890',
        themeMode: 'system',
        isDemoMode: false,
        barcodeEnabled: true,
        qrisEnabled: true,
        bengkelId: 'test-bengkel-123',
      );

      expect(settings.workshopName, 'Bengkel Saya');
      expect(settings.themeMode, 'system');
      expect(settings.barcodeEnabled, true);
      expect(settings.hasSeenOnboarding, false);
      expect(settings.autoLockDuration, 0);
    });

    test('SettingsState copyWith preserves values', () {
      final settings = SettingsState(
        workshopName: 'Bengkel Saya',
        workshopAddress: 'Jl. Merdeka No. 1',
        workshopWhatsapp: '081234567890',
        ownerName: 'Pak Budi',
        ownerPhone: '081234567890',
        themeMode: 'light',
        isDemoMode: false,
        barcodeEnabled: true,
        qrisEnabled: true,
        bengkelId: 'test-bengkel-123',
      );

      final updated = settings.copyWith(
        themeMode: 'dark',
        workshopName: 'Bengkel Baru',
      );

      expect(updated.themeMode, 'dark');
      expect(updated.workshopName, 'Bengkel Baru');
      expect(updated.barcodeEnabled, true); // preserved
      expect(updated.bengkelId, 'test-bengkel-123'); // preserved
    });

    test('SettingsState with default theme time values', () {
      final settings = SettingsState(
        workshopName: 'Test',
        workshopAddress: 'Test',
        workshopWhatsapp: '0812',
        ownerName: 'Test',
        ownerPhone: '0812',
        themeMode: 'time',
        isDemoMode: false,
        barcodeEnabled: true,
        qrisEnabled: true,
        bengkelId: '',
      );

      expect(settings.themeStartTime, '06:00');
      expect(settings.themeEndTime, '18:00');
    });

    test('SettingsState default backup frequency is off', () {
      final settings = SettingsState(
        workshopName: 'Test',
        workshopAddress: 'Test',
        workshopWhatsapp: '0812',
        ownerName: 'Test',
        ownerPhone: '0812',
        themeMode: 'system',
        isDemoMode: false,
        barcodeEnabled: true,
        qrisEnabled: true,
        bengkelId: '',
      );

      expect(settings.backupFrequency, 'off');
      expect(settings.syncWifiOnly, false);
    });
  });
}
