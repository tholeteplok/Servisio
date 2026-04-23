import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../services/encryption_service.dart';
import '../services/bengkel_service.dart';
import '../services/biometric_service.dart';
import '../services/device_session_service.dart';
import '../services/transaction_number_service.dart';
import '../services/backup_service.dart';
import '../services/local_backup_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/session_manager.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../constants/app_settings.dart';
import 'objectbox_provider.dart';
import 'pengaturan_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🏗️ Base Infrastructure Providers
// ─────────────────────────────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn(
      scopes: ['https://www.googleapis.com/auth/drive.appdata'],
    ));

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    ));

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());
final httpClientProvider = Provider<http.Client>((ref) => http.Client());
final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

// ─────────────────────────────────────────────────────────────────────────────
// 🛡️ Core Service Providers (Singletons)
// ─────────────────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService(
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final bengkelServiceProvider = Provider<BengkelService>((ref) {
  return BengkelService(
    firestore: ref.watch(firestoreProvider),
    encryption: ref.watch(encryptionServiceProvider),
    deviceSession: ref.watch(deviceSessionServiceProvider),
  );
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(
    localAuth: ref.watch(localAuthProvider),
    secureStorage: ref.watch(secureStorageProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
  );
});

final deviceSessionServiceProvider = Provider<DeviceSessionService>((ref) {
  return DeviceSessionService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    encryption: ref.watch(encryptionServiceProvider),
  );
});

final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService(
    firestore: ref.watch(firestoreProvider),
    encryption: ref.watch(encryptionServiceProvider),
  );
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(
    secureStorage: ref.watch(secureStorageProvider),
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    deviceSessionService: ref.watch(deviceSessionServiceProvider),
    httpClient: ref.watch(httpClientProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 🛠️ Local Feature Services
// ─────────────────────────────────────────────────────────────────────────────

final trxNumberServiceProvider = Provider<TrxNumberService>((ref) {
  final db = ref.watch(dbProvider);
  return TrxNumberService(db);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(dbProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  return BackupService(db, encryption);
});

final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  final db = ref.watch(dbProvider);
  return LocalBackupService(db);
});

// ─────────────────────────────────────────────────────────────────────────────
// 📊 Auth & Session State Providers
// ─────────────────────────────────────────────────────────────────────────────

final isWipingProvider = StateProvider<bool>((ref) => false);

final authStateProvider = StreamProvider<AuthStateContainer>((ref) async* {
  final service = ref.watch(authServiceProvider);
  final manager = ref.watch(sessionManagerProvider);
  final settings = ref.read(settingsProvider.notifier);
  final device = ref.read(deviceSessionServiceProvider);

  await for (final user in service.authStateChanges) {
    if (user == null) {
      yield AuthStateContainer(state: AuthState.unauthenticated);
      continue;
    }

    yield AuthStateContainer(state: AuthState.authenticating, user: user);

    try {
      final tokenResult = await service.getIdTokenResult(forceRefresh: false);
      
      if (tokenResult?.claims?['bengkelId'] != null) {
        final profile = UserProfile.fromCustomClaims(user, tokenResult!);
        
        if (profile.role == 'owner') await device.registerDevice(user.uid);

        await manager.saveSession(
          token: await user.getIdToken() ?? '',
          userId: user.uid,
          role: profile.role,
          bengkelId: profile.bengkelId,
        );

        if (profile.bengkelId.isNotEmpty) {
          await settings.setBengkelId(profile.bengkelId);
          // Removed: Auto-syncing workshop name from Firestore overwrites local profile edits.
          // Now workshop name is independently managed in Profile settings.
        }

        yield AuthStateContainer(state: AuthState.authenticated, user: user, profile: profile);
      } else {
        // Fallback to Firestore
        final doc = await ref.watch(firestoreProvider).collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['bengkelId'] != null) {
          final profile = UserProfile.fromFirestore(doc);
          if (profile.role == 'owner') await device.registerDevice(user.uid);
          
          await manager.saveSession(
            token: await user.getIdToken() ?? '',
            userId: user.uid,
            role: profile.role,
            bengkelId: profile.bengkelId,
          );

          yield AuthStateContainer(state: AuthState.authenticated, user: user, profile: profile);
        } else {
          yield AuthStateContainer(state: AuthState.missingProfile, user: user);
        }
      }
    } catch (e) {
      debugPrint('Auth State Error: $e');
      yield AuthStateContainer(state: AuthState.unauthenticated, isError: true, errorMessage: e.toString());
    }
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 🎭 Role & Permission Handlers
// ─────────────────────────────────────────────────────────────────────────────

final currentProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authStateProvider).value?.profile;
});

