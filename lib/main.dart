import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/providers/objectbox_provider.dart';
import 'core/providers/system_providers.dart';
import 'core/providers/pengaturan_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/inactivity_monitor_provider.dart';
import 'core/constants/app_theme.dart';
import 'core/models/user_profile.dart';
import 'features/main/adaptive_layout.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_intro_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/unlock_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'core/services/encryption_service.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'core/sync/sync_telemetry.dart';
import 'core/utils/app_logger.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ── Edge-to-Edge Support ──
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );

  await initializeDateFormatting('id_ID', null);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Sync Telemetry
  final deviceId = await _getDeviceId();
  SyncTelemetry().initialize(
    [
      FirebaseTelemetrySink(),
      LocalFileTelemetrySink(),
    ],
    deviceId: deviceId,
  );

  // Initialize Shared Preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Encryption
  await EncryptionService().init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: Phoenix(
        child: const MainApp(),
      ),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  Timer? _themeTimer;

  @override
  void initState() {
    super.initState();
    // UX-09 FIX: Optimasi update tema otomatis.
    // Menggunakan timer yang ditargetkan tepat pada saat transisi (06:00 & 18:00)
    // untuk menghemat CPU cycle dibandingkan Timer.periodic per jam.
    _setupThemeUpdateTimer();

    // ✅ FIX #2: InactivityMonitor dii-nisialisasi sekali di initState,
    // bukan di build() agar tidak di-panggil setiap rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inactivityMonitorProvider).start();
    });
  }

  void _setupThemeUpdateTimer() {
    _themeTimer?.cancel();
    
    final now = DateTime.now();
    DateTime nextTransition;
    
    // Titik transisi: 06:00 (Siang) dan 18:00 (Malam) - menyesuaikan SettingsState default
    if (now.hour < 6) {
      nextTransition = DateTime(now.year, now.month, now.day, 6);
    } else if (now.hour < 18) {
      nextTransition = DateTime(now.year, now.month, now.day, 18);
    } else {
      nextTransition = DateTime(now.year, now.month, now.day + 1, 6);
    }
    
    final duration = nextTransition.difference(now);
    
    // Beri buffer sedikit agar transisi waktu sistem sudah benar-benar lewat
    _themeTimer = Timer(duration + const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {}); // Trigger rebuild untuk update tema
        _setupThemeUpdateTimer(); // Jadwalkan untuk transisi berikutnya
      }
    });
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    final settings = ref.watch(settingsProvider);

    ThemeMode mode;
    switch (settings.themeMode) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'time':
        final now = DateTime.now();
        final currentMinutes = now.hour * 60 + now.minute;

        final startParts = settings.themeStartTime.split(':');
        final endParts = settings.themeEndTime.split(':');

        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes =
            int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        if (startMinutes < endMinutes) {
          // Standard range (e.g., 06:00 - 18:00)
          mode = (currentMinutes >= startMinutes && currentMinutes < endMinutes)
              ? ThemeMode.light
              : ThemeMode.dark;
        } else {
          // Overlap midnight (e.g., 20:00 - 06:00 means light from 20 to 06)
          mode = (currentMinutes >= startMinutes || currentMinutes < endMinutes)
              ? ThemeMode.light
              : ThemeMode.dark;
        }
        break;
      default:
        mode = ThemeMode.system;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ServisLog+',
      theme: AppTheme.modernSiang,
      darkTheme: AppTheme.modernMalam,
      themeMode: mode,
      home: const AuthGate(),
      // Text scale factor clamping for accessibility (WCAG compliant)
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

/// AuthGate — routing berdasarkan auth state.
/// unauthenticated → LoginScreen
/// missingProfile  → OnboardingScreen
/// authenticated   → MainScreen
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(dbInstanceProvider);
    final authAsync = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider);

    // Ensure database is ready first
    if (dbAsync.isLoading) {
      return const SplashScreen();
    }

    if (dbAsync.hasError) {
      return _buildErrorScreen(context, dbAsync.error!);
    }

    return authAsync.when(
      skipLoadingOnReload: false,
      data: (container) {
        switch (container.state) {
          case AuthState.unauthenticated:
            if (!settings.hasSeenOnboarding) {
              return const OnboardingIntroScreen();
            }
            return const LoginScreen();
          case AuthState.authenticating:
            return const SplashScreen();
          case AuthState.missingProfile:
            return const OnboardingScreen();
          case AuthState.authenticated:
            final bengkelId = container.profile?.bengkelId;
            final encryption = EncryptionService();
            if (bengkelId != null && !encryption.isInitialized) {
              return UnlockScreen(
                bengkelId: bengkelId,
                onUnlocked: () async {
                  // Re-initialize encryption context and trigger reload
                  await encryption.init();
                  if (context.mounted) {
                    ref.invalidate(authStateProvider);
                  }
                },
              );
            }
            return const MainScreen();
        }
      },
      loading: () => const SplashScreen(),
      error: (e, st) => _buildErrorScreen(context, e),
    );
  }

  Widget _buildErrorScreen(BuildContext context, Object error) {
    // ✅ FIX #3: Tampilkan pesan ramah user, bukan raw exception string.
    // Detail error tetap dicetak ke console untuk debugging.
    appLogger.error('AuthGate Error', error: error);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              Text(
                'Gagal Memuat Aplikasi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Terjadi masalah saat memulai. Silakan restart aplikasi.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Phoenix.rebirth(context),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Restart Aplikasi'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper for SyncTelemetry device mapping.
Future<String> _getDeviceId() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return 'android_${androidInfo.id}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return 'ios_${iosInfo.identifierForVendor}';
    }
    return 'unknown_${DateTime.now().millisecondsSinceEpoch}';
  } catch (_) {
    return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
  }
}
