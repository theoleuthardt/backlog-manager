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
| Windows, free | SignPath Foundation | free for open-source projects | **Chosen** (see below). Needs an OSI-approved licence and a public repository; this repository has no licence yet |
| Linux | GPG-signed checksums next to the artifacts | free | Protects the download, not the install; AppImage, DEB and RPM have no equivalent of Gatekeeper |

## Proposal

Nothing is bought or enabled by this change; the decision is the owner's.

1. Windows: SignPath Foundation, built into the workflow and switched on by the steps below. Until it is approved the installers stay unsigned; users can follow the instructions above.
2. Before a wider release: the macOS Developer ID is the one with a clear return (the warning cannot be bypassed in one click on recent macOS versions); the Windows warning can be lived with or covered by Azure Trusted Signing.
3. Linux gets `SHA256SUMS` signed with a GPG key once there are enough users to care; until then the release page's checksums are not provided.

## Windows: SignPath Foundation (built in, switched on by variables)

The release workflow signs the Windows installer through [SignPath Foundation](https://signpath.org/), which signs open-source projects for free with its own certificate (the publisher shown to users is "SignPath Foundation"). The workflow steps exist and are skipped until the repository variable `SIGNPATH_ORGANIZATION_ID` and the secret `SIGNPATH_API_TOKEN` are set, so forks and local builds keep producing unsigned installers.

What the owner has to do (nothing here can be done from the repository):

1. **Add an OSI-approved licence.** SignPath only signs projects under an open-source licence without commercial dual licensing and without proprietary code. This repository has no `LICENSE` yet; choosing one (MIT, Apache-2.0, GPL-3.0, ...) is the owner's decision and also decides what others may do with the code.
2. **Have a released, downloadable build.** The project must already be released in the form that is signed and documented on a download page; the GitHub Releases page counts. Publish one release with the Flutter workflow first (it may be unsigned).
3. **Apply** at <https://signpath.org/apply> with the repository URL. The foundation reviews the project and answers by mail; this takes some days.
4. **After approval, set up SignPath** (web interface of SignPath):
   - Create a project with the slug `backlog-manager` (product name `Backlog Manager`).
   - Add the predefined **GitHub.com trusted build system** to the organisation and link it to the project.
   - Create the artifact configuration with the slug `windows-installer` from [`.signpath/windows-installer.xml`](../.signpath/windows-installer.xml) (paste the XML).
   - Create a signing policy with the slug `release-signing` using the Foundation's certificate, with manual approval of every request (the Foundation requires it).
   - Create a CI user with the submitter role and an API token for it.
   - Install the **SignPath GitHub App** on the repository.
5. **Set the repository settings** (GitHub > Settings > Secrets and variables > Actions): variable `SIGNPATH_ORGANIZATION_ID`, secret `SIGNPATH_API_TOKEN`. The slugs above are the defaults; the variables `SIGNPATH_PROJECT_SLUG`, `SIGNPATH_SIGNING_POLICY_SLUG` and `SIGNPATH_ARTIFACT_CONFIGURATION_SLUG` override them.
6. **Run the release workflow.** The Windows job uploads the installer, submits it to SignPath and waits; approve the request in SignPath (mail or web interface) and the job continues with the signed installer.

Hosting: nothing needs to be hosted besides the policy below. SignPath requires the code signing policy on the project's home page and on the download pages; the README and every release (`.github/release-install-notes.md`) link to this section. Using the GitHub repository as the home page is fine.

## Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/). This applies from the first release the foundation signed; before that, and for builds outside the release workflow, the installers are unsigned.

- **Scope:** only the Windows installer of Backlog Manager, built from this repository by the `Release Flutter App` workflow on GitHub-hosted runners. Nothing else is signed with the certificate.
- **Roles:** Authors, reviewers and approvers are the maintainers of this repository: [theoleuthardt](https://github.com/theoleuthardt). Every signing request is approved by hand.
- **Privacy policy:** Backlog Manager talks only to the server whose address the user entered at sign-in (the backlog data, which that server's operator controls) and, with the update check, to the GitHub API to ask for the latest release. It sends no telemetry and transfers no other information to networked systems unless the user asks for it.

## What else signing changes in the release workflow

When Apple certificates exist, the steps below would be added behind a job-level environment variable that is set from the secret (`env: SIGNING_CERT: ${{ secrets.SIGNING_CERT }}`) and tested as `if: env.SIGNING_CERT != ''`, because a secret cannot be used in an `if` directly; they are not written yet because they cannot be tested without the certificates.

- **macOS:** import the Developer ID certificate into a temporary keychain, build with `codesign` (hardened runtime, `--options runtime`), `xcrun notarytool submit --wait`, `xcrun stapler staple` the app before the DMG is created.
- **Linux:** `gpg --detach-sign` over the checksum file.

## Interaction with in-place updates (#279)

- Sparkle (macOS) and WinSparkle verify an EdDSA/DSA signature of the update payload that is independent of OS code signing, so unsigned apps can be updated; the payload signing key is separate from any certificate.
- An unsigned macOS app that replaces itself is not quarantined again, because the files are written by the app, not downloaded by a browser; the first install is the only Gatekeeper prompt.
- Notarization matters only for the first install and for macOS refusing unsigned code in strict environments; Windows SmartScreen weighs the reputation of the publisher and of the individual file, so an unsigned update or a changed identity can bring the warning back.
- If the app is ever signed, the update payloads of that release must be signed with the same identity, otherwise macOS may refuse to swap the bundle.
