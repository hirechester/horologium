# Horologium project notes

## Settings portability (user requirement)

- Keep JSON import/export working as the app evolves. Every new portable setting or saved-location field must be persisted and included in transfer files.
- Export the shared settings models directly; do not maintain a separate whitelist of preference fields that can omit future additions.
- When adding a field, provide a decoding default or migration so existing local settings and previously exported JSON still import successfully. Update Preferences.CodingKeys and its custom decoder when necessary.
- Keep the transfer format versioned. Make additive changes backward compatible; for breaking changes, bump the format version, provide migrations for older supported exports, and reject unsupported future formats without modifying current settings.
- Extend round-trip tests with non-default values for new settings, and retain legacy-file compatibility tests.
- Keep machine-specific OS registration, such as Start at login, local to each Mac. Do not import that state implicitly.

## Commit identity

- Use GitHub account `hirechester` for both author and committer, with the private email `9629221+hirechester@users.noreply.github.com`.
- Keep this identity explicitly configured in this repository. Never fall back to a local machine username or a personal email address.
