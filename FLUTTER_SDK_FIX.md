# Flutter SDK Fix Guide

## 🔴 Problem
Missing `frontend_server.dart.snapshot` file in Flutter SDK
- Location: `C:\flutter\bin\cache\dart-sdk\bin\snapshots\`
- Required for: `flutter pub run build_runner build`

## ✅ Current Status
- `flutter doctor` ✅ Working
- `flutter test` ✅ Working  
- `flutter build` ✅ Working
- `build_runner` ❌ Not working

---

## 🔧 Solution Options

### Option 1: Quick Workaround - Skip build_runner (Recommended)
Since your tests are working, you can manually create the mock files:

```bash
# Tests work without build_runner
flutter test test/core/utils/permission_constants_test.dart
flutter test test/core/models/permission_models_test.dart
flutter test test/core/utils/app_logger_test.dart
flutter test test/core/services/encryption_service_pin_hash_test.dart
```

**For mock files**, manually create them or use existing ones in `test/mocks/`.

---

### Option 2: Reinstall Flutter (Clean Fix)

**Step 1: Backup your Flutter config**
```powershell
# Save your Flutter settings
flutter config --list > flutter-config-backup.txt
```

**Step 2: Delete Flutter folder**
```powershell
# Run in PowerShell as Administrator
Remove-Item -Recurse -Force "C:\flutter"
```

**Step 3: Download & Install Fresh Flutter**
```powershell
# Download Flutter 3.41.7 stable
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.7-stable.zip" -OutFile "$env:TEMP\flutter.zip"

# Extract to C:\
Expand-Archive -Path "$env:TEMP\flutter.zip" -DestinationPath "C:\"

# Verify
flutter doctor
```

**Step 4: Restore pub packages**
```bash
cd c:\Users\fabian nuriel\ServisLog_core_1.2
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Option 3: Use Dart SDK Directly (Alternative)

If `flutter pub run` fails, use `dart run`:

```bash
# Install build_runner globally
dart pub global activate build_runner

# Run with dart directly
dart run build_runner build --delete-conflicting-outputs
```

---

### Option 4: VS Code / IDE Build Runner Extension

Use IDE extensions to handle code generation:

1. **VS Code**: Install "Dart" and "Flutter" extensions
2. Enable setting: `dart.previewBuildRunnerTasks`
3. Use IDE commands for code generation instead of CLI

---

## 📝 Immediate Workaround Script

Create `fix-and-test.ps1`:

```powershell
# Fix and Test Script for ServisLog Core

Write-Host "=== ServisLog Core Test Runner ===" -ForegroundColor Cyan

# Step 1: Clean
Write-Host "`n[1/4] Cleaning..." -ForegroundColor Yellow
flutter clean

# Step 2: Get dependencies  
Write-Host "`n[2/4] Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Step 3: Analyze
Write-Host "`n[3/4] Analyzing code..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos

# Step 4: Run tests (without build_runner)
Write-Host "`n[4/4] Running tests..." -ForegroundColor Yellow
flutter test test/core/utils/permission_constants_test.dart
flutter test test/core/models/permission_models_test.dart
flutter test test/core/utils/app_logger_test.dart
flutter test test/core/services/encryption_service_pin_hash_test.dart

Write-Host "`n✅ Tests completed!" -ForegroundColor Green
```

Run with:
```powershell
.\fix-and-test.ps1
```

---

## 🎯 Current Recommendation

Since **54 tests are passing** and your main functionality works:

1. **Continue development** with existing tests
2. **Defer build_runner** until you need code generation
3. **Reinstall Flutter** when convenient (e.g., weekend)

---

## 🔍 Verification Commands

Check if fix worked:
```bash
# Test 1: Flutter doctor
flutter doctor

# Test 2: Unit tests
flutter test

# Test 3: Build runner (after fix)
flutter pub run build_runner build --delete-conflicting-outputs

# Test 4: Build app
flutter build apk --debug
```

---

## 📊 Test Results Summary

| Test File | Tests | Status |
|-----------|-------|--------|
| permission_constants_test.dart | 17 | ✅ Pass |
| permission_models_test.dart | 10 | ✅ Pass |
| app_logger_test.dart | 13 | ✅ Pass |
| encryption_service_pin_hash_test.dart | 14 | ✅ Pass |
| **Total** | **54** | **✅ All Pass** |

Coverage file generated: `coverage/lcov.info`
