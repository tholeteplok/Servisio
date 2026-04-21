# ServisLog+ Audit Report

**Tanggal Audit:** 21 April 2026  
**Version:** 1.2 (ServisLog_core_1.2)  
**Platform:** Flutter (Android, iOS, Windows, macOS, Linux, Web)

---

## 1. Eksekusi & Dependencies

### 1.1 Flutter Environment
- **SDK:** ^3.11.4
- **Flutter Version:** Multi-platform support
- **Build Tools:** build_runner, objectbox_generator, riverpod_generator

### 1.2 Key Dependencies

| Category | Package | Version |
|----------|---------|---------|
| State Management | flutter_riverpod | ^2.5.1 |
| State Management | riverpod_annotation | ^2.3.5 |
| Database | objectbox | ^2.5.1 |
| Database | objectbox_flutter_libs | ^2.5.1 |
| Firebase | firebase_core | ^3.1.0 |
| Firebase | cloud_firestore | ^5.0.0 |
| Firebase | firebase_auth | ^5.1.0 |
| Firebase | firebase_storage | ^12.1.0 |
| Firebase | firebase_crashlytics | ^4.0.0 |
| Security | flutter_secure_storage | ^10.0.0 |
| Security | encrypt | ^5.0.3 |
| Security | crypto | ^3.0.7 |
| Auth | google_sign_in | ^6.2.1 |
| Auth | local_auth | ^2.3.0 |
| UI | google_fonts | ^8.0.2 |
| UI | fl_chart | ^0.70.2 |
| UI | shimmer | ^3.0.0 |
| Utils | intl | ^0.19.0 |
| Utils | logger | ^2.0.2 |
| Utils | uuid | ^4.4.0 |
| Utils | mobile_scanner | ^5.2.3 |
| Utils | pdf | ^3.11.1 |
| Utils | printing | ^5.13.2 |

### 1.3 Dependency Issues

| Issue | Description | Severity |
|-------|-------------|----------|
| Deprecated | `encryptedSharedPreferences` - Jetpack Security library deprecated | MEDIUM |
| Duplicate Export | `authStateProvider` defined in both `auth_provider.dart` and `system_providers.dart` | HIGH |
| Duplicate Export | `authServiceProvider` defined in both `auth_provider.dart` and `system_providers.dart` | HIGH |
| Duplicate Export | `firestoreSyncServiceProvider` ambiguous import | HIGH |

---

## 2. Arsitektur & Kode Structure

### 2.1 Clean Architecture Layers

```
lib/
├── main.dart                    # Entry point
├── objectbox.g.dart           # Generated ObjectBox code
│
├── core/                    # Core utilities & infrastructure
│   ├── config/             # App configuration
│   ├── constants/          # Theme, colors, strings, icons
│   ├── models/             # Data models
│   ├── providers/          # Riverpod providers
│   ├── services/          # Core services (21 services)
│   ├── sync/             # Sync infrastructure
│   ├── utils/            # Utilities
│   └── widgets/          # Reusable widgets
│
├── domain/                  # Domain layer
│   └── entities/          # Business entities (11 entities)
│       ├── transaction.dart
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
├── data/                   # Data layer
│   └── repositories/       # Repository implementations
│       ├── transaction_repository.dart
│       ├── pelanggan_repository.dart
│       ├── stok_repository.dart
│       ├── sale_repository.dart
│       ├── stok_history_repository.dart
│       └── master_repositories.dart
│
└── features/              # Presentation layer
    ├── auth/             # Authentication
    ├── home/             # Home & transactions
    ├── pelanggan/       # Customer management
    ├── katalog/         # Inventory/catalog
    ├── riwayat/        # History
    ├── statistik/       # Statistics/dashboard
    ├── pengaturan/      # Settings
    └── main/           # Main layout
```

### 2.2 State Management

- **Pattern:** Riverpod dengan StateNotifier
- **Types Used:**
  - `StateNotifierProvider` - Primary state management
  - `AsyncNotifierProvider` - Async operations
  - `StreamProvider` - Auth state stream
  - `StateProvider` - Simple UI state

