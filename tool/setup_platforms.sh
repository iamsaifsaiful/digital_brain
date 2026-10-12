#!/usr/bin/env bash
# Creates the rest of the android/ folder with `flutter create`.
#
# The repo keeps only the Android files this app customises (manifest,
# MainActivity, theme, icon, backup rules). `flutter create` never overwrites
# files that exist, so it only adds the missing ones (Gradle files, launcher
# PNGs for old phones).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org com.iamsaifsaiful --project-name digital_brain .

GRADLE_KTS="android/app/build.gradle.kts"
if [ ! -f "$GRADLE_KTS" ]; then
  echo "Expected $GRADLE_KTS" >&2
  exit 1
fi

# local_auth needs Android 7.0 (API 24) or newer.
sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(24, flutter.minSdkVersion)/' "$GRADLE_KTS"

# Scheduled notifications need core library desugaring; the AppCompat theme
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
KTS
fi

# A permanent release key (from CI secrets, written to android/key.properties)
# so every new APK installs over the old one. Without it the debug key is
# used, which differs from build to build.
if ! grep -q 'myAssistantKeys' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

val myAssistantKeys: Map<String, String> = rootProject.file("key.properties").let { f ->
    if (f.exists()) {
        f.readLines().filter { it.contains("=") }.associate { it.substringBefore("=").trim() to it.substringAfter("=").trim() }
    } else {
        emptyMap()
    }
}
if (myAssistantKeys["storeFile"] != null) {
    android {
        signingConfigs {
            create("release") {
                storeFile = file(myAssistantKeys.getValue("storeFile"))
                storePassword = myAssistantKeys["storePassword"]
                keyAlias = myAssistantKeys["keyAlias"]
                keyPassword = myAssistantKeys["keyPassword"]
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
rm -f test/widget_test.dart

echo "Platform folders are ready. Next: flutter pub get && flutter run"
