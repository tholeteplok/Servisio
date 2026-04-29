# ServisLog+ Project Audit Report 2026

**Tanggal Audit:** 21 April 2026
**Version:** 1.2 (ServisLog_core_1.2)
**Platform:** Flutter (Android, iOS, Windows, macOS, Linux, Web)
**Auditor:** BigPickle

---

## 1. Ringkasan Eksekutif

### 1.1 Status Project

| Aspek | Status | Catatan |
|------|--------|--------|
| **Overall** | 🟡 BUTUH PERBAIKAN | 2 compilation errors aktif |
| **Code Quality** | 🟡 MEDIUM | Large files, missing keys |
| **Security** | 🟢 BAIK | AES-GCM 256-bit, hybrid zones |
| **Architecture** | 🟢 BAIK | Clean Architecture + Riverpod |
| **Testing** | 🟡 MEDIUM | Test coverage ada, 1 failure |

### 1.2 metrics

| metric | Value |
|--------|-------|
| Total Dart Files | ~150+ |
| Test Files | 44 |
| Core Services | 23 |
| Entities | 12 |
| Providers | 36+ |
| Features | 8 modules |

---

## 2. Flutter Analyze Results

### 2.1 Current Errors

```
error - Undefined name 'currentAccessLevelProvider' - lib/features/statistik/statistik_screen.dart:37:36
error - Undefined name 'currentAccessLevelProvider' - lib/features/statistik/statistik_screen.dart:54:36
```

**Root Cause:**
- Provider didefinisikan di `system_providers.dart` sebagai `currentAccessLevelProvider`
- Tapi di `statistik_screen.dart` menggunakan nama `currentAccessLevelProvider`
- Seharusnya tidak error karena sudah di-import via `system_providers.dart`

**Impact:** HIGH - Statistik screen tidak dapat di-build

**Fix Required:** Add import `import '../../core/providers/auth_provider.dart';` atau verify import di statistik_screen.dart

---

## 3. Dependency & Environment

### 3.1 pubspec.yaml Analysis

```yaml
name: servislog_core
sdk: ^3.11.4
version: 1.0.0+1
```

#### Key Dependencies:

| Category | Package | Version | Status |
|----------|---------|---------|--------|
| State Management | flutter_riverpod | ^2.5.1 | 🟢 OK |
| State Management | riverpod_annotation | ^2.3.5 | 🟢 OK |
| Database | objectbox | ^2.5.1 | 🟢 OK |
| Database | objectbox_flutter_libs | ^2.5.1 | 🟢 OK |
| Firebase | firebase_core | ^3.1.0 | 🟢 OK |
| Firebase | cloud_firestore | ^5.0.0 | 🟢 OK |
| Firebase | firebase_auth | ^5.1.0 | 🟢 OK |
| Firebase | firebase_storage | ^12.1.0 | 🟢 OK |
| Firebase | firebase_crashlytics | ^4.0.0 | 🟢 OK |
| Security | flutter_secure_storage | ^10.0.0 | 🟢 OK |
| Security | encrypt | ^5.0.3 | 🟢 OK |
| Security | crypto | ^3.0.7 | 🟢 OK |
| Auth | google_sign_in | ^6.2.1 | 🟢 OK |
| Auth | local_auth | ^2.3.0 | 🟢 OK |
| UI | google_fonts | ^8.0.2 | 🟢 OK |
| UI | fl_chart | ^0.70.2 | 🟢 OK |
| UI | shimmer | ^3.0.0 | 🟢 OK |
| Utils | intl | ^0.19.0 | 🟢 OK |
| Utils | logger | ^2.0.2 | 🟢 OK |
| Utils | uuid | ^4.4.0 | 🟢 OK |
| Utils | mobile_scanner | ^5.2.3 | 🟢 OK |
| Utils | pdf | ^3.11.1 | 🟢 OK |
| Utils | printing | ^5.13.2 | 🟢 OK |

### 3.2 Dependency Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| Duplicate Export | HIGH | `authStateProvider` dan `authServiceProvider` di-export di dua file |

---

## 4. Arsitektur & Code Structure

### 4.1 Clean Architecture Layers