### 2.3 Security Architecture

**Hybrid Security Policy (3 Zones):**

1. **Public Zone** - No encryption
   - Service names, item prices

2. **Restricted Zone** - Basic encryption
   - Customer names (encrypted)
   - Phone numbers (encrypted)

3. **Sensitive Zone** - Strict encryption
   - Financial data
   - Service history

**Encryption:**
- Algorithm: AES-GCM 256-bit
- Key Derivation: PBKDF2-HMAC-SHA256
- Iterations: 100,000 (OWASP compliant)
- IV: Random 12-byte per encryption

### 2.4 Sync Architecture

- ObjectBox (local) <-> Firestore (cloud)
- Bidirectional sync with conflict resolution
- Circuit breaker pattern
- Sync queue for offline operations

---

## 3. Quality Issues

### 3.1 Error (Blocking Issues)

| Error | File | Line | Description |
|-------|------|------|-------------|
| undefined_class | lib/core/providers/objectbox_provider.dart | 60 | Undefined class 'FutureOr' |
| ambiguous_import | lib/core/providers/sync_provider.dart | 60 | firestoreSyncServiceProvider defined in two libraries |
| undefined_identifier | lib/core/services/device_session_service.dart | 278 | isWipingProvider not found |
| undefined_identifier | lib/core/services/firestore_sync_service.dart | 612 | encryptionServiceProvider not found |
| undefined_identifier | lib/core/widgets/critical_action_guard.dart | 43 | sessionManagerProvider not found |
| undefined_identifier | lib/core/widgets/critical_action_guard.dart | 44 | biometricServiceProvider not found |
| undefined_identifier | lib/core/widgets/critical_action_guard.dart | 48 | accessLevelProvider not found |
| undefined_identifier | lib/core/widgets/session_status_bar.dart | 30 | accessLevelProvider not found |
| ambiguous_import | lib/features/auth/screens/create_bengkel_screen.dart | 191 | authStateProvider ambiguous |
| ambiguous_import | lib/features/auth/screens/onboarding_screen.dart | 126 | authServiceProvider ambiguous |
| ambiguous_import | lib/features/auth/screens/onboarding_screen.dart | 366 | authStateProvider ambiguous |
| undefined_identifier | lib/features/auth/screens/session_displaced_screen.dart | 58 | deviceSessionServiceProvider not found |
| undefined_identifier | lib/features/auth/screens/sync_restore_screen.dart | 85 | sessionManagerProvider not found |
| undefined_identifier | lib/features/auth/screens/unlock_screen.dart | 44 | encryptionServiceProvider not found |
| undefined_identifier | lib/features/auth/screens/unlock_screen.dart | 45 | biometricServiceProvider not found |
| undefined_identifier | lib/features/auth/screens/unlock_screen.dart | 92 | encryptionServiceProvider not found |
| undefined_identifier | lib/features/auth/screens/unlock_screen.dart | 93 | biometricServiceProvider not found |
| undefined_identifier | lib/features/auth/screens/unlock_screen.dart | 130 | encryptionServiceProvider not found |
| undefined_identifier | lib/features/auth/screens/unlock_screen.dart | 131 | biometricServiceProvider not found |
| undefined_identifier | lib/features/home/home_screen.dart | 1733 | accessLevelProvider not found |

### 3.2 Warnings

| Warning | File | Line | Description |
|---------|------|------|-------------|
| unreachable_switch_default | lib/core/providers/system_providers.dart | 308 | Default clause covered by previous cases |
| invalid_use_of_visible_for_testing_member | lib/features/main/adaptive_layout.dart | 260 | StateNotifier.state accessed externally |
| invalid_use_of_protected_member | lib/features/main/adaptive_layout.dart | 260 | Protected member accessed |
| invalid_use_of_visible_for_testing_member | lib/features/main/adaptive_layout.dart | 266 | StateNotifier.state accessed externally |
| invalid_use_of_protected_member | lib/features/main/adaptive_layout.dart | 266 | Protected member accessed |

### 3.3 Info

