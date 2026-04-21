import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/app_settings.dart';
import 'system_providers.dart';
import 'sync_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ⚙️ Settings State
// ─────────────────────────────────────────────────────────────────────────────

class SettingsState {
  final String workshopName;
  final String workshopAddress;
  final String workshopWhatsapp;
  final String ownerName;
  final String ownerPhone;
  final String themeMode; 
  final String themeStartTime; 
  final String themeEndTime; 
  final bool isDemoMode;
  final bool barcodeEnabled;
  final bool qrisEnabled;
  final String? qrisImagePath;
  final String? lastBackupAt;
  final int? lastBackupTimestamp;
  final String backupFrequency; // 'off', 'daily', 'weekly'
  final bool isBiometricEnabled;
  final int autoLockDuration; // 0, 1, 5, 10, 30, 60
  final bool requireBiometricSensitive;
  final bool autoLock30m; 
  final bool syncWifiOnly;
  final bool syncCompressionMax;
  final int reminderThresholdDays;
  final String bengkelId;
  final int monthlyTarget;
  final bool hasSeenOnboarding;
  final bool hasCheckedBackupDiscovery;
  final String? lastSyncAt;
  final bool hasSeenSwipeHint;
  final bool hasSeenOverscrollHint;

  SettingsState({
    required this.workshopName,
    required this.workshopAddress,
    required this.workshopWhatsapp,
    required this.ownerName,
    required this.ownerPhone,
    required this.themeMode,
    this.themeStartTime = '06:00',
    this.themeEndTime = '18:00',
    required this.isDemoMode,
    required this.barcodeEnabled,
    required this.qrisEnabled,
    this.qrisImagePath,
    this.lastBackupAt,
    this.lastBackupTimestamp,
    this.backupFrequency = 'off',
    this.isBiometricEnabled = false,
    this.autoLockDuration = 0,
    this.requireBiometricSensitive = false,
    this.autoLock30m = false,
    this.syncWifiOnly = false,
    this.syncCompressionMax = true,
    this.reminderThresholdDays = 7,
    this.bengkelId = '',
    this.monthlyTarget = 10000000,
    this.hasSeenOnboarding = false,
    this.hasCheckedBackupDiscovery = false,
    this.lastSyncAt,
    this.hasSeenSwipeHint = false,
    this.hasSeenOverscrollHint = false,
  });

