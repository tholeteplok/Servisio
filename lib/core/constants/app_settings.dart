class AppSettings {
  /// The display name of the workshop used in receipts and profile headers.
  static const String workshopName = 'workshop_name';

  /// Full physical address of the workshop.
  static const String workshopAddress = 'workshop_address';

  /// WhatsApp contact number for the workshop.
  static const String workshopWhatsapp = 'workshop_whatsapp';

  /// Name of the workshop owner.
  static const String ownerName = 'owner_name';

  /// Phone number of the workshop owner.
  static const String ownerPhone = 'owner_phone';

  /// Theme mode setting: 'siang' (light), 'malam' (dark), 'otomatis' (system), or 'time' (schedule).
  static const String themeMode = 'theme_mode';

  /// Start time for scheduled dark mode (format: "HH:mm").
  static const String themeStartTime = 'theme_start_time';

  /// End time for scheduled dark mode (format: "HH:mm").
  static const String themeEndTime = 'theme_end_time';

  /// Flag for manual dark mode toggle (boolean).
  static const String darkMode = 'dark_mode';

  /// Flag for demo/trial mode (boolean).
  static const String isDemoMode = 'is_demo_mode';

  /// Flag to enable/disable barcode scanning features globally.
  static const String barcodeEnabled = 'barcode_enabled';

  /// Flag to enable/disable QRIS payment display.
  static const String qrisEnabled = 'qris_enabled';

  /// Local path to the saved QRIS image asset.
  static const String qrisImagePath = 'qris_image_path';

  /// Timestamp of the last successful data backup (ISO8601 String).
  static const String lastBackupAt = 'last_backup_at';

  /// Unique identifier for the workshop (for Cloud sync).
  static const String workshopId = 'workshop_id';

  /// Flag identifying if biometric authentication is enabled.
  static const String isBiometricEnabled = 'is_biometric_enabled';

  /// Timeout duration for auto-lock in minutes (int: 0, 1, 5, 10, 30, 60).
  static const String autoLockDuration = 'auto_lock_duration';

  /// Flag to require biometric auth for sensitive actions (e.g. deleting finance data).
  static const String requireBiometricSensitive = 'require_biometric_sensitive';

  /// @deprecated in favor of [autoLockDuration].
  static const String autoLock30m = 'auto_lock_30m';

  /// Flag to restrict sync operations to Wi-Fi connection only.
  static const String syncWifiOnly = 'sync_wifi_only';

  /// Maximum compression level for sync payloads (int).
  static const String syncCompressionMax = 'sync_compression_max';

  /// Number of days before service is due to trigger a reminder.
  static const String reminderThresholdDays = 'reminder_threshold_days';

  /// Monthly revenue target for statistics dashboard (int).
  static const String monthlyTarget = 'monthly_target';

  /// Flag indicating if the user has completed the initial app onboarding.
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  /// Flag indicating if the app has already checked for cloud backups during setup.
  static const String hasCheckedBackupDiscovery = 'has_checked_backup_discovery';
}
