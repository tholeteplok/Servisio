class AppConfig {
  /// Default handshake URL (fallback when no env var or Firestore config).
  static const String defaultHandshakeUrl =
      'https://asia-southeast2-servislog-plus.cloudfunctions.net/securityHandshake';

  /// Compile-time environment variable override (set via --dart-define).
  /// Returns env var if provided, otherwise falls back to default.
  static String get handshakeUrl {
    const envUrl = String.fromEnvironment('HANDSHAKE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return defaultHandshakeUrl;
  }

  /// Firebase region (for building correct URLs).
  /// Override via --dart-define=FIREBASE_REGION=asia-southeast2
  static const String firebaseRegion = String.fromEnvironment(
    'FIREBASE_REGION',
    defaultValue: 'asia-southeast2',
  );

  /// App version identifier for security audit and version matching.
  /// Fallback version when package_info_plus is not available.
  static const String appVersionFallback = '1.2.0';

  /// ✅ NEW: Config version for secret rotation tracking
  static const String configVersion = '1.0.0';

  /// ✅ NEW: Last rotation timestamp (update when secrets change)
  static const String lastRotatedAt = '2026-04-16T00:00:00Z';

  /// Lockout configuration
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 15;

  // ✅ NEW: Rate limit configuration (moved from session_manager)
  static const int handshakeMaxRetry = 3;
  static const Duration handshakeTimeout = Duration(seconds: 5);
  static const Duration handshakeCacheTtl = Duration(minutes: 15);

  // ✅ NEW: Exponential backoff configuration
  static const int backoffBaseSeconds = 2;
  static const int backoffMaxMinutes = 120;

  /// ✅ NEW: Validate production configuration
  /// Throws exception if required env vars are missing in production
  static void validateProductionConfig() {
    const isProduction =
        bool.fromEnvironment('PRODUCTION', defaultValue: false);

    if (isProduction) {
      // In production, custom handshake URL is NOT allowed (security)
      // Only default Firebase Function URL should be used
      if (handshakeUrl != defaultHandshakeUrl) {
        throw Exception(
            'SECURITY: Custom handshake URL not allowed in production mode');
      }

      // Verify Firebase region is set (not default for production)
      const envRegion = String.fromEnvironment('FIREBASE_REGION');
      if (envRegion.isEmpty) {
        throw Exception(
            'PRODUCTION: FIREBASE_REGION must be explicitly set via --dart-define');
      }
    }
  }

  /// ✅ NEW: Check if running in debug/development mode
  static bool get isDevelopment {
    const isDev = bool.fromEnvironment('DEV', defaultValue: true);
    const isProd = bool.fromEnvironment('PRODUCTION', defaultValue: false);
    return isDev && !isProd;
  }

  /// ✅ NEW: Get environment name for logging
  static String get environmentName {
    if (const bool.fromEnvironment('PRODUCTION', defaultValue: false)) {
      return 'PRODUCTION';
    }
    if (const bool.fromEnvironment('STAGING', defaultValue: false)) {
      return 'STAGING';
    }
    return 'DEVELOPMENT';
  }
}