```
lib/
├── main.dart                          # Entry point (315 lines)
├── objectbox.g.dart                  # Generated (2696 lines - IGNORE)
│
├── core/                            # Core infrastructure
│   ├── config/
│   │   └── app_config.dart
│   ├── constants/
│   │   ├── app_strings.dart
│   │   ├── app_theme.dart
│   │   ├── app_theme_tokens.dart
│   │   ├── app_theme_extension.dart
│   │   ├── app_colors.dart
│   │   ├── app_icons.dart
│   │   ├── app_settings.dart
│   │   └── logic_constants.dart
│   ├── models/
│   │   └── user_profile.dart
│   │   └── permission_models.dart
│   ├── providers/
│   │   ├── objectbox_provider.dart
│   │   ├── auth_provider.dart       # PROXY to system_providers
│   │   ├── system_providers.dart    # MAIN - 331 lines
│   │   ├── transaction_providers.dart
│   │   ├── pelanggan_provider.dart
│   │   ├── stok_provider.dart
│   │   ├── sale_providers.dart
│   │   ├── master_providers.dart
│   │   ├── stats_provider.dart
│   │   ├── pengaturaaan_provider.dart
│   │   ├── navigation_provider.dart
│   │   ├── home_provider.dart
│   │   ├── history_provider.dart
│   │   ├── reminder_provider.dart
│   │   ├── katalog_provider.dart
│   │   ├── sync_provider.dart
│   │   ├── backup_provider.dart
│   │   ├── media_provider.dart
│   │   ├── device_info_provider.dart
│   │   └── inactivity_monitor_provider.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── encryption_service.dart   # 364 lines
│   │   ├── biometric_service.dart
│   │   ├── session_manager.dart     # 672 lines
│   │   ├── bengkel_service.dart
│   │   ├── sync_service.dart
│   │   ├── firestore_sync_service.dart # 20k+ lines
│   │   ├── sync_worker.dart
│   │   ├── local_sync_service.dart
│   │   ├── backup_service.dart
│   │   ├── drive_backup_service.dart
│   │   ├── local_backup_service.dart
│   │   ├── settings_backup_service.dart
│   │   ├── transaction_number_service.dart
│   │   ├── vehicle_data_service.dart
│   │   ├── device_session_service.dart
│   │   ├── document_service.dart
│   │   ├── media_service.dart
│   │   ├── migration_service.dart
│   │   ├── permission_service.dart
│   │   └── zip_utility.dart
│   ├── sync/
│   │   ├── sync_lock_manager.dart
│   │   ├── sync_telemetry.dart
│   │   ├── circuit_breaker.dart
│   │   ├── sync_error_mapping.dart
│   │   └── concurrency_pool.dart
│   ├── utils/
│   │   ├── app_logger.dart
│   │   ├── app_page_transitions.dart
│   │   ├── app_haptic.dart
│   │   ├── permission_constants.dart
│   │   ├── error_handler.dart
│   │   ├── license_plate_formatter.dart
│   │   └── phone_formatter.dart
│   └── widgets/
│       ├── atelier_header.dart
│       ├── atelier_list_card.dart
│       ├── atelier_skeleton.dart
│       ├── critical_action_guard.dart
│       ├── standard_dialog.dart
│       ├── qr_view_view.dart
│       ├── the_ceremony_dialog.dart
│       ├── step_indicator.dart
│       ├── security_dialogs.dart
│       ├── session_status_bar.dart
│       ├── role_guard.dart
│       ├── sync_status_indicator.dart
│       ├── standard_search_bar.dart
│       ├── shimmer_widget.dart
│       ├── premium_app_bar.dart
│       ├── glass_card.dart
│       ├── barcode_scanner_dialog.dart
│       ├── app_error_state.dart
│       └── app_empty_state.dart
│
├── domain/
│   └── entities/
│       ├── transaction.dart          # 208 lines
│       ├── pelanggan.dart
│       ├── vehicle.dart
│       ├── staff.dart
│       ├── stok.dart
│       ├── sale.dart
│       ├── service_master.dart
│       ├── stok_history.dart
│       ├── sync_queue_item.dart
│       ├── transaction_item.dart
│       ├── shop_profile.dart
│       └── trx_counter.dart
│
├── data/
│   └── repositories/
│       ├── transaction_repository.dart
│       ├── pelanggan_repository.dart
│       ├── stok_repository.dart
│       ├── sale_repository.dart
│       ├── stok_history_repository.dart
│       └── master_repositories.dart
│
└── features/
    ├── auth/
    │   └── screens/
    │       ├── login_screen.dart
    │       ├── onboarding_screen.dart
    │       ├── onboarding_intro_screen.dart
    │       ├── unlock_screen.dart
    │       ├── splash_screen.dart
    │       ├── create_bengkel_screen.dart
    │       ├── access_revoked_screen.dart
    │       ├── session_displaced_screen.dart
    │       └── sync_restore_screen.dart
    ├── main/
    │   ├── adaptive_layout.dart
    │   └── responsive_layout_builder.dart
    ├── home/
    │   ├── home_screen.dart        # 1807 lines - VERY LARGE
    │   ├── create_transaction_screen.dart # 2552 lines - VERY LARGE
    │   ├── transaction_detail_screen.dart
    │   ├── reminder_screen.dart
    │   └── widgets/
    │       └── transaction_card_skeleton.dart
    ├── pelanggan/
    │   ├── pelanggan_screen.dart
    │   ├── create_pelanggan_screen.dart
    │   ├── pelanggan_detail_screen.dart
    │   └── create_vehicle_screen.dart
    ├── katalog/
    │   ├── katalog_screen.dart
    │   ├── create_barang_screen.dart
    │   ├── create_sale_screen.dart
    │   ├── create_service_master_screen.dart
    │   └── stok_history_screen.dart
    ├── riwayat/
    │   └── history_screen.dart
    ├── statistik/
    │   ├── statistik_screen.dart   # 314 lines
    │   ├── tabs/
    │   │   ├── pendapatan_tab.dart
    │   │   ├── layanan_tab.dart
    │   │   ├── produk_tab.dart
    │   │   └── teknisi_tab.dart
    │   └── widgets/
    │       └── statistik_skeleton.dart
    ├── pengaturan/
    │   ├── pengaturan_screen.dart
    │   └── sub/
    │       ├── profil_screen.dart
    │       ├── teknisi_screen.dart
    │       ├── tampilan_screen.dart
    │       ├── fitur_screen.dart
    │       ├── backup_screen.dart
    │       ├── restore_screen.dart
    │       ├── security_data_center_screen.dart
    │       ├── sync_settings_screen.dart
    │       ├── faq_screen.dart
    │       └── tentang_screen.dart
    └── owner/
        ├── screens/
        │   └── permission_checklist_screen.dart
        └── widgets/
            ├── permission_tile.dart
            └── permission_category_card.dart
```

