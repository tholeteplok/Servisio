# Changelog Servisio

## [Unreleased] - 2026-04-28

### Fixed
- **Sinkronisasi Tidak Berjalan (Critical)**:
  - Ditemukan bug kritis di mana sinkronisasi lokal dengan Firestore tidak berjalan karena `activeWorkshopOwnerId` mengembalikan `null`.
  - **Root Cause**: `FirestoreSyncService._workshopDoc()` langsung throw error jika `ownerId` null, tanpa fallback ke legacy path. Selain itu, `SessionManager` tidak otomatis me-resolve workshop saat sync dimulai.
  - **Fix**:
    - `FirestoreSyncService._workshopDoc()` sekarang menggunakan **legacy path** (`bengkel/{workshopId}`) sebagai fallback jika `ownerId` tidak tersedia.
    - `pullAllData()` mendukung operasi dengan atau tanpa `ownerId`, dengan logging yang jelas untuk debugging.
    - Menambahkan metode baru `ensureWorkshopResolved()` di `SessionManager` untuk auto-resolve workshop dari Firestore atau secure storage.
    - `SyncWorker.start()` sekarang memanggil `ensureWorkshopResolved()` sebelum memproses queue.
    - Menambahkan `workshopResolvedProvider` di `sync_provider.dart` untuk memastikan workshop ter-resolve sebelum `SyncWorker` dibuat.
  - **File Terdampak**: `firestore_sync_service.dart`, `session_manager.dart`, `sync_worker.dart`, `sync_provider.dart`.

- **Restore Data Gagal Setelah Clear Data (Critical)**:
  - Ditemukan bug di mana data tidak berhasil dipulihkan setelah clear data aplikasi, meskipun data ada di server.
  - **Root Cause**: 
    - Discovery phase hanya memeriksa apakah dokumen workshop ada, bukan apakah sub-koleksi memiliki data.
    - Jika data ada di legacy path tapi `ownerId` tersedia, sistem mencoba mengambil dari nested path yang kosong.
  - **Fix**:
    - Menambahkan pengecekan sub-koleksi di discovery phase: jika nested path kosong, cek legacy path.
    - Menambahkan logging detail di `pullAllData()`, `_pullCollectionWithPagination()`, dan `syncDownAll()` untuk debugging.
    - Memperbaiki logging di `SyncRestoreScreen` untuk melihat jumlah data yang diambil dan disimpan.
  - **File Terdampak**: `firestore_sync_service.dart`, `sync_worker.dart`, `sync_restore_screen.dart`.

- **Firestore Rules untuk Legacy Path**:
  - Menambahkan akses ke sub-koleksi di path legacy (`bengkel/{bengkelId}/{collectionName}/{docId}`) untuk mendukung sinkronisasi data yang belum migrasi ke nested path.
  - Rules sekarang mengizinkan read/write untuk user yang terautentikasi dengan `bengkelId` yang valid.

- **Firestore Indexes**:
  - Menambahkan indexes baru untuk `staff`, `inventory`, `inventory_history`, dan `expenses` collections.
  - Menambahkan index alternatif untuk `transactions` dengan `createdAt` (sebelumnya hanya `updatedAt`).
  - Semua indexes sudah di-deploy ke Firebase.

