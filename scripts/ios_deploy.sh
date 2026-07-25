#!/bin/bash
set -e

DEVICE_ID="${1:-00008140-00020CEC3C8A801C}"
BUNDLE_ID="com.mk.naamJap.app"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Building iOS release..."
cd "$PROJECT_DIR"
flutter build ios --release --no-codesign \
  --obfuscate --split-debug-info="$PROJECT_DIR/build/debug-info" \
  2>/dev/null || true
flutter build ios --release \
  --obfuscate --split-debug-info="$PROJECT_DIR/build/debug-info" \
  2>/dev/null || true

APP_PATH=""
for dir in "build/ios/iphoneos" "build/ios/Release-iphoneos"; do
  if [ -d "$PROJECT_DIR/$dir/Runner.app" ]; then
    APP_PATH="$PROJECT_DIR/$dir/Runner.app"
    break
  fi
done

if [ -z "$APP_PATH" ]; then
  echo "ERROR: Runner.app not found in build output."
  exit 1
fi

echo "==> Found app at: $APP_PATH"
echo "==> Installing on device $DEVICE_ID..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "==> Launching..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "==> Done! App is running on your iPhone."
