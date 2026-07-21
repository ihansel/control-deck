# Safe macOS distribution

Local builds are ad-hoc signed so they can run during development on the Mac
that built them. A public download must instead use an Apple **Developer ID
Application** certificate, hardened runtime, Apple notarization and a stapled
ticket. Do not remove quarantine attributes or ask users to bypass Gatekeeper.

## One-time Apple setup

1. Install a Developer ID Application certificate in the login keychain.
2. Store App Store Connect credentials in a notarytool keychain profile:

   ```bash
   xcrun notarytool store-credentials "control-deck-notary"
   ```

## Build and notarize

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Example (TEAMID)"
export NOTARYTOOL_PROFILE="control-deck-notary"
./scripts/package-notarized-release.sh
```

The script signs the bundled Opus framework and ControlDeck with hardened
runtime, submits the archive to Apple, staples and validates the ticket, runs
Gatekeeper assessment, then creates and separately notarizes a signed DMG. Only
after both formats pass validation does it replace `dist/ControlDeck.dmg` and
`dist/ControlDeck.zip`. The DMG contains the app and an Applications shortcut;
the ZIP remains a lightweight fallback. It builds separate arm64 and x86_64
executables and merges them into one universal app, so both downloads support
Apple Silicon and Intel Macs.

For an already-built app bundle, append `--no-build`.

The process intentionally fails closed: missing credentials, signing failures,
notarization rejection, staple failures, invalid DMG contents, or Gatekeeper
rejection prevent either release artifact from being published.
