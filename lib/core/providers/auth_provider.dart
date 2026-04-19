import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/bengkel_service.dart';
import '../services/encryption_service.dart';
import '../services/device_session_service.dart';
import '../models/user_profile.dart';
import 'sync_provider.dart';
import 'pengaturan_provider.dart';
import '../services/session_manager.dart';
import '../constants/app_settings.dart';

// ===== Service Providers =====

final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    ));

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider), // From session_manager.dart or defined here
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

final bengkelServiceProvider = Provider<BengkelService>(
  (ref) => BengkelService(),
);

// ===== Auth State Provider =====

/// Container untuk hold auth state + user + profile.
class AuthStateContainer {
  final AuthState state;
  final User? user;
  final UserProfile? profile;
  // UX-03: Flag untuk membedakan error jaringan vs genuinely unauthenticated
  final bool isError;
  final String? errorMessage;

  AuthStateContainer({
    required this.state,
    this.user,
    this.profile,
    this.isError = false,
    this.errorMessage,
  });

  bool get isAuthenticated => state == AuthState.authenticated;
  bool get needsOnboarding => state == AuthState.missingProfile;
}

/// StreamProvider yang tracks auth state + profile resolution.
/// Priority: Custom Claims → Firestore fallback.
final authStateProvider = StreamProvider<AuthStateContainer>((ref) async* {
  final authService = ref.watch(authServiceProvider);
  final sessionManager = SessionManager(); // LGK-04: Session persistence
  final settings = ref.read(settingsProvider.notifier);

  await for (final user in authService.authStateChanges) {
    if (user == null) {
      yield AuthStateContainer(
        state: AuthState.unauthenticated,
        user: null,
        profile: null,
      );
      continue;
    }

    // User authenticated, resolving profile...
    yield AuthStateContainer(
      state: AuthState.authenticating,
      user: user,
      profile: null,
    );

    try {
      // Priority 1: Custom Claims (zero Firestore read)
      final tokenResult = await authService.getIdTokenResult(
        forceRefresh: false,
      );

      if (tokenResult != null &&
          tokenResult.claims != null &&
          tokenResult.claims!['bengkelId'] != null) {
        final profile = UserProfile.fromCustomClaims(user, tokenResult);

        // 📱 Register device → mencabut sesi perangkat lama (Owner only)
        if (profile.role == 'owner') {
          await DeviceSessionService().registerDevice(user.uid);
        }

        // 🎯 LGK-04 FIX: Inisialisasi metadata sesi dan sinkronisasi pengaturan
        // Ini memastikan Bengkel ID tampil di UI dan sesi tidak blocked saat offline.
        final token = await user.getIdToken();
        await sessionManager.saveSession(
          token: token ?? '',
          userId: user.uid,
          role: profile.role,
          bengkelId: profile.bengkelId,
        );

        // Sinkronisasi Bengkel ID ke SharedPreferences agar tampil di UI Pusat Data
        if (profile.bengkelId.isNotEmpty) {
          await settings.setBengkelId(profile.bengkelId);
        }

        // Ambil nama bengkel agar konsisten di settings
        try {
          final bengkelDoc = await BengkelService().getBengkel(profile.bengkelId);
          if (bengkelDoc.exists) {
            final name = (bengkelDoc.data() as Map<String, dynamic>?)?['name'];
            if (name != null) {
              await settings.updateWorkshopInfo(name: name as String);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Gagal sinkronisasi nama bengkel: $e');
        }

        yield AuthStateContainer(
          state: AuthState.authenticated,
          user: user,
          profile: profile,
        );
        continue;
      }

      // Priority 2: Firestore fallback (first login scenario)
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (profileDoc.exists && profileDoc.data()?['bengkelId'] != null) {
        final profile = UserProfile.fromFirestore(profileDoc);

        // 📱 Register device → mencabut sesi perangkat lama (Owner only)
        if (profile.role == 'owner') {
          await DeviceSessionService().registerDevice(user.uid);
        }

        // 🎯 LGK-04 FIX: Inisialisasi metadata sesi dan sinkronisasi pengaturan
        final token = await user.getIdToken();
        await sessionManager.saveSession(
          token: token ?? '',
          userId: user.uid,
          role: profile.role,
          bengkelId: profile.bengkelId,
        );

        if (profile.bengkelId.isNotEmpty) {
          await settings.setBengkelId(profile.bengkelId);
        }

        // Ambil nama bengkel agar konsisten di settings
        try {
          final bengkelDoc = await BengkelService().getBengkel(profile.bengkelId);
          if (bengkelDoc.exists) {
            final name = (bengkelDoc.data() as Map<String, dynamic>?)?['name'];
            if (name != null) {
              await settings.updateWorkshopInfo(name: name as String);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Gagal sinkronisasi nama bengkel: $e');
        }

        yield AuthStateContainer(
          state: AuthState.authenticated,
          user: user,
          profile: profile,
        );
      } else {
        // First login → redirect ke onboarding
        yield AuthStateContainer(
          state: AuthState.missingProfile,
          user: user,
          profile: null,
        );
      }
    } catch (e) {
      debugPrint('Auth State Resolution Error: $e');
      // UX-03 FIX: Bedakan error jaringan/Firebase dari genuinely missing profile.
      // Error jaringan → yield unauthenticated dengan isError=true agar UI
      // bisa menampilkan pesan spesifik tanpa redirect ke OnboardingScreen.
      final isNetworkOrFirebase = e is FirebaseException ||
          e.toString().contains('network') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('timeout');

      if (isNetworkOrFirebase) {
        yield AuthStateContainer(
          state: AuthState.unauthenticated,
          user: user,
          profile: null,
          isError: true,
          errorMessage: 'Gagal memuat profil. Periksa koneksi internet Anda.',
        );
      } else {
        // Benar-benar belum ada profil (first login edge case)
        yield AuthStateContainer(
          state: AuthState.missingProfile,
          user: user,
          profile: null,
        );
      }
    }
  }
});

// ===== Permission & Role Providers (derived from auth state) =====

/// Check permission di UI — dari Custom Claims / profile.
final permissionProvider = Provider.family<bool, Permission>((ref, permission) {
  final container = ref.watch(authStateProvider).value;
  return container?.profile?.can(permission) ?? false;
});

/// Check role di UI.
final roleProvider = Provider.family<bool, String>((ref, role) {
  final container = ref.watch(authStateProvider).value;
  return container?.profile?.role == role;
});

/// Current user profile (convenience shortcut).
final currentProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authStateProvider).value?.profile;
});

/// Force refresh token (setelah role change dari owner).
final refreshAuthProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authService = ref.read(authServiceProvider);
    await authService.getIdTokenResult(forceRefresh: true);
    ref.invalidate(authStateProvider);
  };
});