| Info | File | Line | Description |
|------|------|------|-------------|
| deprecated_member_use | lib/core/providers/system_providers.dart | 38 | encryptedSharedPreferences deprecated |
| curly_braces_in_flow_control_structures | lib/core/providers/transaction_providers.dart | 84 | Missing curly braces in if statement |

### 3.4 Code Smell - Files

| File | Lines | Issue | Severity |
|------|-------|------|----------|
| lib/objectbox.g.dart | 2696 | Auto-generated, massive file | N/A |
| lib/features/home/create_transaction_screen.dart | 2552 | Very large widget | HIGH |
| lib/features/home/home_screen.dart | 1807 | Large widget | HIGH |
| lib/features/main/adaptive_layout.dart | 1461 | Large widget with deep nesting | MEDIUM |
| lib/core/services/session_manager.dart | 28349 | Large service class | MEDIUM |
| lib/core/services/sync_worker.dart | 27253 | Large sync service | MEDIUM |
| lib/core/services/firestore_sync_service.dart | 20593 | Large sync service | MEDIUM |

### 3.5 Code Smell - Empty Catch Blocks

| File | Line | Description |
|------|------|-------------|
| lib/features/home/create_transaction_screen.dart | 1719 | Empty catch block |
| lib/features/pengaturan/sub/restore_screen.dart | 90 | Empty catch block |
| lib/core/services/session_manager.dart | 408 | Empty catch block |
| lib/core/services/session_manager.dart | 414 | Empty catch block |

### 3.6 Code Smell - Missing Keys in ListView

| File | Line | Issue |
|------|------|-------|
| lib/features/katalog/create_sale_screen.dart | 348 | ListView without key |
| lib/features/katalog/create_sale_screen.dart | 764 | ListView without key |
| lib/features/katalog/katalog_screen.dart | 305 | ListView without key |
| lib/features/katalog/katalog_screen.dart | 373 | ListView without key |
| lib/features/home/create_transaction_screen.dart | 1872 | ListView without key |
| lib/features/home/create_transaction_screen.dart | 2037 | ListView without key |
| lib/features/home/create_transaction_screen.dart | 2198 | ListView without key |
| lib/features/katalog/create_barang_screen.dart | 438 | ListView.separated missing key |

### 3.7 Code Smell - Print Statements

| File | Line | Content |
|------|------|---------|
| scratch/debug_json.dart | 19 | print('isEncrypted: $isEncrypted') |
| scratch/debug_json.dart | 20 | print('bengkelId: $bengkelId') |
| scratch/debug_json.dart | 24-26 | Multiple print statements |
| lib/core/utils/app_logger.dart | 123 | Uses print as fallback |

---

## 4. Security

### 4.1 Security Features Implemented

| Feature | Status | Implementation |
|---------|--------|----------------|
| AES-GCM 256-bit Encryption | OK | encryption_service.dart |
| PBKDF2 Key Derivation | OK | 100,000 iterations |
| Biometric Authentication | OK | local_auth |
| PIN Authentication | OK | 6 digits |
| Google Sign-In | OK | firebase_auth |
| Secure Storage | OK | flutter_secure_storage |
| Session Management | OK | session_manager.dart |
| Remote Wipe | OK | device_session_service.dart |

### 4.2 Security Concerns

| Issue | File | Line | Risk Level |
|-------|------|------|-----------|
| print() statements in scratch | scratch/debug_json.dart | Multiple | LOW |
| Hardcoded key alias | encryption_service.dart | 25 | LOW (acceptable) |
| Sensitive keys list | app_logger.dart | 100 | LOW (configurable) |

### 4.3 Security Best Practices

- Encryption key stored in memory only (not persisted)
- Session timeout management
- Access level enforcement
- Critical action guards in place
- Encryption zones properly implemented

---

## 5. Performance

### 5.1 Performance Concerns

| Issue | File | Impact |
|-------|------|--------|
| ListView without keys | Multiple screens | Rebuild inefficiency |
| Large widget files | create_transaction_screen.dart | Slow hot reload |
| Deep nesting | adaptive_layout.dart | Render complexity |
| Multiple .add() on lists | sync_worker.dart, firestore_sync_service.dart | Memory allocation |