final bengkelIdProvider = Provider<String?>((ref) {
  return ref.watch(currentProfileProvider)?.bengkelId;
});

final permissionProvider = Provider.family<bool, Permission>((ref, permission) {
  return ref.watch(currentProfileProvider)?.can(permission) ?? false;
});

final roleProvider = Provider.family<bool, String>((ref, role) {
  return ref.watch(currentProfileProvider)?.role == role;
});

// ─────────────────────────────────────────────────────────────────────────────
// 🏹 Action Providers (Callbacks)
// ─────────────────────────────────────────────────────────────────────────────

final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final auth = ref.read(authServiceProvider);
    final encryption = ref.read(encryptionServiceProvider);
    final settings = ref.read(settingsProvider.notifier);

    encryption.lock();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppSettings.workshopId);
    await prefs.remove('last_backup_at');
    await settings.setBengkelId('');

    await auth.signOut();
    ref.invalidate(authStateProvider);
  };
});

final refreshAuthProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(authServiceProvider);
    await service.getIdTokenResult(forceRefresh: true);
    ref.invalidate(authStateProvider);
  };
});

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Session Status & Monitoring
// ─────────────────────────────────────────────────────────────────────────────

final deviceSessionStatusProvider = StreamProvider<DeviceSessionStatus>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value(DeviceSessionStatus.unknown);
  return ref.watch(deviceSessionServiceProvider).watchSessionValidity(user.uid);
});

final currentSessionStatusProvider = FutureProvider<SessionStatus>((ref) async {
  return await ref.watch(sessionManagerProvider).validateSession();
});

final currentDeviceIdProvider = FutureProvider<String>((ref) async {
  return await ref.watch(deviceSessionServiceProvider).getOrCreateDeviceId();
});

final loginHistoryStreamProvider = StreamProvider<List<DeviceInfo>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);
  
  return ref.watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) return [];
    final historyData = snapshot.data()?['loginHistory'] as List<dynamic>? ?? [];
    return historyData.map((d) => DeviceInfo.fromFirestore(d as Map<String, dynamic>)).toList();
  });
});

final currentAccessLevelProvider = Provider<AccessLevel>((ref) {
  final isWiping = ref.watch(isWipingProvider);
  if (isWiping) return AccessLevel.blocked;

  final container = ref.watch(authStateProvider).value;
  if (container == null) return AccessLevel.full;
  if (container.state == AuthState.unauthenticated) return AccessLevel.blocked;
  if (container.state != AuthState.authenticated) return AccessLevel.full;

  final profile = container.profile;
  if (profile == null) return AccessLevel.blocked;

  final status = ref.watch(currentSessionStatusProvider).value ?? SessionStatus.full;
  
  switch (status) {
    case SessionStatus.full:
    case SessionStatus.valid:
      return AccessLevel.full;
    case SessionStatus.warning:
      return profile.role == 'owner' ? AccessLevel.readOnlyFinancial : AccessLevel.readOnly;
    case SessionStatus.blocked:
    case SessionStatus.invalid:
      return AccessLevel.blocked;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 📦 Models & Containers
// ─────────────────────────────────────────────────────────────────────────────

class AuthStateContainer {
  final AuthState state;
  final User? user;
  final UserProfile? profile;
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
}
