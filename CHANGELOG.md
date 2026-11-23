# Changelog

## 1.0.10 — Build 11

- Click the Time Travel heading to cycle through a small easter egg; closing the dropdown restores the normal heading.

## 1.0.9 — Build 10

- Branded the native installer with the app logo, a clean title, an app introduction, and getting-started instructions.
- Added explicit Apple silicon/macOS requirements and fixed installation to Applications, preventing relocation to development builds.

## 1.0.8 — Build 9

- Added JSON import/export in General settings, including ordered locations, emoji, custom labels, and all portable app preferences.
- Added a versioned transfer format, import review, validation before replacement, and a local pre-import recovery copy.
- Kept Start at login local to each Mac and recorded future settings-portability requirements in AGENTS.md.

## 1.0.7 — Build 8

- Added System/Custom accent color selection in General settings, using the native macOS color picker.
- Applied the accent to the dropdown, settings controls, calendar highlights, and native settings tabs.
- Preserved custom colors when returning to System, and kept selected calendar dates legible with light colors.

## 1.0.6 — Build 7

- Replaced the main anchored popover with a rounded, arrowless native panel below the menu bar item.
- Preserved click-outside, Escape, focus-loss, and status-item dismissal, with screen-aware placement and dynamic resizing.

## 1.0.5 — Build 6

- Added Calendar icon only at the top of Menu Bar settings, showing 🗓️ and clearing/disabling text options.
- Turning icon-only mode off restores the default date/time options without changing clock format or other preferences.

## 1.0.4 — Build 5

- Added a Command-drag rearrangement tip beneath the macOS Clock Settings link.

## 1.0.3 — Build 4

- Removed the Menu Bar formatting group's heading.
- Added a link below the format toggles to the native macOS clock settings.

## 1.0.2 — Build 3

- Stabilized settings tabs with fixed, equal native segment widths.
- Removed Ardens from About and removed the Menu Bar preview section.
- Removed excess space below short clock lists and tightened the dropdown's bottom padding.
- Added a little spacing between the calendar header and weekday grid.

## 1.0.1 — Build 2

- Simplified the location editor and emoji picker by removing helper text and the emoji count footer.
- Matched Layout's “Drag to reorder” treatment to Locations and made settings panel backgrounds consistent.
- Added About with the app artwork, runtime version/build, GeoNames attribution, and GitHub link.
- Centralized versioning in Version.json, added a version-bump script, and included version/build in installer filenames.

## 1.0 — Build 1

- Initial native macOS menu bar calendar, offline city search, world clocks, and time travel.
- Added native emoji and custom location labels, appearance settings, menu bar display options, and section reordering.
