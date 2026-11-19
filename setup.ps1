# PEW Smart Home - one-time setup on Windows (PowerShell).
# Run from inside this folder:   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter is not installed or not on PATH. Install it from https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Red
    exit 1
}

# Create the Android/iOS platform folders around our lib/ (keeps our files).
flutter create --org rw.physician --project-name pew_smarthome --platforms android,ios .

# Android settings: manifest, phone lock, notifications, Kotlin cache fix.
powershell -ExecutionPolicy Bypass -File .\patch_android.ps1

# flutter create adds a counter-app test that does not apply to this app.
if (Test-Path .\test\widget_test.dart) { Remove-Item .\test\widget_test.dart }

flutter pub get
flutter analyze
Write-Host ""
Write-Host "Done. Connect a phone (USB debugging on) and run:  flutter run" -ForegroundColor Green
Write-Host "Build an installable APK with:                   flutter build apk --release" -ForegroundColor Green