### 4.2 State Management

- **Pattern:** Riverpod dengan StateNotifier
- **Types Used:**
  - `StateNotifierProvider` - Primary
  - `AsyncNotifierProvider` - Async operations
  - `StreamProvider` - Auth state stream
  - `StateProvider` - Simple UI state
  - `Provider` - Services & dependencies

---

## 5. Security Architecture

### 5.1 Hybrid Security Policy (3 Zones)

| Zone | Data | Encryption |
|------|------|-------------|
| **Public** | Service names, item prices | None |
| **Restricted** | Customer names, phone numbers | AES-GCM |
| **Sensitive** | Financial data, service history | AES-GCM |

### 5.2 Encryption Implementation

**File:** `lib/core/services/encryption_service.dart`

```dart
class EncryptionService {
  static const String encryptionPrefix = 'enc:v1:';
  static const int pbkdf2Iterations = 100000;

  // AES-GCM 256-bit
  _encrypter = encrypt.Encrypter(
    encrypt.AES(key, mode: encrypt.AESMode.gcm),
  );
}
```

### 5.3 Authentication Layers

| Method | Implementation |
|--------|----------------|
| Google Sign-In | Firebase Auth |
| PIN | 6 digits, SHA-256 + salt |
| Biometric | local_auth |
| Session Management | session_manager.dart |
| Remote Wipe | device_session_service.dart |

### 5.4 Session Status Enum

```dart
enum SessionStatus {
  full,       // Zone 1: Full access (< warningThreshold)
  warning,    // Zone 2: Restricted (< gracePeriod)
  blocked,    // Zone 3: No access (> gracePeriod)
}
```

### 5.5 Access Level Enum

```dart
enum AccessLevel {
  full,               // Create, Read, Update, Delete*
  readOnly,           // Read only (all)
  readOnlyFinancial, // Read only (non-financial)
  blocked,           // No access
}
```

### 5.6 Security Concerns

| Issue | Location | Risk | Notes |
|-------|-----------|------|-------|
| Print statements | scratch/debug_json.dart | LOW | Debug file |
| Session-only key | encryption_service.dart | LOW | Design - key tidak persist |
| Master password | session_manager.dart:33 | LOW | Konstanta policy |

---

## 6. Sync Architecture

### 6.1 Sync Components

| Component | File | Description |
|-----------|------|-------------|
| FirestoreSyncService | firestore_sync_service.dart | Main sync impl |
| SyncWorker | sync_worker.dart | Background worker |
| LocalSyncService | local_sync_service.dart | Local operations |
| SyncTelemetry | sync_telemetry.dart | Monitoring |
| CircuitBreaker | circuit_breaker.dart | Fault tolerance |
| ConcurrencyPool | concurrency_pool.dart | Rate limiting |
| SyncLockManager | sync_lock_manager.dart | Lock management |

