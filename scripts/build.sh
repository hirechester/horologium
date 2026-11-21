#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project Horologium.xcodeproj -scheme Horologium \
  -configuration Debug -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- build
printf '\nBuilt: %s/build/DerivedData/Build/Products/Debug/Horologium.app\n' "$PWD"
