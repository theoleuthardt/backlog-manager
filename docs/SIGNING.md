# Code signing and notarization

The desktop builds are **not signed** (neither the Tauri client nor the Flutter client). This page records what users see, the options with their costs, and what signing would change in the release workflow. Issue #280.

## What users see today

| Platform | First start | How to open it |
| --- | --- | --- |
| macOS | "Backlog Manager can't be opened because Apple cannot check it for malicious software" (Gatekeeper) | Right click the app > Open > Open. On macOS 15 and later: try to open it once, then System Settings > Privacy & Security > "Open Anyway". Or remove the quarantine flag: `xattr -dr com.apple.quarantine /Applications/backlog_manager.app` |
| Windows | "Windows protected your PC" (SmartScreen) | More info > Run anyway |
| Linux | Nothing | AppImages need `chmod +x`; DEB and RPM install like any package |

The installers of a release carry these instructions in the release notes (`.github/release-install-notes.md`) and the README links here.

## Options and costs

Prices are what the vendors list at the time of writing; check them before buying.

| Goal | Option | Cost | Notes |
| --- | --- | --- | --- |
| macOS without warnings | Apple Developer ID certificate + notarization | Apple Developer Program, about 99 USD per year | The only way; needs the Hardened Runtime, which Flutter supports with the entitlements already in `macos/Runner/Release.entitlements` (network client, sandbox) |
| Windows without SmartScreen warnings | OV or EV code signing certificate from a certificate authority | OV roughly 100-400 USD per year, EV more; neither avoids the SmartScreen prompt from the first day, because SmartScreen also weighs the reputation of the publisher and of the file, which builds up with downloads | A certificate on a hardware token or cloud HSM is now required by the CAs, which makes CI signing indirect |
| Windows, cheaper | Azure Trusted Signing (Azure Artifact Signing) | about 10 USD per month | Eligibility depends on country and organisation type, individuals are limited in some regions; verify before relying on it |
| Windows, free | SignPath Foundation | free for open-source projects | Needs an OSI-approved licence and a public repository; this repository has no licence yet |
| Linux | GPG-signed checksums next to the artifacts | free | Protects the download, not the install; AppImage, DEB and RPM have no equivalent of Gatekeeper |

## Proposal

Nothing is bought or enabled by this change; the decision is the owner's.

1. Keep unsigned builds for the beta (#286). The project has a handful of users, who can follow the instructions above.
2. Before a wider release: the macOS Developer ID is the one with a clear return (the warning cannot be bypassed in one click on recent macOS versions); the Windows warning can be lived with or covered by Azure Trusted Signing.
3. Linux gets `SHA256SUMS` signed with a GPG key once there are enough users to care; until then the release page's checksums are not provided.

## What signing changes in the release workflow

`release-app.yml` builds unsigned artifacts when no certificate secrets exist (forks, local builds). When certificates exist, the steps below would be added behind a job-level environment variable that is set from the secret (`env: SIGNING_CERT: ${{ secrets.SIGNING_CERT }}`) and tested as `if: env.SIGNING_CERT != ''`, because a secret cannot be used in an `if` directly; they are not written yet because they cannot be tested without the certificates.

- **macOS:** import the Developer ID certificate into a temporary keychain, build with `codesign` (hardened runtime, `--options runtime`), `xcrun notarytool submit --wait`, `xcrun stapler staple` the app before the DMG is created.
- **Windows:** sign the app executable and the installer with `signtool` (or the Trusted Signing action) before and after Inno Setup.
- **Linux:** `gpg --detach-sign` over the checksum file.

## Interaction with in-place updates (#279)

- Sparkle (macOS) and WinSparkle verify an EdDSA/DSA signature of the update payload that is independent of OS code signing, so unsigned apps can be updated; the payload signing key is separate from any certificate.
- An unsigned macOS app that replaces itself is not quarantined again, because the files are written by the app, not downloaded by a browser; the first install is the only Gatekeeper prompt.
- Notarization matters only for the first install and for macOS refusing unsigned code in strict environments; Windows SmartScreen weighs the reputation of the publisher and of the individual file, so an unsigned update or a changed identity can bring the warning back.
- If the app is ever signed, the update payloads of that release must be signed with the same identity, otherwise macOS may refuse to swap the bundle.