- **Race Condition: Data Hilang Setelah Restart** (Critical):
  - Ditemukan bug kritis di mana **semua data (Stok, Pelanggan, Transaksi, Staff, Master Jasa, Kendaraan) hilang dari UI setelah force-close dan buka kembali aplikasi**, sementara tab Pengeluaran tetap tampil normal.
  - **Root Cause**: `sessionManager.activeWorkshopId` awalnya `null` (async loading). Provider data (`stokRepositoryProvider`, `pelangganRepositoryProvider`, dll.) dibuat lebih awal sebelum autentikasi selesai, lalu dipakai oleh `StateNotifier` di `_init()`. Ketika session akhirnya terisi (setelah `loadWorkshops()` selesai), `StateNotifier` **tidak ikut refresh** karena hanya memanggil `_init()` sekali di constructor.
  - **Fix**: Menambahkan `ref.listen<SessionManager>(sessionManagerProvider, ...)` di constructor setiap `StateNotifier`. Ketika `activeWorkshopId` berubah dari `null/kosong` ke nilai valid, notifier otomatis memanggil `_init()` kembali untuk memuat data yang benar.
  - **File Terdampak**: `stok_provider.dart`, `pelanggan_provider.dart`, `master_providers.dart` (Staff, ServiceMaster, Vehicle), `transaction_providers.dart` (TransactionList & PaginatedTransactionList).
  - Expense tab tidak terdampak karena `expenseListProvider` menggunakan pola `Provider.family(bengkelId)` dengan `bengkelId` di-pass eksplisit dari screen.

- **Service Master Tidak Pernah Di-Sync ke Firestore** (Critical):
  - `ServiceMasterListNotifier.addItem()`, `updateItem()`, dan `deleteItem()` **tidak pernah memanggil `syncWorker.enqueue()`**, menyebabkan master jasa tersimpan lokal tapi tidak pernah terkirim ke Firestore.
  - **Fix**: Menambahkan `syncWorker?.enqueue(entityType: 'service_master', entityUuid: item.uuid)` di ketiga method.
- **Stabilisasi Data Sync Restoration** (Major):
  - Memastikan konsistensi status data setelah instal ulang dengan memaksakan `syncStatus` ke `synced` (2) dan mengisi `lastSyncedAt` pada proses `SyncWorker.syncDownAll`.
  - Hal ini mencegah UI menampilkan status "gagal sinkronisasi" atau data terlihat "belum terunggah" untuk data yang sebenarnya baru saja diunduh dari server.
  - Menambahkan logging di `UnlockScreen` untuk melacak kondisi pemicu layar restore (check `txCount`, `pelangganCount`, `stokCount`).
  - Menjalankan `build_runner` untuk meregenerasi `objectbox.g.dart` guna menyertakan field `syncStatus` dan `lastSyncedAt` di level database.

- **Data Restore & Legacy Fallback** (Major):
  - Implemented automatic discovery for Phase 2 data structure (root `bengkel/` collection) during fresh installs. If data is not found in the new Phase 3 nested structure (`users/{ownerId}/workshops/{workshopId}`), the sync service now attempts to pull from the legacy path.
  - Added multi-path fallback for Master Key recovery: Secrets Sub-collection -> Nested Root Doc -> Legacy Registry.
- **Financial Sync & Integrity**:
  - Integrated `Expense` entity into the cloud synchronization pipeline. Repayments (cicilan) are now correctly linked to their parent debts via `parentExpenseUuid` during restoration.
  - Fixed type mismatch for `amount` in `SyncWorker` (ensured `int` instead of `double` to match ObjectBox schema).
  - Deprecated `Debt` synchronization: Since `Debt` is a local-only analytical entity derived from `Expense` records, it has been removed from the sync pipeline to prevent data duplication and maintain a single source of truth (the Expense record).

## [Unreleased] - 2026-04-27


### Added
- **Financial Reporting (CSV Export)**:
  - Implemented "Unduh Laporan" (Download Report) functionality in `PengeluaranTab`.
  - Created `FinancialExportHelper` to generate comprehensive `.csv` reports covering Services, Direct Sales, and Expenses.
  - Implemented manual CSV formatting to ensure robustness and cross-platform compatibility without external dependency conflicts.
  - Added native sharing integration via `share_plus` for easy report distribution.
- **UI Awareness (Color Psychology)**:
  - Standardized **Red** (`AppColors.error`) for Expense-related stats and trends to improve user awareness of cash outflows.
  - Standardized **Orange/Yellow** (`AppColors.warning`) for Debt-related headers and cards to signal items requiring attention.