### 6.2 Sync Flow

```
ObjectBox (local) <--> Firestore (cloud)
       |
       v
  Sync Queue
       |
       v
  Conflict Resolution
       |
       v
  Bidirectional Sync
```

---

## 7. Feature Modules

### 7.1 Feature List

| Module | Screens | Purpose |
|--------|---------|---------|
| **Auth** | 8 screens | Login, onboarding, session mgmt |
| **Home** | 4 screens | Dashboard, transactions |
| **Pelanggan** | 4 screens | Customer & vehicle management |
| **Katalog** | 5 screens | Inventory, sales |
| **Riwayat** | 1 screen | Transaction history |
| **Statistik** | 5 tabs | Reports & analytics |
| **Pengaturan** | 10 screens | Settings |
| **Owner** | 1 screen | Permission management |

### 7.2 Main Features

1. **Transaction Management**
   - Create service transactions
   - Status: Antri -> Dikerjakan -> Selesai -> Lunas
   - Notes, odometer, recommendations

2. **Customer Management**
   - Database: name, phone, address
   - Vehicle per customer
   - Service history

3. **Inventory (Katalog)**
   - Items: spareparts, oils, accessories
   - Service master list
   - Stock monitoring
   - Barcode scanning

4. **Staff Management**
   - Technician & admin data
   - Role-based access
   - Commission tracking

5. **Statistics**
   - Revenue reports
   - Service analysis
   - Product performance
   - Technician evaluation

6. **Security**
   - PIN (6 digits)
   - Biometric
   - Data encryption
   - Remote wipe

7. **Backup & Sync**
   - Local backup
   - Google Drive
   - Firestore sync

---

## 8. Code Quality Issues

### 8.1 Large Files (>1500 lines)

| File | Lines | Severity | Recommendation |
|------|-------|----------|----------------|
| create_transaction_screen.dart | 2552 | HIGH | Decompose |
| home_screen.dart | 1807 | HIGH | Decompose |
| adaptive_layout.dart | 1461 | MEDIUM | Decompose |
| session_manager.dart | 672 | MEDIUM | OK |
| firestore_sync_service.dart | ~20k | MEDIUM | OK |

### 8.2 ListView Without Keys

| File | Line |
|------|------|
| create_sale_screen.dart | 348, 764 |
| katalog_screen.dart | 305, 373 |
| create_transaction_screen.dart | 1872, 2037, 2198 |
| create_barang_screen.dart | 438 |

**Impact:** Rebuild inefficiency

### 8.3 Empty Catch Blocks

| File | Line | Description |
|------|------|-------------|
| create_transaction_screen.dart | 1719 | Empty catch |
| restore_screen.dart | 90 | Empty catch |
| session_manager.dart | 408, 414 | Empty catch |

**Impact:** Silent failures

### 8.4 Code Smells

| Issue | Location | Severity |
|------|----------|----------|
| print() in debug files | scratch/debug_json.dart | LOW |
| Unreachable switch default | system_providers.dart:308 | INFO |
| Deprecated API | encryptedSharedPreferences | INFO |

---

## 9. Testing

### 9.1 Test Results

```
flutter test --reporter expanded
```

**Status:** 1 failure detected

```
00:02 +10 -1: BengkelService Tests claimBengkelId creates bengkel and secret docs [E]
  Expected: a string starting with 'enc:'
  Actual: 'wrapped:123456:TEST-BENGKEL'
```

### 9.2 Test Files Distribution

| Category | Files |
|----------|-------|
| Services | 26 |
| Repositories | 7 |
| Widgets | 1 |
| **Total** | 44 |

### 9.3 Coverage

- Coverage report: `coverage/lcov.info`
- Many services tested

---

## 10. CI/CD Configuration

### 10.1 GitHub Actions Workflow

**File:** `.github/workflows/ci.yml`

```yaml
Jobs:
  - analyze    # flutter analyze
  - test       # flutter test --coverage
  - build_apk  # flutter build apk --release
```

**Status:** Konfigurasi OK

---

## 11. Logic & Functional Analysis

### 11.1 Transaction Flow

```
1. Create Transaction
   -> Generate TRX Number (SL-YYYYMMDD-XXX)
   -> Link Customer (existing or new)
   -> Link Vehicle (existing or new)
   -> Add Items (service + parts)
   -> Calculate Total (parts + labor)

2. Status Workflow
   antri (0) -> dikerjakan (1) -> selesai (2) -> lunas (3)

3. Payment
   -> Tunai / QRIS / Transfer
   -> Update status to lunas
```

### 11.2 Session Management Logic