### 5.2 Performance Recommendations

1. **Add keys to all ListView builders** - For efficient rebuilds
2. **Decompose large widgets** - Extract to smaller components
3. **Use const constructors** - Where applicable
4. **Implement lazy loading** - For large lists

---

## 6. Testing

### 6.1 Test Files

Total: 44 test files

| Category | Files |
|----------|-------|
| Services | 26 |
| Repositories | 7 |
| Widgets | 1 |
| Total Tests | 44 |

### 6.2 Test Issues

| Error | File | Line | Description |
|-------|------|------|-------------|
| undefined_getter | reminder_service_test.dart | 88 | StateNotifier has no .future getter |
| unchecked_use_of_nullable_value | reminder_service_test.dart | 89 | Nullable length access |
| undefined_getter | service_records_service_test.dart | 64 | .future getter |
| undefined_identifier | session_manager_test.dart | 44 | sessionManagerProvider |
| undefined_getter | stats_provider_test.dart | 75, 138, 156 | .future getter |
| undefined_getter | technician_service_test.dart | 40, 63 | .future getter |
| undefined_getter | transaksi_service_test.dart | 43 | .future getter |
| undefined_getter | vehicle_service_test.dart | 38 | .future getter |

### 6.3 Coverage

- Coverage report available: `coverage/lcov.info`
- Many services tested but with provider access issues

---

## 7. Rekomendasi Perbaikan

### 7.1 PRIORITY 1 - Fix Errors (Blocking)

```bash
# 1. Add missing provider exports
# - lib/core/widgets/critical_action_guard.dart needs:
#   - sessionManagerProvider
#   - biometricServiceProvider
#   - accessLevelProvider
# - lib/features/auth/screens/unlock_screen.dart needs:
#   - encryptionServiceProvider
#   - biometricServiceProvider
#   - bengkelServiceProvider
# - lib/features/home/home_screen.dart needs:
#   - accessLevelProvider

# 2. Fix ambiguous imports
# - Create single provider exports file
# - Or use 'show'/'hide' in imports
```

### 7.2 PRIORITY 2 - Decompose Large Files

```
create_transaction_screen.dart (2552 lines)
  -> Extract to:
    - transaction_form_widget.dart
    - vehicle_selector_widget.dart
    - item_selector_widget.dart
    - mechanic_selector_widget.dart

home_screen.dart (1807 lines)
  -> Extract to:
    - transaction_list_widget.dart
    - quick_actions_widget.dart
    - summary_cards_widget.dart
```

### 7.3 PRIORITY 3 - Fix Performance Issues

```
1. Add keys to all ListView builders:
   - Use ObjectKey or ValueKey
   - Example: key: ValueKey(item.id)

2. Use const constructors:
   - const StandardDialog()
   - const AtelierHeader()

3. Fix empty catch blocks:
   - Add proper error handling
   - Log errors appropriately
```

### 7.4 PRIORITY 4 - Code Quality

```
1. Remove debug files:
   - scratch/debug_json.dart
   - Move to test or delete

2. Add documentation:
   - DartDoc for public APIs
   - Entity classes documentation

3. Add TODO completion:
   - encryption_service.dart: Firebase Crashlytics integration
   - transaction_number_service.dart: format
```

---

## 8. Summary

| Category | Count | Severity |
|----------|-------|----------|
| Errors | 20+ | CRITICAL |
| Warnings | 5 | HIGH |
| Code Smells | 30+ | MEDIUM |
| Large Files | 4 | HIGH |
| Test Issues | 15+ | MEDIUM |

### Overall Assessment

**Project Status:**Perlu perbaikan sebelum production release

**Strengths:**
- Clean Architecture implemented correctly
- Security features comprehensive
- Good separation of concerns
- Multiple platform support

**Areas for Improvement:**
- Fix compilation errors
- Decompose large files
- Fix ListView keys
- Add proper error handling
- Improve test coverage

---

*Report generated: 21 April 2026*