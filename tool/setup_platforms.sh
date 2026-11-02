#!/usr/bin/env bash
# Creates the rest of the android/ folder with `flutter create`.
#
# The repo keeps only the Android files this app customises (manifest,
# MainActivity, theme, icon, backup rules). `flutter create` never overwrites
# files that exist, so it only adds the missing ones (Gradle files, launcher
# PNGs for old phones).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org com.iamsaifsaiful --project-name riyal_hisab .

GRADLE_KTS="android/app/build.gradle.kts"
if [ ! -f "$GRADLE_KTS" ]; then
  echo "Expected $GRADLE_KTS" >&2
  exit 1
fi

# local_auth needs Android 7.0 (API 24) or newer.
sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(24, flutter.minSdkVersion)/' "$GRADLE_KTS"

# Core library desugaring (some plugins need it), Firebase messaging (push); the AppCompat theme
# (for the fingerprint dialog) needs androidx.appcompat.
if ! grep -q 'desugar_jdk_libs' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.13.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Push from the shop's server; started at run time with the server's settings.
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-messaging")
}
KTS
fi

# A permanent release key (from CI secrets, written to android/key.properties)
# so every new APK installs over the old one. Without it the debug key is
# used, which differs from build to build.
if ! grep -q 'releaseKeys' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

val releaseKeys: Map<String, String> = rootProject.file("key.properties").let { f ->
    if (f.exists()) {
        f.readLines().filter { it.contains("=") }.associate { it.substringBefore("=").trim() to it.substringAfter("=").trim() }
    } else {
        emptyMap()
    }
}
if (releaseKeys["storeFile"] != null) {
    android {
        signingConfigs {
            create("release") {
                storeFile = file(releaseKeys.getValue("storeFile"))
                storePassword = releaseKeys["storePassword"]
                keyAlias = releaseKeys["keyAlias"]
                keyPassword = releaseKeys["keyPassword"]
            }
        }
        buildTypes {
            getByName("release") {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}
KTS
fi

# Remove the sample test flutter create may add; this repo has its own tests.
rm -f test/widget_test.dart  # this app tests in app_flow_test.dart

echo "Platform folders are ready. Next: flutter pub get && flutter run"
