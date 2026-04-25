import 'system_providers.dart' as sys;

// ─────────────────────────────────────────────────────────────────────────────
// 🌁 Bridge / Proxy Providers (Compatibility Layer)
// ─────────────────────────────────────────────────────────────────────────────
// This file acts as a compatibility layer for existing code that still imports
// 'auth_provider.dart'. All logic has been moved to 'system_providers.dart'.

final googleSignInProvider = sys.googleSignInProvider;
final authServiceProvider = sys.authServiceProvider;
final authStateProvider = sys.authStateProvider;
final currentProfileProvider = sys.currentProfileProvider;
final permissionProvider = sys.permissionProvider;
final roleProvider = sys.roleProvider;
final logoutProvider = sys.logoutProvider;
final refreshAuthProvider = sys.refreshAuthProvider;
final isWipingProvider = sys.isWipingProvider;
final bengkelIdProvider = sys.bengkelIdProvider;

// System Infrastructure Proxies
final secureStorageProvider = sys.secureStorageProvider;
final deviceSessionServiceProvider = sys.deviceSessionServiceProvider;
final sessionManagerProvider = sys.sessionManagerProvider;
final deviceSessionStatusProvider = sys.deviceSessionStatusProvider;

// Renamed/Gen Proxies
final sessionStatusProvider = sys.currentSessionStatusProvider;
final accessLevelProvider = sys.currentAccessLevelProvider;

typedef AuthStateContainer = sys.AuthStateContainer;

