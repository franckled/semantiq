#!/usr/bin/env bash
# Génère les dossiers natifs android/ et ios/ s'ils n'existent pas encore,
# puis applique l'identité et les exigences de l'application :
#   - nom affiché et identifiant ;
#   - iOS 15.6 minimum (Whisper sur l'appareil) ;
#   - Android 7.0 (API 24) minimum et accès internet (API, modèles).
# Idempotent : sans effet si tout est déjà en place.
set -euo pipefail

APP_ID="fr.semantiq.app"
APP_NAME="SemantiQ"
IOS_MIN="15.6"

cd "$(dirname "$0")/.."

if [[ ! -d android || ! -d ios ]]; then
  flutter create --platforms=android,ios --org fr.semantiq \
    --project-name semantiq --no-pub .
  # `flutter create` ajoute un test d'exemple qui ne correspond pas à l'app.
  rm -f test/widget_test.dart
fi

# --- Android -----------------------------------------------------------------
GRADLE=android/app/build.gradle.kts
[[ -f $GRADLE ]] || GRADLE=android/app/build.gradle
sed -i.bak -E "s/applicationId[ =]+\"[^\"]+\"/applicationId = \"$APP_ID\"/" "$GRADLE"
sed -i.bak -E "s/namespace[ =]+\"[^\"]+\"/namespace = \"$APP_ID\"/" "$GRADLE"
sed -i.bak -E "s/minSdk[ =]+flutter\.minSdkVersion/minSdk = 24/; s/minSdkVersion[ =]+flutter\.minSdkVersion/minSdkVersion 24/" "$GRADLE"
# Un seul NDK pour tout le projet : celui exigé par le module Whisper,
# installé par le workflow (évite un second téléchargement de 1 Go).
sed -i.bak -E 's/ndkVersion[ =]+flutter\.ndkVersion/ndkVersion = "29.0.13113456"/' "$GRADLE"
if [[ $GRADLE == *.gradle ]]; then
  # Syntaxe Groovy : pas de signe égal.
  sed -i.bak -E "s/applicationId = \"/applicationId \"/; s/namespace = \"/namespace \"/" "$GRADLE"
fi
rm -f "$GRADLE.bak"

# Le package Kotlin de MainActivity doit suivre le namespace.
MAIN=$(find android/app/src/main -name 'MainActivity.kt' | head -n1)
if [[ -n $MAIN ]]; then
  DEST="android/app/src/main/kotlin/${APP_ID//.//}"
  mkdir -p "$DEST"
  sed -E "s/^package .*/package $APP_ID/" "$MAIN" > "$DEST/MainActivity.kt.tmp"
  [[ "$MAIN" != "$DEST/MainActivity.kt" ]] && rm -f "$MAIN"
  mv "$DEST/MainActivity.kt.tmp" "$DEST/MainActivity.kt"
  find android/app/src/main/kotlin -type d -empty -delete
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak -E "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" "$MANIFEST"
rm -f "$MANIFEST.bak"
python3 - "$MANIFEST" <<'PY'
import re, sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
if 'android.permission.INTERNET' not in s:
    s = re.sub(r'(<manifest[^>]*>)',
               r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>',
               s, count=1)
    open(path, 'w', encoding='utf-8').write(s)
PY

# --- iOS ---------------------------------------------------------------------
PBX=ios/Runner.xcodeproj/project.pbxproj
sed -i.bak -E "s/PRODUCT_BUNDLE_IDENTIFIER = fr\.semantiq\.semantiq;/PRODUCT_BUNDLE_IDENTIFIER = $APP_ID;/; s/PRODUCT_BUNDLE_IDENTIFIER = fr\.semantiq\.semantiq\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = $APP_ID.RunnerTests;/" "$PBX"
sed -i.bak -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = $IOS_MIN;/" "$PBX"
rm -f "$PBX.bak"

# Podfile : Flutter ne le crée qu'au premier build ; on part de son modèle
# pour y fixer la version minimale d'iOS.
if [[ ! -f ios/Podfile ]]; then
  FLUTTER_ROOT="$(cd "$(dirname "$(command -v flutter)")/.." && pwd)"
  TPL="$FLUTTER_ROOT/packages/flutter_tools/templates/cocoapods"
  for f in Podfile-ios Podfile-ios-swift Podfile-ios-objc; do
    if [[ -f "$TPL/$f" ]]; then cp "$TPL/$f" ios/Podfile; break; fi
  done
fi
if [[ -f ios/Podfile ]]; then
  sed -i.bak -E "s/^#? *platform :ios, '[0-9.]+'/platform :ios, '$IOS_MIN'/" ios/Podfile
  rm -f ios/Podfile.bak
fi

PLIST=ios/Runner/Info.plist
python3 - "$PLIST" "$APP_NAME" <<'PY'
import plistlib, sys
path, name = sys.argv[1], sys.argv[2]
with open(path, 'rb') as f:
    data = plistlib.load(f)
data['CFBundleDisplayName'] = name
data['CFBundleName'] = name
# Pas de chiffrement propriétaire : évite la question export à chaque envoi.
data['ITSAppUsesNonExemptEncryption'] = False
with open(path, 'wb') as f:
    plistlib.dump(data, f)
PY

echo "Plateformes prêtes : $APP_NAME ($APP_ID), iOS $IOS_MIN+, Android API 24+"
