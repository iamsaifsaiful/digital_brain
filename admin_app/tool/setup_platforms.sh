#!/usr/bin/env bash
# Creates the rest of admin_app/android with `flutter create` (it never
# overwrites the files kept in the repo: manifest, MainActivity, PushService,
# styles, the notification icon), then adds what they need.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org com.iamsaifsaiful --project-name my_assistant_admin .
rm -f test/widget_test.dart

GRADLE_KTS="android/app/build.gradle.kts"
sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(24, flutter.minSdkVersion)/' "$GRADLE_KTS"

if ! grep -q 'firebase-messaging' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-messaging")
}
KTS
fi

# Firebase settings for this package (push off when google-services.json is missing).
python3 ../tool/firebase_values.py ../tool/google-services.json com.iamsaifsaiful.my_assistant_admin android/app/src/main/res/values/firebase.xml
echo "Admin app platform folders are ready."