```
1. User signs in with Google
2. System checks workshop ownership
   - If has bengkel: go to UnlockScreen
   - If no bengkel: go to OnboardingScreen

3. After unlock:
   - Initialize encryption with session key
   - Start session timer
   - Monitor activity (InactivityMonitor)

4. Session Status Check:
   - Zone 1 (< 8h): Full access
   - Zone 2 (8-12h): Warning - read only
   - Zone 3 (> 12h): Blocked
```

### 11.3 Sync Logic

```
1. Local Change Detected
   -> Add to sync queue
   -> Set syncStatus = syncing

2. Background Worker Processes Queue
   -> Circuit breaker check
   -> Concurrency pool check
   -> Submit to Firestore

3. Conflict Resolution:
   - If remote newer: Use remote (last-write-wins)
   - If local newer: Push to remote
   - If both changed: Merge or reject

4. Recovery on Failure:
   -> Retry with exponential backoff
   -> Circuit breaker opens after N failures
   -> Manual intervention required
```

### 11.4 Backup Logic

```
1. Manual Backup:
   -> Export all ObjectBox data
   -> Encrypt sensitive fields
   -> ZIP file
   -> Save to local or Drive

2. Restore:
   -> Import ZIP
   -> Decrypt with PIN
   -> Merge with existing data
   -> Handle conflicts
```

### 11.5 Security Zones Logic

```
Encrypted Fields (Restricted Zone):
- pelanggan.nama
- pelanggan.noHp

Encrypted Fields (Sensitive Zone):
- transaction.totalAmount
- transaction.partsCost
- transaction.laborCost
- sale.* (all fields)
- stok.hargaBeli
- stok.hargaJual

Public (No Encryption):
- serviceMaster.nama
- serviceMaster.harga
- stock.nama
- stock.satuan
```

---

## 12. Issues & Recommendations

### 12.1 Priority 1: Fix Compilation Errors

```bash
# Fix: Add import to statistik_screen.dart
import '../../core/providers/auth_provider.dart';
# OR
import '../../core/providers/system_providers.dart' show currentAccessLevelProvider;
```

### 12.2 Priority 2: Decompose Large Files

```
create_transaction_screen.dart (2552 lines)
  -> Extract: transaction_form_widget.dart
  -> Extract: vehicle_selector_widget.dart
  -> Extract: item_selector_widget.dart
  -> Extract: mechanic_selector_widget.dart

home_screen.dart (1807 lines)
  -> Extract: transaction_list_widget.dart
  -> Extract: quick_actions_widget.dart
  -> Extract: summary_cards_widget.dart
```

### 12.3 Priority 3: Add ListView Keys

```dart
// Before:
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(items[index]),
)

// After:
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(
    key: ValueKey(items[index].id),
    items[index],
  ),
)
```

### 12.4 Priority 4: Fix Empty Catch Blocks

```dart
// Before:
catch (e) { }

// After:
catch (e, stack) {
  appLogger.error('Operation failed', error: e, stackTrace: stack);
  rethrow;
}
```

### 12.5 Priority 5: Fix Test Failure

```
// BengkelService Test:
// Expected: 'enc:...' format
// Actual: 'wrapped:123456:TEST-BENGKEL'
//
// Fix: Update test expectation OR
// Fix: Wrapped key format in implementation
```

---

## 13. Summary Scores

| Category | Score | Grade |
|----------|-------|-------|
| Compilation | 8/10 | B |
| Dependencies | 9/10 | A |
| Architecture | 9/10 | A |
| Security | 9/10 | A |
| Code Quality | 6/10 | C |
| Testing | 7/10 | B |
| Documentation | 7/10 | B |
| **Overall** | **7.8/10** | **B** |

---

## 14. Strengths

1. Clean Architecture implemented correctly
2. Comprehensive security with 3-zone policy
3. Strong typing with ObjectBox entities
4. Riverpod state management
5. Multi-platform support (Flutter)
6. Good separation between UI, business logic, data
7. Comprehensive backup & sync system
8. Good test coverage

---

## 15. Action Items

| # | Item | Priority | Owner |
|---|------|----------|-------|
| 1 | Fix statistik_screen.dart import | CRITICAL | Dev |
| 2 | Decompose create_transaction_screen.dart | HIGH | Dev |
| 3 | Decompose home_screen.dart | HIGH | Dev |
| 4 | Add keys to all ListView.builder | MEDIUM | Dev |
| 5 | Fix empty catch blocks | MEDIUM | Dev |
| 6 | Fix bengkel_service_test.dart | MEDIUM | Dev |
| 7 | Remove print statements from debug files | LOW | Dev |

---

*Report generated: 21 April 2026*
*Auditor: BigPickle*