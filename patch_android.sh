#!/usr/bin/env bash
# Applies the Android settings this app needs. Safe to run more than once.
set -e
cp -f android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
for f in $(find android/app/src/main -name 'MainActivity.kt' -o -name 'MainActivity.java'); do
  grep -q FlutterFragmentActivity "$f" || sed -i.bak -e 's/io\.flutter\.embedding\.android\.FlutterActivity/io.flutter.embedding.android.FlutterFragmentActivity/' -e 's/\bFlutterActivity\b/FlutterFragmentActivity/g' "$f" && rm -f "$f.bak"
done
G=android/app/build.gradle.kts
if [ -f "$G" ]; then
  grep -q isCoreLibraryDesugaringEnabled "$G" || sed -i.bak 's/compileOptions *{/compileOptions {\n        isCoreLibraryDesugaringEnabled = true/' "$G"
  grep -q desugar_jdk_libs "$G" || printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$G"
  rm -f "$G.bak"
fi
grep -q 'kotlin.incremental=false' android/gradle.properties || printf '\nkotlin.incremental=false\n' >> android/gradle.properties
echo "Android patch done."
