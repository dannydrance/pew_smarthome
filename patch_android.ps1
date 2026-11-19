# Applies the Android settings this app needs. Safe to run more than once.
# Run from the project folder:  powershell -ExecutionPolicy Bypass -File .\patch_android.ps1
$ErrorActionPreference = "Stop"
function Save($path, $text) { [System.IO.File]::WriteAllText((Resolve-Path $path), $text) }

# 1. Manifest: internet, biometric/PIN lock, notifications, links to WhatsApp/phone/email.
Copy-Item -Force .\android_overrides\AndroidManifest.xml .\android\app\src\main\AndroidManifest.xml
Write-Host "Manifest updated"

# 2. Phone lock (local_auth) needs a FragmentActivity.
Get-ChildItem .\android\app\src\main -Recurse -Include MainActivity.kt,MainActivity.java | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName)
    if ($t -notmatch "FlutterFragmentActivity") {
        $t = $t -replace "io\.flutter\.embedding\.android\.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity"
        $t = $t -replace "\bFlutterActivity\b", "FlutterFragmentActivity"
        Save $_.FullName $t
    }
    Write-Host "MainActivity uses FlutterFragmentActivity: $($_.Name)"
}

# 3. Notifications plugin needs Java 8+ library desugaring.
$kts = ".\android\app\build.gradle.kts"
$groovy = ".\android\app\build.gradle"
if (Test-Path $kts) {
    $t = [System.IO.File]::ReadAllText((Resolve-Path $kts))
    if ($t -notmatch "isCoreLibraryDesugaringEnabled") {
        $t = $t -replace "compileOptions\s*\{", "compileOptions {`n        isCoreLibraryDesugaringEnabled = true"
    }
    if ($t -notmatch "desugar_jdk_libs") {
        $t = $t.TrimEnd() + "`n`ndependencies {`n    coreLibraryDesugaring(""com.android.tools:desugar_jdk_libs:2.1.4"")`n}`n"
    }
    Save $kts $t
    Write-Host "build.gradle.kts: desugaring enabled"
} elseif (Test-Path $groovy) {
    $t = [System.IO.File]::ReadAllText((Resolve-Path $groovy))
    if ($t -notmatch "coreLibraryDesugaringEnabled") {
        $t = $t -replace "compileOptions\s*\{", "compileOptions {`n        coreLibraryDesugaringEnabled true"
    }
    if ($t -notmatch "desugar_jdk_libs") {
        $t = $t.TrimEnd() + "`n`ndependencies {`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'`n}`n"
    }
    Save $groovy $t
    Write-Host "build.gradle: desugaring enabled"
}

# 4. Project and Flutter package cache on different drives (A: and C:): avoid Kotlin cache errors.
$props = ".\android\gradle.properties"
if (-not (Select-String -Path $props -Pattern "kotlin.incremental=false" -Quiet)) {
    Add-Content $props "`nkotlin.incremental=false"
}
Write-Host "Android patch done." -ForegroundColor Green
