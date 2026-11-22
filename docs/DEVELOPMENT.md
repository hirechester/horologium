# Developing Horologium

Build, test, package, and maintain Horologium. Run the commands below from the repository root. For an overview of the app, see the [README](../README.md).

## Build and run

Open `Horologium.xcodeproj` in Xcode 26 or later, choose the **Horologium** scheme and **My Mac**, then Run. Development does not require a paid Developer Program membership. Use **Sign to Run Locally** if Xcode requests signing configuration.

Or use the bundled scripts (Xcode is selected per command without changing the system developer directory):

```sh
./scripts/build.sh
open build/DerivedData/Build/Products/Debug/Horologium.app
./scripts/test.sh
```

The app lives in the menu bar and does not display a Dock icon. Right-click (or Control-click) the menu bar item for Settings and Quit. The dropdown has no app header or settings footer. If all menu bar text is disabled, a small clock icon keeps the app accessible. Arrow keys move the calendar selection by a day or week; Space returns to now. Command-comma opens Settings. The plus button opens the Locations settings. Clock format and week start follow the Mac’s system preferences by default; both can be overridden independently.

For start at login, install the app at a stable location such as `/Applications` before enabling it. macOS may require approval under System Settings → General → Login Items.

## Installer packages

Create a local installer for development:

```sh
./scripts/package.sh --local
```

Output: `build/packages/Horologium-<version>-build<build>-local.pkg`. This contains an ad hoc signed app; the package is **not Developer ID signed or notarized** and is for local development.

Both package modes use a native product installer with a branded welcome page and completion instructions. `scripts/prepare-installer.py` generates the resources and customizes the synthesized distribution. Installation requires Apple silicon and macOS 26 or later, and always targets `/Applications/Horologium.app`. The release workflow signs the final product archive.

Once Ardens' Apple Developer Program membership is active:

1. Create **Developer ID Application** and **Developer ID Installer** certificates in the account and import them into Keychain.
2. Store notarization credentials using `xcrun notarytool store-credentials Ardens-notary` and follow its interactive prompts. Do not commit credentials.
3. Run the release workflow with your actual certificate names:

```sh
export APPLICATION_IDENTITY='Developer ID Application: YOUR LEGAL NAME (TEAMID)'
export INSTALLER_IDENTITY='Developer ID Installer: YOUR LEGAL NAME (TEAMID)'
export NOTARY_PROFILE='Ardens-notary'
./scripts/package.sh --release
```

The script builds an arm64 release app, signs it with hardened runtime and a secure timestamp, signs the installer, submits it for notarization, staples the ticket, and verifies the result. The installer places the app in `/Applications`. The bundle and package identifier is **`app.ardens.horologium`**. The test bundle is `app.ardens.horologium.tests`.

Quit an existing Horologium process before installing an updated build, then reopen the app. Automatic updates and App Store distribution are outside this version.

## Move settings between Macs

In **Settings → General**, choose **Export Settings…** to save a readable JSON file. Transfer that file to another Mac, choose **Import Settings…**, review the location count, and confirm **Replace Settings**.

The file includes saved locations in order (including labels and emoji), menu bar options, calendar preferences, section order, appearance, and custom accent colors. System-following options use the destination Mac's system settings. Start at login is an OS registration and stays unchanged on each Mac.

Import replaces the current portable configuration; it does not merge locations. Invalid or unsupported files leave current settings untouched. A copy of the previous local state is retained under the `horologium.beforeImport` UserDefaults key. Temporary calendar/time-travel state is not exported.

The JSON format has an app identifier and format version, plus optional export/app-version metadata. New portable fields must be included and older files kept compatible; the project requirement is recorded in [AGENTS.md](../AGENTS.md). Files are limited to 2 MB.

## Versioning

`Version.json` is the source of truth for the app version and build number; the Xcode project generator reads it, About reads the built app metadata, and installer filenames include both version and build.

Bump the patch version and build once per delivered app update. Documentation-only changes do not require a new app build:

```sh
python3 scripts/bump-version.py
```

Use `minor` or `major` for larger releases. The script increments the build number and regenerates Xcode settings. Routine rebuilds and test runs keep the current pair. See [CHANGELOG.md](../CHANGELOG.md) for delivered changes.

## Project structure and tests

SwiftUI views are hosted by an AppKit status item and rounded, arrowless floating panel. `TimeEngine` owns calendar and time-zone calculations; `CityCatalog` handles offline search; `AppStore` persists locations and preferences in UserDefaults. Preview time is temporary. Malformed settings are preserved under a recovery key before fresh defaults are used.

The shared Xcode scheme runs unit tests for DST gaps/overlaps, date boundaries, leap days, fractional offsets, search, persistence, and an injectable clock. Visual tests render the actual SwiftUI views with sample locations into XCTest attachments and `/tmp/horologium-previews`. These previews are not desktop interaction tests. Live panel placement, full-screen Spaces, login-item approval, and signed installation should also be checked on a Mac before public distribution.

The Xcode project has no external package dependencies. After adding source/resource files, regenerate its file list:

```sh
python3 scripts/generate-project.py
```

## Artwork and city data

The supplied Horologium logo is in `Artwork/`; the supplied IconKitchen macOS icon is bundled as `AppIcon.icns`.

City data is derived from [GeoNames](https://www.geonames.org/) under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), with attribution bundled in the app. The catalog covers cities in GeoNames' `cities15000` extract, not every settlement; use the manual time-zone picker for other locations. It includes a pinned dataset snapshot, so the app needs no download at launch. Time-zone rules come from macOS.

To update the bundled catalog, download `cities15000.zip` and `admin1CodesASCII.txt` from [GeoNames' dump directory](https://download.geonames.org/export/dump/), then run:

```sh
python3 scripts/import-cities.py /path/to/cities15000.zip /path/to/admin1CodesASCII.txt
```

Update the snapshot date in `Horologium/Resources/GeoNames-attribution.txt` when refreshing the data.


Emoji glyphs are rendered by macOS using its native emoji font; no third-party emoji artwork is bundled. Search uses Unicode 16 emoji names and CLDR 46 English keywords, with the Unicode license included in the app. This pinned set supports the minimum macOS version. To refresh the search index:

```sh
# Download emoji-test.txt from https://unicode.org/Public/emoji/16.0/emoji-test.txt
# Download en.xml from https://raw.githubusercontent.com/unicode-org/cldr/release-46/common/annotations/en.xml
python3 scripts/import-emoji.py /path/to/emoji-test.txt /path/to/en.xml
```
