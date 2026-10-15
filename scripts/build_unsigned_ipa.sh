#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf build output
mkdir -p output

PROJECT="AcousticIntensityScanner.xcodeproj"
TARGET="AcousticIntensityScanner"

set +e
xcodebuild \
  -project "$PROJECT" \
  -target "$TARGET" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build | tee "$ROOT/output/xcodebuild.log"
STATUS=${PIPESTATUS[0]}
set -e
if [ "$STATUS" -ne 0 ]; then
  echo "xcodebuild failed with status $STATUS"
  exit "$STATUS"
fi

APP_PATH=$(find "$ROOT/build/DerivedData/Build/Products/Release-iphoneos" -maxdepth 2 -name '*.app' -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "No .app bundle found after build"
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