/// Comprehensive Logout Logic
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authService = ref.read(authServiceProvider);
    final encryptionService = EncryptionService();

    // SEC-01 FIX 1: Lock in-memory encryption key segera agar data PII
    // tidak bisa di-decrypt setelah logout tanpa re-auth.
    encryptionService.lock();

    // SEC-01 FIX 2: Hentikan SyncWorker agar tidak ada operasi sync
    // yang berjalan setelah user logout.
    ref.invalidate(syncWorkerProvider);

    // SEC-01 FIX 3: Clear data session (biometrics, dll) tapi pertahankan master key
    // agar data lokal tidak "terkunci" selamanya setelah logout.
    await encryptionService.clearSessionDataOnly();

    // SEC-01 FIX 4: Bersihkan SharedPreferences yang relevan
    // (bengkelId & lastBackupAt tidak sensitif namun harus direset
    // agar tidak bocor ke user berikutnya di perangkat yang sama).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppSettings.workshopId); // LGK-04 FIX: Gunakan key yang benar
    await prefs.remove('last_backup_at');
    // Catatan: key seperti theme, language dipertahankan (preferensi perangkat)

    // SEC-01 FIX 5: Sign out dari Firebase Auth & Google
    await authService.signOut();

    // SEC-01 FIX 6: Reset auth state agar AuthGate kembali ke LoginScreen
    ref.invalidate(authStateProvider);
  };
});