### Fixed
- **UI & Navigation Clean-up**:
  - Removed **Workshop Selector** from the header of `HistoryScreen` (Riwayat) and `KatalogScreen` (Inventaris) as per user request, since workshop context is already clear from the Statistik screen.
  - Removed **Expense Summary Card** from the Pengeluaran tab in `HistoryScreen` to eliminate redundancy and provide a cleaner list-focused view.
  - Optimized **Biometric Security Prompt**: The "Aktifkan Keamanan Biometrik" prompt in the main layout now only appears once (until dismissed or enabled) instead of on every app restart.
  - Fixed **StatistikScreen Alignment**: Centered headers and adjusted padding for better visual balance after the removal of the workshop selector.
  - **Code Quality**: Fixed `ListToCsvConverter` and `WorkshopInfo` reference issues, achieving a clean `flutter analyze` status.

## [Unreleased] - 2026-04-26

### Added
- **UI Redesign (Premium Dashboard Look)**:
  - Redesigned `HistoryScreen` (Riwayat Transaksi) and `KatalogScreen` (Inventaris) to use a premium `Column` + `Stack` layout inspired by `StatistikScreen`.
  - Implemented centralized floating `TabBar` with pill indicators, custom shadows, and Jakarta Sans typography.
  - Standardized header gradients to remain consistent with previous design while adopting the new layout structure.
- **Session & Restore Robustness**:
  - Implemented `resolveAndSelectWorkshop` in `SessionManager` to handle direct registry lookups for workshop metadata during fresh installs.

### Fixed
- **UI & Layout**:
  - Fixed "Keamanan Biometrik" prompt appearing on every app restart; now it only appears once until dismissed or enabled.
  - Fixed header padding in `StatistikScreen` to prevent the TabBar from overlapping the title after subtitle removal.
  - Added `bottomPadding` parameter to `AtelierHeaderSub` for better layout flexibility across the app.
- **Critical Restore Flow (Fresh Install)**:
  - Resolved the "Surviving Root Cause" where `activeWorkshopOwnerId` was null during restoration because the user document hadn't synced yet.
  - **Master Key Recovery**: Implemented Cloud-based recovery where the app prompts for PIN to unwrap the key from Firestore.
  - **Session Initialization**: Fixed a race condition by ensuring `SessionManager` is fully initialized (loaded and selected workshop) before pulling data.
  - **Parameter Safety**: Fixed `pullAllData` to correctly use the `bengkelId` parameter and verify session state.
  - **Security Rules**: Updated Firestore rules to allow `secrets` subcollection access for authenticated users during recovery.
- **Sync Settings Stability**:
  - Fixed a white screen (crash) on `SyncSettingsScreen` caused by eager initialization of `MigrationService` without required dependencies.
  - Refactored `MigrationService` to use safe dependency injection and lazy initialization.
- **UI & Navigation**:
  - Refined the "Tentang Aplikasi" links to use Firebase Hosting for legal and privacy documents.
  - Standardized the `PinVerifyDialog` to support both routine verification and disaster recovery scenarios.

