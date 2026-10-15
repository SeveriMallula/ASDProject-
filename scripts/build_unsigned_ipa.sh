#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf build output
mkdir -p build output

PROJECT="AcousticIntensityScanner.xcodeproj"
TARGET="AcousticIntensityScanner"

set +e
xcodebuild \
  -project "$PROJECT" \
  -target "$TARGET" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  SYMROOT="$ROOT/build" \
  build | tee "$ROOT/output/xcodebuild.log"
STATUS=${PIPESTATUS[0]}
set -e
if [ "$STATUS" -ne 0 ]; then
  echo "xcodebuild failed with status $STATUS"
  exit "$STATUS"
fi

APP_PATH=$(find "$ROOT/build" -type d -name 'AcousticIntensityScanner.app' | head -1)
if [ -z "$APP_PATH" ]; then
  echo "No .app bundle found after build"
  find "$ROOT/build" -maxdepth 4 -type d -print || true
  exit 1
fi

mkdir -p "$ROOT/output/Payload"
cp -R "$APP_PATH" "$ROOT/output/Payload/AcousticIntensityScanner.app"
(
  cd "$ROOT/output"
  /usr/bin/zip -qry AcousticIntensityScanner.ipa Payload
)
rm -rf "$ROOT/output/Payload"

/usr/bin/file "$ROOT/output/AcousticIntensityScanner.ipa"
/usr/bin/du -h "$ROOT/output/AcousticIntensityScanner.ipa"
echo "Created: $ROOT/output/AcousticIntensityScanner.ipa"
