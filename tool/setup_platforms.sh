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

# Health Connect's library (androidx.health.connect:connect-client) needs
# Android 8.0 (API 26) or newer; local_auth alone needed 24.
sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(26, flutter.minSdkVersion)/' "$GRADLE_KTS"

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

# Sign in with Google (Credential Manager) and Drive's app folder (GoogleAuth.kt).
if ! grep -q 'identity.googleid' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

dependencies {
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    implementation("com.google.android.gms:play-services-auth:21.2.0")
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-messaging")
}
KTS
fi

# Reading a paper's printed date from its photo, on the phone (TextReader.kt;
# the model comes from Play Services).
if ! grep -q 'mlkit-text-recognition' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

dependencies {
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.0")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}
KTS
fi

# ফ্যামিলি › লোকেশন: the phone answers "এখন কোথায়?" by itself (LocationShare.kt).
if ! grep -q 'play-services-location' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

dependencies {
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
KTS
fi

# স্বাস্থ্য › Health Connect, read only (HealthConnect.kt). 1.1.0 is the
# stable release (8 Oct 2025); it needs compileSdk 36 and AGP 8.9.1+, which
# this Flutter's template already has.
if ! grep -q 'connect-client' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

dependencies {
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
KTS
fi

# Firebase (push): its settings for this app's package, from google-services.json.
python3 tool/firebase_values.py tool/google-services.json "com.iamsaifsaiful.digital_brain$([ "${MY_ASSISTANT_PREVIEW:-}" = 1 ] && echo .preview)" android/app/src/main/res/values/firebase.xml

# The app's name on the phone, and the Play Store preview: MY_ASSISTANT_PREVIEW=1
# makes a separate app (".preview") that installs beside the real one, empty,
# as a new Play Store user would get it.
if ! grep -q 'MY_ASSISTANT_PREVIEW' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

android {
    defaultConfig {
        val preview = System.getenv("MY_ASSISTANT_PREVIEW") == "1"
        manifestPlaceholders["appLabel"] = if (preview) "My Assistant Play প্রিভিউ" else "My Assistant"
        if (preview) applicationIdSuffix = ".preview"
    }
}
KTS
fi

# Premium in the Play app: Google Play subscriptions (PlayBilling.kt; checked
# by our server, play.php).
if ! grep -q 'billingclient' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

dependencies {
    implementation("com.android.billingclient:billing:7.1.1")
    // WorkManager (AdMob brings it): started by MainActivity, not at app start.
    implementation("androidx.work:work-runtime:2.10.0")
}
KTS
fi

# AdMob's app ID for the manifest (the free Play app's ads): the real one from
# the Play build's ADMOB_APP_ID, Google's own test ID otherwise.
if ! grep -q 'admobAppId' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

android {
    defaultConfig {
        manifestPlaceholders["admobAppId"] = System.getenv("ADMOB_APP_ID")?.takeIf { it.matches(Regex("ca-app-pub-[0-9]{10,20}~[0-9]{6,12}")) }
            ?: "ca-app-pub-3940256099942544~3347511713"
    }
}
KTS
fi

# Our own shrinker rules (android/app/proguard-rules.pro): keep what is
# opened by reflection, like WorkManager's Room database (owner, 29 Oct).
if ! grep -q 'proguard-rules.pro' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

android {
    buildTypes {
        getByName("release") {
            proguardFiles("proguard-rules.pro")
        }
    }
}
KTS
fi

# Remove the sample test flutter create may add; this repo has its own tests.
rm -f test/widget_test.dart

echo "Platform folders are ready. Next: flutter pub get && flutter run"
