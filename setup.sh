#!/usr/bin/env bash
# PEW Smart Home - one-time setup on macOS/Linux. Run from inside this folder: bash setup.sh
set -e
command -v flutter >/dev/null || { echo "Flutter is not installed or not on PATH."; exit 1; }
flutter create --org rw.physician --project-name pew_smarthome --platforms android,ios .
bash patch_android.sh
rm -f test/widget_test.dart
flutter pub get
flutter analyze
echo "Done. Run: flutter run   |   Build APK: flutter build apk --release"
