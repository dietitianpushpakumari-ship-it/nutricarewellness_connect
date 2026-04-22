#!/bin/bash

# ==========================================
# 1. APP IDENTITY (Specific to Client App)
# ==========================================
APP_NAME="Nutricare Client"
APP_TYPE="Patient Portal" # 👈 This creates a new tab for your clients!
DESCRIPTION="Personalized diet tracking, biometric logs, and secure clinical chat."

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