  SettingsState copyWith({
    String? workshopName,
    String? workshopAddress,
    String? workshopWhatsapp,
    String? ownerName,
    String? ownerPhone,
    String? themeMode,
    String? themeStartTime,
    String? themeEndTime,
    bool? isDemoMode,
    bool? barcodeEnabled,
    bool? qrisEnabled,
    String? qrisImagePath,
    String? lastBackupAt,
    int? lastBackupTimestamp,
    String? backupFrequency,
    bool? isBiometricEnabled,
    int? autoLockDuration,
    bool? requireBiometricSensitive,
    bool? autoLock30m,
    bool? syncWifiOnly,
    bool? syncCompressionMax,
    int? reminderThresholdDays,
    String? bengkelId,
    int? monthlyTarget,
    bool? hasSeenOnboarding,
    bool? hasCheckedBackupDiscovery,
    String? lastSyncAt,
    bool? hasSeenSwipeHint,
    bool? hasSeenOverscrollHint,
  }) {
    return SettingsState(
      workshopName: workshopName ?? this.workshopName,
      workshopAddress: workshopAddress ?? this.workshopAddress,
      workshopWhatsapp: workshopWhatsapp ?? this.workshopWhatsapp,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      themeMode: themeMode ?? this.themeMode,
      themeStartTime: themeStartTime ?? this.themeStartTime,
      themeEndTime: themeEndTime ?? this.themeEndTime,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      barcodeEnabled: barcodeEnabled ?? this.barcodeEnabled,
      qrisEnabled: qrisEnabled ?? this.qrisEnabled,
      qrisImagePath: qrisImagePath ?? this.qrisImagePath,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastBackupTimestamp: lastBackupTimestamp ?? this.lastBackupTimestamp,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      autoLockDuration: autoLockDuration ?? this.autoLockDuration,
      requireBiometricSensitive: requireBiometricSensitive ?? this.requireBiometricSensitive,
      autoLock30m: autoLock30m ?? this.autoLock30m,
      syncWifiOnly: syncWifiOnly ?? this.syncWifiOnly,
      syncCompressionMax: syncCompressionMax ?? this.syncCompressionMax,
      reminderThresholdDays: reminderThresholdDays ?? this.reminderThresholdDays,
      bengkelId: bengkelId ?? this.bengkelId,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      hasCheckedBackupDiscovery: hasCheckedBackupDiscovery ?? this.hasCheckedBackupDiscovery,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      hasSeenSwipeHint: hasSeenSwipeHint ?? this.hasSeenSwipeHint,
      hasSeenOverscrollHint: hasSeenOverscrollHint ?? this.hasSeenOverscrollHint,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🕹️ Settings Notifier
// ─────────────────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref ref;
  SettingsNotifier(this.ref) : super(_initialState(ref));

  static SettingsState _initialState(Ref ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    return SettingsState(
      workshopName: prefs.getString(AppSettings.workshopName) ?? 'ServisLog+',
      workshopAddress: prefs.getString(AppSettings.workshopAddress) ?? '',
      workshopWhatsapp: prefs.getString(AppSettings.workshopWhatsapp) ?? '',
      ownerName: prefs.getString(AppSettings.ownerName) ?? 'Owner',
      ownerPhone: prefs.getString(AppSettings.ownerPhone) ?? '',
      themeMode: prefs.getString(AppSettings.themeMode) ?? 'otomatis',
      themeStartTime: prefs.getString(AppSettings.themeStartTime) ?? '06:00',
      themeEndTime: prefs.getString(AppSettings.themeEndTime) ?? '18:00',
      isDemoMode: prefs.getBool(AppSettings.isDemoMode) ?? false,
      barcodeEnabled: prefs.getBool(AppSettings.barcodeEnabled) ?? true,
      qrisEnabled: prefs.getBool(AppSettings.qrisEnabled) ?? false,
      qrisImagePath: prefs.getString(AppSettings.qrisImagePath),
      lastBackupAt: prefs.getString(AppSettings.lastBackupAt),
      lastBackupTimestamp: prefs.getInt('last_backup_timestamp'),
      backupFrequency: prefs.getString('backup_frequency') ?? 'off',
      isBiometricEnabled: prefs.getBool(AppSettings.isBiometricEnabled) ?? false,
      autoLockDuration: prefs.getInt(AppSettings.autoLockDuration) ?? (prefs.getBool(AppSettings.autoLock30m) == true ? 30 : 0),
      requireBiometricSensitive: prefs.getBool(AppSettings.requireBiometricSensitive) ?? false,
      autoLock30m: prefs.getBool(AppSettings.autoLock30m) ?? false,
      syncWifiOnly: prefs.getBool(AppSettings.syncWifiOnly) ?? false,
      syncCompressionMax: prefs.getBool(AppSettings.syncCompressionMax) ?? true,
      reminderThresholdDays: prefs.getInt(AppSettings.reminderThresholdDays) ?? 7,
      bengkelId: prefs.getString(AppSettings.workshopId) ?? '',
      monthlyTarget: prefs.getInt(AppSettings.monthlyTarget) ?? 10000000,
      hasSeenOnboarding: prefs.getBool(AppSettings.hasSeenOnboarding) ?? false,
      hasCheckedBackupDiscovery: prefs.getBool(AppSettings.hasCheckedBackupDiscovery) ?? false,
      lastSyncAt: prefs.getString(AppSettings.lastSyncAt),
      hasSeenSwipeHint: prefs.getBool(AppSettings.hasSeenSwipeHint) ?? false,
      hasSeenOverscrollHint: prefs.getBool(AppSettings.hasSeenOverscrollHint) ?? false,
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> updateWorkshopInfo({String? name, String? address, String? whatsapp}) async {
    if (name != null) await _prefs.setString(AppSettings.workshopName, name);
    if (address != null) await _prefs.setString(AppSettings.workshopAddress, address);
    if (whatsapp != null) await _prefs.setString(AppSettings.workshopWhatsapp, whatsapp);
    state = state.copyWith(workshopName: name, workshopAddress: address, workshopWhatsapp: whatsapp);
  }

  Future<void> updateOwnerInfo({String? name, String? phone}) async {
    if (name != null) await _prefs.setString(AppSettings.ownerName, name);
    if (phone != null) await _prefs.setString(AppSettings.ownerPhone, phone);
    state = state.copyWith(ownerName: name, ownerPhone: phone);
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(AppSettings.themeMode, mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setThemeStartTime(String time) async {
    await _prefs.setString(AppSettings.themeStartTime, time);
    state = state.copyWith(themeStartTime: time);
  }

  Future<void> setThemeEndTime(String time) async {
    await _prefs.setString(AppSettings.themeEndTime, time);
    state = state.copyWith(themeEndTime: time);
  }

  Future<void> setDemoMode(bool value) async {
    await _prefs.setBool(AppSettings.isDemoMode, value);
    state = state.copyWith(isDemoMode: value);
  }

  Future<void> setBarcodeEnabled(bool value) async {
    await _prefs.setBool(AppSettings.barcodeEnabled, value);
    state = state.copyWith(barcodeEnabled: value);
  }

  Future<void> setQrisEnabled(bool value) async {
    await _prefs.setBool(AppSettings.qrisEnabled, value);
    state = state.copyWith(qrisEnabled: value);
  }

  Future<void> setQrisImagePath(String? path) async {
    if (path != null) {
      await _prefs.setString(AppSettings.qrisImagePath, path);
    } else {
      await _prefs.remove(AppSettings.qrisImagePath);
    }
    state = state.copyWith(qrisImagePath: path);
  }

  Future<void> updateLastBackup() async {
    final now = DateTime.now();
    final formatted = DateFormat('dd MMM yyyy, HH:mm').format(now);
    await _prefs.setString(AppSettings.lastBackupAt, formatted);
    await _prefs.setInt('last_backup_timestamp', now.millisecondsSinceEpoch);
    state = state.copyWith(lastBackupAt: formatted, lastBackupTimestamp: now.millisecondsSinceEpoch);
  }

  Future<void> setBackupFrequency(String frequency) async {
    await _prefs.setString('backup_frequency', frequency);
    state = state.copyWith(backupFrequency: frequency);
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _prefs.setBool(AppSettings.isBiometricEnabled, value);
    state = state.copyWith(isBiometricEnabled: value);
  }

  Future<void> setAutoLock30m(bool value) async {
    await _prefs.setBool(AppSettings.autoLock30m, value);
    await _prefs.setInt(AppSettings.autoLockDuration, value ? 30 : 0);
    state = state.copyWith(autoLock30m: value, autoLockDuration: value ? 30 : 0);
  }

  Future<void> setAutoLockDuration(int minutes) async {
    await _prefs.setInt(AppSettings.autoLockDuration, minutes);
    await _prefs.setBool(AppSettings.autoLock30m, minutes == 30);
    state = state.copyWith(autoLockDuration: minutes, autoLock30m: minutes == 30);
  }

  Future<void> setRequireBiometricSensitive(bool value) async {
    await _prefs.setBool(AppSettings.requireBiometricSensitive, value);
    state = state.copyWith(requireBiometricSensitive: value);
  }

  Future<void> setSyncWifiOnly(bool value) async {
    await _prefs.setBool(AppSettings.syncWifiOnly, value);
    state = state.copyWith(syncWifiOnly: value);
    ref.invalidate(syncWorkerProvider);
  }

  Future<void> setSyncCompressionMax(bool value) async {
    await _prefs.setBool(AppSettings.syncCompressionMax, value);
    state = state.copyWith(syncCompressionMax: value);
  }

  Future<void> setReminderThreshold(int days) async {
    await _prefs.setInt(AppSettings.reminderThresholdDays, days);
    state = state.copyWith(reminderThresholdDays: days);
  }

  Future<void> setBengkelId(String id) async {
    await _prefs.setString(AppSettings.workshopId, id);
    state = state.copyWith(bengkelId: id);
  }

  Future<void> setMonthlyTarget(int value) async {
    final validValue = value.clamp(10000, 999999999);
    await _prefs.setInt(AppSettings.monthlyTarget, validValue);
    state = state.copyWith(monthlyTarget: validValue);
  }

  Future<void> updateLastSyncTime() async {
    final now = DateTime.now();
    final formatted = DateFormat('yyyy-MM-ddTHH:mm:ss').format(now);
    await _prefs.setString(AppSettings.lastSyncAt, formatted);
    state = state.copyWith(lastSyncAt: formatted);
  }

  Future<void> reload() async {
    state = _initialState(ref);
  }

  void setHasSeenOnboarding(bool value) async {
    await _prefs.setBool(AppSettings.hasSeenOnboarding, value);
    state = state.copyWith(hasSeenOnboarding: value);
  }

  Future<void> setHasCheckedBackupDiscovery(bool value) async {
    await _prefs.setBool(AppSettings.hasCheckedBackupDiscovery, value);
    state = state.copyWith(hasCheckedBackupDiscovery: value);
  }

  Future<void> setHasSeenSwipeHint(bool value) async {
    await _prefs.setBool(AppSettings.hasSeenSwipeHint, value);
    state = state.copyWith(hasSeenSwipeHint: value);
  }

  Future<void> setHasSeenOverscrollHint(bool value) async {
    await _prefs.setBool(AppSettings.hasSeenOverscrollHint, value);
    state = state.copyWith(hasSeenOverscrollHint: value);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
