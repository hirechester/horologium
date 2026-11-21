#!/bin/bash
# Usage: scripts/package.sh --local OR scripts/package.sh --release
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mode="${1:---local}"
if [[ "$mode" != --local && "$mode" != --release ]]; then
  echo 'Usage: scripts/package.sh --local|--release' >&2; exit 2
fi
if [[ "$mode" == --release ]]; then
  : "${APPLICATION_IDENTITY:?Set APPLICATION_IDENTITY to your Developer ID Application certificate name}"
  : "${INSTALLER_IDENTITY:?Set INSTALLER_IDENTITY to your Developer ID Installer certificate name}"
  : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile name}"
fi
xcodebuild -project Horologium.xcodeproj -scheme Horologium \
  -configuration Release -derivedDataPath build/Release CODE_SIGNING_ALLOWED=NO build
app="$PWD/build/Release/Build/Products/Release/Horologium.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
mkdir -p build/packages
if [[ "$mode" == --local ]]; then
  codesign --force --sign - "$app"
  package="$PWD/build/packages/Horologium-$version-local.pkg"
  pkgbuild --component "$app" --install-location /Applications \
    --identifier app.ardens.horologium --version "$version" "$package"
  echo "Local package (not Developer ID signed or notarized): $package"
else
  codesign --force --options runtime --timestamp --sign "$APPLICATION_IDENTITY" "$app"
  codesign --verify --deep --strict --verbose=2 "$app"
  package="$PWD/build/packages/Horologium-$version.pkg"
  pkgbuild --component "$app" --install-location /Applications \
    --identifier app.ardens.horologium --version "$version" \
    --sign "$INSTALLER_IDENTITY" "$package"
  xcrun notarytool submit "$package" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$package"
  xcrun stapler validate "$package"
  pkgutil --check-signature "$package"
  spctl --assess --type install --verbose=2 "$package"
  echo "Signed, notarized package: $package"
fi
