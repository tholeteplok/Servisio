/// Logical constants for database and sync values.
/// ADR-003: These values are stable and must NOT be localized.
/// Localization should only happen in the UI layer using AppStrings mapping.
class LogicConstants {
  const LogicConstants._();

  // Vehicle Types
  static const String vehicleMotor = 'motor';
  static const String vehicleMobil = 'mobil';
  static const String vehicleTruk = 'truk';

  // Transaction Statuses
  static const String trxPending = 'pending';
  static const String trxInProgress = 'in_progress';
  static const String trxCompleted = 'completed';
  static const String trxLunas = 'lunas';

  // Service Workflow Statuses
  static const String serviceStatusAntri = 'antri';
  static const String serviceStatusDikerjakan = 'dikerjakan';
  static const String serviceStatusSelesai = 'selesai';
  static const String serviceStatusSiapAmbil = 'siap_ambil';

  // Staff Roles
  static const String roleMekanik = 'mekanik';
  static const String roleAdmin = 'admin';
  static const String roleOwner = 'owner';

  // Inventory Categories
  static const String catSparepart = 'sparepart';
  static const String catOli = 'oli';
  static const String catBan = 'ban';
  static const String catAki = 'aki';
  static const String catAksesoris = 'aksesoris';
  static const String catAdjustment = 'adjustment';
  
  // Sync Status (for entities)
  static const int syncLocal = 0;
  static const int syncInProgress = 1;
  static const int syncSynced = 2;
  static const int syncFailed = 3;
}
