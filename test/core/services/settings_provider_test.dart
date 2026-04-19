import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servislog_core/core/providers/pengaturan_provider.dart';
import 'package:servislog_core/core/providers/system_providers.dart';
import 'package:servislog_core/core/constants/app_settings.dart';
import '../../helpers/test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppSettings.workshopName: 'Bengkel Test',
      AppSettings.isBiometricEnabled: true,
    });
    final prefs = await SharedPreferences.getInstance();

    container = createContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  group('Settings Provider Tests', () {
    test('Initial state should load from SharedPreferences', () {
      final state = container.read(settingsProvider);
      expect(state.workshopName, 'Bengkel Test');
      expect(state.isBiometricEnabled, true);
    });

    test('updateWorkshopInfo should update state and SharedPreferences', () async {
      await container.read(settingsProvider.notifier).updateWorkshopInfo(
        name: 'Bengkel Maju',
        address: 'Jl. Test No. 1',
      );
      
      final state = container.read(settingsProvider);
      expect(state.workshopName, 'Bengkel Maju');
      expect(state.workshopAddress, 'Jl. Test No. 1');
      
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(AppSettings.workshopName), 'Bengkel Maju');
      expect(prefs.getString(AppSettings.workshopAddress), 'Jl. Test No. 1');
    });

    test('setMonthlyTarget should clamp value', () async {
      // monthly_target clamped to [10000, 999999999] in provider
      await container.read(settingsProvider.notifier).setMonthlyTarget(5000);
      expect(container.read(settingsProvider).monthlyTarget, 10000);
      
      await container.read(settingsProvider.notifier).setMonthlyTarget(25000000);
      expect(container.read(settingsProvider).monthlyTarget, 25000000);
    });

    test('setThemeMode should persist value', () async {
      await container.read(settingsProvider.notifier).setThemeMode('malam');
      expect(container.read(settingsProvider).themeMode, 'malam');
      
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(AppSettings.themeMode), 'malam');
    });
  });
}
