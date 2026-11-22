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
build_number=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
mkdir -p build/packages
work="$PWD/build/installer"
rm -rf "$work"
mkdir -p "$work/payload/Applications"
if [[ "$mode" == --local ]]; then
  codesign --force --sign - "$app"
  package="$PWD/build/packages/Horologium-$version-build$build_number-local.pkg"
else
  codesign --force --options runtime --timestamp --sign "$APPLICATION_IDENTITY" "$app"
  codesign --verify --deep --strict --verbose=2 "$app"
  package="$PWD/build/packages/Horologium-$version-build$build_number.pkg"
fi
# Disable relocation so an existing development build cannot redirect installation.
ditto "$app" "$work/payload/Applications/Horologium.app"
python3 scripts/prepare-installer.py prepare
xcrun swift scripts/installer-artwork.swift Horologium/Resources/Logo.png "$work/Resources/Logo.png"
pkgbuild --root "$work/payload" --component-plist "$work/components.plist" \
  --install-location / --identifier app.ardens.horologium --version "$version" \
  "$work/Horologium-component.pkg"
productbuild --synthesize --product "$work/requirements.plist" \
  --package "$work/Horologium-component.pkg" "$work/Distribution.xml"
python3 scripts/prepare-installer.py distribution
productbuild_command=(productbuild)
if [[ "$mode" == --release ]]; then
  productbuild_command+=(--sign "$INSTALLER_IDENTITY")
fi
"${productbuild_command[@]}" --distribution "$work/Distribution.xml" --resources "$work/Resources" \
  --package-path "$work" --version "$version" "$package"
if [[ "$mode" == --release ]]; then
  xcrun notarytool submit "$package" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$package"
  xcrun stapler validate "$package"
  pkgutil --check-signature "$package"
  spctl --assess --type install --verbose=2 "$package"
  echo "Signed, notarized package: $package"
else
  echo "Local package (not Developer ID signed or notarized): $package"
fi
