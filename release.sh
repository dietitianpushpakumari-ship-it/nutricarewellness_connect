#!/bin/bash

# ==========================================
# 1. APP IDENTITY (Specific to Client App)
# ==========================================
APP_NAME="Pure Shift"
APP_TYPE="Client Portal"
DESCRIPTION="The ultimate health command center. Features real-time meal & activity logging, proprietary Health Scoring, transformation mapping, and a secure clinical chat engine."

# ==========================================
# 2. SETUP VARIABLES
# ==========================================
DATE=$(date +%Y-%m-%d)
VERSION=$(grep 'version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
TAG="v$VERSION"

# Paths
ORIGINAL_APK="build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
RENAMED_APK="build/app/outputs/flutter-apk/Nutricare_client.apk"

echo "🚀 Starting Local Build for $APP_NAME ($TAG)..."

# ==========================================
# 3. CLEAN AND BUILD
# ==========================================
flutter clean
flutter pub get
flutter build apk --release --split-per-abi

if [ ! -f "$ORIGINAL_APK" ]; then
  echo "❌ Build Failed! APK not found at $ORIGINAL_APK"
  exit 1
fi

# Rename the APK
cp "$ORIGINAL_APK" "$RENAMED_APK"
echo "✅ Build Successful. Renamed to Nutricare_client.apk"

# ==========================================
# 🔍 NEW: SIGNATURE VERIFICATION
# ==========================================
echo "🛡️ Verifying APK signature..."

# Locate apksigner (Standard Mac Android SDK path)
# We use 'ls' to find the latest version in the build-tools folder
APKSIGNER_PATH=$(ls -d ~/Library/Android/sdk/build-tools/*/apksigner | tail -1)

if [ -z "$APKSIGNER_PATH" ]; then
    echo "⚠️ apksigner not found in standard path. Skipping deep verification..."
else
    $APKSIGNER_PATH verify "$RENAMED_APK"
    if [ $? -eq 0 ]; then
        echo "✅ Signature Verified: This is a valid production-ready APK."
    else
        echo "❌ ERROR: APK is NOT SIGNED! Upload aborted."
        echo "Please check your android/key.properties and keystore file."
        exit 1
    fi
fi

# ==========================================
# 4. TRIGGER FIREBASE UPLOAD
# ==========================================
echo "🔥 Sending to Firebase Storage and updating Firestore..."

# Trigger the Node script passing the Client App details
node upload_release.js "$VERSION" "$DATE" "$RENAMED_APK" "$APP_NAME" "$APP_TYPE" "$DESCRIPTION"

if [ $? -eq 0 ]; then
  echo "🎉 Deployment complete! $APP_NAME is live under the '$APP_TYPE' tab."
else
  echo "❌ Deployment failed."
  exit 1
fi