# Changelog Servisio

## [Unreleased] - 2026-04-25

### Fixed
- **Sync & Restore Robustness**:
  - Improved `_toDateTime` in `SyncWorker` to support ISO 8601 strings from Firestore.
  - Enhanced `_sanitizeForIsolate` to prevent crashes when processing ISO strings in background isolates.
  - Added null-safety for all collection processing in `syncDownAll`.
  - Implemented `forceOverwrite` logic in `SyncWorker` and `SyncRestoreScreen` to ensure complete data recovery during app reinstallation.
  - Hardened `_isLocalNewer` with safe type checking and handling for empty local databases.
  - Fixed `pushServiceMaster` and `pushSale` in `FirestoreSyncService` to use `Timestamp` instead of ISO strings and added encryption for service names.
  - Added post-restore migration for `ServiceMaster` names to ensure legacy data is correctly encrypted.
- **UI Robustness & Error Handling**:
  - Rewrote `SyncSettingsScreen` with a dedicated Error Boundary and custom Error Widget to eliminate white screen crashes.
  - Implemented null-safety validation for `SettingsState` and `UserProfile` containers.
  - Added safe fallback values for `SyncQueueSummary` and `SessionStatus` providers.
  - Integrated `appLogger` for better debugging of UI state and synchronization processes.
  - Added robust error handling for "Retry Failed Items" actions with user-facing snackbars.
- **Business Logic Overhaul (Phase 1 & 2)**:
  - **Transaction & Profit**: Enhanced `Transaction` entity with net profit, margin, and break-even point calculations.
  - **Atomic Finalization**: Refactored `finalizeTransaction` to include atomic invoice generation and stock updates within a single transaction.
  - **Invoice System**: Created `Invoice` entity and `InvoiceNumberGenerator` for unique, category-based auditing.
  - **Inventory Intelligence**: Implemented `InventoryForecastService` for smart stock status monitoring (Reorder Point).
  - **Debt Management**: Created `Debt` entity and `DebtManagementService` with priority scoring (Pay Now, Schedule, Defer).
  - **Supplier Enhancement**: Added `creditLimit` and `isStrategic` fields to `Supplier` entity for financial profiling.
  - **Infrastructure**: Implemented `UnitOfWork` pattern and integrated `Invoice` boxes into `ObjectBoxProvider`.
  - **Code Quality**: Resolved all `flutter analyze` issues.


### Security
- Enabled encryption for `ServiceMaster` names during synchronization.

## [Unreleased] - 2026-04-24

### Fixed
- **Sync Restoration**: 
  - Added `bengkelId` to multiple entities (`Vehicle`, `StokHistory`, `TransactionItem`, `ShopProfile`, `ServiceMaster`, `Sale`) to ensure proper data isolation and filtering.
  - Updated `FirestoreSyncService` to explicitly include `bengkelId` in Firestore documents for all entities, including new support for `ServiceMaster` and `Sale`.
  - Refactored `SyncWorker` to correctly map and restore `ServiceMaster` and `Sale` entities from Firestore to local ObjectBox storage.
- **UI Stability**:
  - Hardened `SyncSettingsScreen` against "white screen" crashes by wrapping the build logic in a loading/error state handler using `authStateProvider.when`.
- **Security & Navigation**:
  - Corrected biometric setup navigation in `AdaptiveLayout` to explicitly route users to the `SecurityDataCenterScreen` instead of generic index switches.
  - Implemented automatic biometric re-enrollment prompt in `AdaptiveLayout` that triggers after login if security setup is missing.

### Infrastructure
- Standardized UI color handling using `withOpacity` across all core widgets (`StandardDialog`, `AtelierHeader`, `RestoreScreen`, etc.).
- Hardened `SyncWorker` recovery logic (ADR-012) to ensure latest entries win during de-duplication.