- **History Screen Premium Redesign (Riwayat Transaksi & Pengeluaran)**:
  - **Atelier "History" Aesthetic**: Completely redesigned the History screen with a premium "floating header" architecture, similar to the Statistik screen.
  - **Premium Transaction Card**: Replaced generic list items with tiered, high-contrast cards featuring:
    - Hashtag-based transaction IDs (#ABCD).
    - Modern status badges (LUNAS/PENDING) with soft-glow backgrounds.
    - Dedicated note sections for service details or product information.
    - Bold, Indigo-accented currency formatting using Google Fonts (Manrope).
  - **Expense Card Harmonization**: Redesigned expense cards to match the transaction card's visual language, including category icons and unified spacing.
  - **Structural Refactor**: Converted the screen to a `Stack` layout with a floating `TabBar` positioned at `top: 215`, providing a sophisticated layered effect.
  - **Layout Optimization**: Fine-tuned content padding (`top: 275`) to ensure a seamless scrolling experience behind the floating navigation elements.
  - **Centralized UI**: Ensured all components (Cards, BottomSheet, Filter Chips) utilize the core design system and tokens, avoiding hardcoded values.
- **Katalog & Inventory Screen Premium Redesign**:
  - **Floating TabBar Architecture**: Refactored `KatalogScreen` from `NestedScrollView` to a modern `Column` layout with a floating `TabBar` positioned on the header's edge.
  - **Interactive Header**: Integrated `AtelierHeader` with support for real-time search filtering, scanner access, and data refresh.
  - **UI Harmonization**: Standardized `TabBar` indicators (solid pill with shadow), typography (Plus Jakarta Sans), and spatial layouts to match the "Business Analysis" design system.
  - **Navigation Fidelity**: Preserved horizontal overscroll navigation logic between main application tabs (Home <-> Katalog <-> Pelanggan).
  - **Centralized Components**: Replaced ad-hoc styling with centralized design tokens for borders, shadows, and gradients.
  - **Cleanup**: Removed `NestedScrollView` complexity while maintaining a seamless scrolling experience and consistent padding.

### Added
- **Business Analysis Redesign (StatistikScreen)**:
  - **Premium Header**: Updated the global header gradient to match the Stitch 'Business Analysis' palette (`A49BFF`, `B8D7FF`, `D5E5FF`) for a more premium first impression.
  - **Floating TabBar**: Implemented a floating segmented control for tab navigation that overlaps the header, improving visual hierarchy and spatial efficiency.
  - **Pengeluaran Tab Overhaul**: Completely redesigned the Pengeluaran tab based on the Stitch layout:
    - Added a modern Date Range selector with calendar integration.
    - Implemented high-contrast Stat Cards with better typography and icons.
    - Updated the Allocation Chart (Donut) with a clean, right-aligned legend and bold percentages.
    - Enhanced the Trend Chart (Bar) with a highlighted "Today" bar and better tooltips.
    - Added a primary "Unduh Laporan Lengkap" CTA button for better UX.
  - **UI Consistency**: Standardized fonts (Plus Jakarta Sans & Manrope) and border-radius (32-40px) across financial reports to maintain the premium "Atelier" design language.
  - **Header Cleanup**: Removed the workshop selector (dropdown) and subtitle from the Statistik header to prevent overlapping with the floating tab bar and provide a cleaner, focused layout.
  - **Pemasukan & Hutang Premium Upgrade**: Upgraded the remaining Statistik tabs to the premium "Business Analysis" design, including enhanced stat cards, modern gradients, and refined spatial layouts.
  - **Bug Fix**: Resolved compilation error in `PengeluaranTab` caused by `MainAxisAlignment.between` typos.
- **Biometric Security Overhaul**:
  - **Unified Setup Flow**: Refactored the "Aktifkan Sekarang" prompt to initiate a direct PIN verification and biometric linking sequence, eliminating redundant navigation.
  - **Centralized Management**: Added a dedicated Biometric toggle to `SecurityDataCenterScreen` with mandatory PIN confirmation for secure enrollment.
  - **PinVerifyDialog**: Created a reusable, premium PIN verification widget for high-security actions.
  - **Improved UX**: Added success snackbars and clearer instructions for biometric enrollment.

### Fixed
- **Fresh Install Restoration**: Fixed a critical bug where data restoration failed on fresh installs due to missing workshop context. 
  - Ensured `SessionManager` loads and selects the correct workshop during the `UnlockScreen` flow before restoration starts.
  - Updated `SyncRestoreScreen` to use the centralized `firestoreSyncServiceProvider`.
- **Sync Settings Visibility**: Fully resolved the "white screen" issue on the Sync Settings screen by implementing explicit loading and error states with visible headers (`SliverAtelierHeaderSub`).
- **State Management**: Refactored `SyncSettingsScreen` to centralize provider watching at the top-level of the `build` method, ensuring proper reactivity and handling of the `AuthState.authenticating` state.
- **Robustness**: Added a robust error boundary with a fallback UI in `SyncSettingsScreen` to prevent total rendering failure in case of unexpected errors during build.
- **Legal Links**: Reverted external legal links (Privacy Policy, Terms, FAQ) to Firebase Hosting (`servisio.web.app`) to ensure availability while the primary domain is being finalized.

## [Unreleased] - 2026-04-25

### Added
- **Firestore Nested Migration (Phase 4: UI Layer & Isolation)**:
  - **Workshop Isolation**: Refactored all core repositories (`Transaction`, `Stok`, `Sale`, `Pelanggan`, `Expense`) to be workshop-aware using a mandatory/optional `workshopId` filter.
  - **Data Privacy**: Implemented strict ObjectBox query filtering to ensure users only see data belonging to the active workshop context.
  - **UI Context Switching**: Created a premium `WorkshopSelector` widget with a modern bottom-sheet picker for seamless switching between accessible workshops.
  - **Header Integration**: Enhanced `AtelierHeader` and `SliverAtelierHeader` to natively support the workshop selector.
  - **Reactive Analytics**: Updated `StatistikScreen` to automatically refresh financial reports when the active workshop is switched via Riverpod provider watching.
  - **User Data Expansion**: Updated `UserProfile` and `SessionManager` to handle `accessibleWorkshops` metadata, enabling multi-workshop access for staff and owners.

- **Firestore Nested Migration (Phase 5: Backend & Security)**:
  - **Security Rules**: Completely refactored `firestore.rules` to support nested workshop paths (`users/{ownerId}/workshops/{workshopId}/...`). Implemented a hybrid access check: direct UID match for owners and a 'members' sub-collection lookup for staff.
  - **Index Optimization**: Rewrote `firestore.indexes.json` to focus on nested collection synchronization and multi-tenant scalability, including a new Collection Group index for cross-workshop member queries.
  - **Path Consolidation**: Fully decoupled `FirestoreSyncService` and `SyncWorker` from legacy top-level `bengkel` paths, standardizing on the hierarchical owner-based structure.
  - **Access Strategy**: Implemented the "Accessible Workshops" consolidated list in the user document for efficient UI listing and rule validation.

### Fixed
- **Code Quality**: Standardized repository constructors and cleaned up unused remote datasource dependencies across the data layer.
- **UI Consistency**: Ensured financial dashboard (`StatistikScreen`) maintains security guards while supporting multi-workshop context.
- **Legal & Support**: Centralized all external links (Privacy Policy, Terms, FAQ, Rating) into `AppStrings.legal` and unified the domain to `servisio.id` across `TentangScreen` and `LoginScreen`.
- **Linter Compliance**: Resolved all `flutter analyze` errors and warnings including type mismatches and unused imports.

- **Firestore Nested Migration (Phase 1 & 2)**:
  - **Rules Fix**: Diperbaiki masalah perizinan pendaftaran bengkel dengan mengaktifkan kembali registry `bengkel/{id}` untuk lookup owner dan cek ketersediaan ID.
  - **BengkelService Update**: Mendukung penulisan atomic ke struktur nested `users/{ownerId}/workshops/{bengkelId}` saat pendaftaran dan join.
  - **Transaction Fix**: Memperbaiki error `[cloud_firestore/not-found]` saat pendaftaran bengkel baru dengan mengganti `transaction.update` ke `transaction.set(merge: true)` untuk profil user.
  - **Multi-Lookup**: `getWrappedMasterKey` sekarang mendukung pencarian hybrid (Registry -> Nested -> Legacy) untuk transisi data yang mulus.
  - **Data Layer**: Integrated nested Firestore paths (`users/{ownerId}/workshops/{workshopId}/...`) into `Stok`, `Pelanggan`, dan `Transaction` repositories.
  - **Service Layer**: Refactored `FirestoreSyncService` with reactive `SessionManager` dependency and `_workshopCollection` helpers.
  - **Multi-User Sync**: Implemented idempotency keys and workshop-specific sync telemetry in `SyncWorker`.
  - **Infrastructure**: Converted `sessionManagerProvider` to `ChangeNotifierProvider` for real-time UI workshop switching.

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
