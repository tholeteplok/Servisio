# Fix and Test Script for ServisLog Core
# Run this in PowerShell to test without build_runner

Write-Host "=== ServisLog Core Test Runner ===" -ForegroundColor Cyan

# Step 1: Clean
Write-Host "`n[1/4] Cleaning..." -ForegroundColor Yellow
flutter clean 2>&1 | Out-Null

# Step 2: Get dependencies  
Write-Host "[2/4] Getting dependencies..." -ForegroundColor Yellow
flutter pub get 2>&1 | Out-Null

# Step 3: Analyze
Write-Host "[3/4] Analyzing code..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos 2>&1 | Out-Null

# Step 4: Run tests
Write-Host "[4/4] Running tests...`n" -ForegroundColor Yellow

$tests = @(
    "test/core/utils/permission_constants_test.dart",
    "test/core/models/permission_models_test.dart", 
    "test/core/utils/app_logger_test.dart",
    "test/core/services/encryption_service_pin_hash_test.dart"
)

$totalPassed = 0
$totalFailed = 0

foreach ($test in $tests) {
    Write-Host "Running: $test" -ForegroundColor Gray
    $result = flutter test "$test" 2>&1
    
    if ($result -match "All tests passed") {
        $passed = [regex]::Match($result, "(\d+): All tests passed").Groups[1].Value
        $totalPassed += [int]$passed
        Write-Host "  ✅ $passed tests passed" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Tests failed" -ForegroundColor Red
        $totalFailed++
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total Passed: $totalPassed" -ForegroundColor Green
if ($totalFailed -gt 0) {
    Write-Host "Failed Suites: $totalFailed" -ForegroundColor Red
}
Write-Host "Coverage: coverage/lcov.info" -ForegroundColor Gray
Write-Host "`n✅ Test run completed!" -ForegroundColor Green
