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
Gatekeeper assessment, and only then replaces the release ZIP in `dist`.

For an already-built app bundle, append `--no-build`.

The process intentionally fails closed: missing credentials, signing failures,
notarization rejection, staple failures, or Gatekeeper rejection prevent a
release ZIP from being published.
