/// Path builder untuk struktur Firestore baru Servisio (Versi Multi-User Ready)
/// 
/// Struktur Dasar:
/// users/{userId}/                               ← Data pribadi (devices, subs)
/// users/{ownerId}/workshops/{workshopId}/       ← Data operasional bengkel
///
/// Multi-user Access Strategy:
/// User B mengakses bengkel milik User A melalui path:
/// users/{userA}/workshops/{wsId}/...
///
/// Hak akses divalidasi melalui field `accessibleWorkshops` di `users/{userId}`.
class FirestorePaths {
  final String currentUserId; // User yang sedang login
  final String? ownerId;      // Pemilik bengkel (bisa sama dengan currentUserId)
  final String? workshopId;   // ID bengkel aktif

  const FirestorePaths({
    required this.currentUserId,
    this.ownerId,
    this.workshopId,
  });

  // ────────────────────────────────────────────
  // 👤 USER LEVEL (Data Pribadi & Keamanan)
  // ────────────────────────────────────────────

  /// users/{currentUserId}
  String get currentUserDoc => 'users/$currentUserId';

  /// users/{currentUserId}/devices/{deviceId}
  String userDevice(String deviceId) => 'users/$currentUserId/devices/$deviceId';

  /// users/{currentUserId}/devices
  String get userDevicesCollection => 'users/$currentUserId/devices';

  /// users/{currentUserId}/subscriptions
  String get userSubscriptionsCollection => 'users/$currentUserId/subscriptions';

  /// users/{currentUserId}/workshops (Daftar workshop yang DIMILIKI user ini secara langsung)
  String get myWorkshopsCollection => 'users/$currentUserId/workshops';

  // ────────────────────────────────────────────
  // 🛠️ WORKSHOP LEVEL (Operasional Bengkel)
  // ────────────────────────────────────────────

  /// Base path untuk workshop aktif: users/{ownerId}/workshops/{workshopId}
  String get _ws {
    assert(ownerId != null, 'ownerId must be provided for workshop level paths');
    assert(workshopId != null, 'workshopId must be provided for workshop level paths');
    return 'users/$ownerId/workshops/$workshopId';
  }

  /// Settings: users/{ownerId}/workshops/{workshopId}/settings/default
  String get workshopSettings => '$_ws/settings/default';

  /// Members: users/{ownerId}/workshops/{workshopId}/members
  String get workshopMembersCollection => '$_ws/members';
  String workshopMember(String memberId) => '$_ws/members/$memberId';

  /// Customers: users/{ownerId}/workshops/{workshopId}/customers
  String get workshopCustomersCollection => '$_ws/customers';
  String workshopCustomer(String customerId) => '$_ws/customers/$customerId';

  /// Inventory: users/{ownerId}/workshops/{workshopId}/inventory
  String get workshopInventoryCollection => '$_ws/inventory';
  String workshopInventory(String itemId) => '$_ws/inventory/$itemId';

  /// Inventory > Stock Logs
  String stockLogsCollection(String inventoryId) => '$_ws/inventory/$inventoryId/stock_logs';
  String stockLog(String inventoryId, String logId) => '$_ws/inventory/$inventoryId/stock_logs/$logId';

  /// Transactions: users/{ownerId}/workshops/{workshopId}/transactions
  String get workshopTransactionsCollection => '$_ws/transactions';
  String workshopTransaction(String trxId) => '$_ws/transactions/$trxId';

  /// Transactions > Status Logs
  String statusLogsCollection(String transactionId) => '$_ws/transactions/$transactionId/status_logs';
  String statusLog(String transactionId, String logId) => '$_ws/transactions/$transactionId/status_logs/$logId';

  /// Suppliers: users/{ownerId}/workshops/{workshopId}/suppliers
  String get workshopSuppliersCollection => '$_ws/suppliers';
  String workshopSupplier(String supplierId) => '$_ws/suppliers/$supplierId';

  /// Expenses: users/{ownerId}/workshops/{workshopId}/expenses
  String get workshopExpensesCollection => '$_ws/expenses';
  String workshopExpense(String expenseId) => '$_ws/expenses/$expenseId';

  /// Reports: users/{ownerId}/workshops/{workshopId}/reports
  String get workshopReportsCollection => '$_ws/reports';
  String workshopReport(String reportId) => '$_ws/reports/$reportId';

  // ────────────────────────────────────────────
  // 🔧 UTILITY
  // ────────────────────────────────────────────

  /// Buat instance baru untuk workshop berbeda (misal saat berpindah bengkel)
  FirestorePaths switchWorkshop({required String newOwnerId, required String newWsId}) {
    return FirestorePaths(
      currentUserId: currentUserId,
      ownerId: newOwnerId,
      workshopId: newWsId,
    );
  }

  @override
  String toString() => 'FirestorePaths(currentUser: $currentUserId, owner: $ownerId, workshop: $workshopId)';
}
