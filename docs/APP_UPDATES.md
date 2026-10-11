# In-place updates of the Flutter app

The Flutter client updates itself in place (issue #279): it finds a newer
release, downloads the installer for the running install, checks size, hash and
signature, and restarts into it. Everything that is not installed in a way that
can replace itself stays notify-only: the app tells the user about the release
and opens its page.

## What happens

1. **Feed.** `GithubReleaseSource` (`lib/data/release_source.dart`) lists the
   newest releases and reads the `app-update.json` of the first one that has it.
   Flutter releases are pre-releases until the cutover, so the list is read and
   not `releases/latest`; a release without that asset is skipped, and without
   any manifest the answer is the latest stable release (notify-only).
2. **Payload.** The manifest has one payload per `{os}-{arch}-{format}` key:
   `linux-x64-appimage`, `macos-universal-dmg`, `windows-x64-exe`. An install
   looks up its own key (`UpdateInstaller.payloadKey`), so a DEB or RPM install
   (no key) is never offered a payload it cannot apply.
3. **Download** into a folder on the disk of the app (`.blm-update-<version>`).
   A failed download removes the part and keeps the installed version.
4. **Verification** (`UpdateVerifier`): the size and the SHA-256 are the ones of
   the manifest, and the Ed25519 signature of
   `blm-update-v1:<version>:<key>:<sha256>` is good under the public key built
   into the app. The message names the version and the platform, so a signature
   is good for one file only (no swapping a signed Linux file in for Windows, no
   replaying an older release). A file that fails is deleted and reported.
5. **Install** on "Restart to Update":

   | Platform | How |
   |---|---|
   | Linux AppImage | the new file is made executable, moved over the running AppImage (`$APPIMAGE`) and started; the old process keeps its open inode and exits |
   | macOS | a detached shell script waits for the app to exit, mounts the disk image, copies the app over the bundle with `ditto` and opens it; the file is not quarantined because the app downloaded it itself |
   | Windows | a detached `cmd` runs a small batch file next to the download: it waits a moment, runs the Inno Setup installer silently over the install, starts the app and deletes itself |

   An install in a folder the user cannot write to has no payload key and stays
   notify-only. A failure while applying removes the download and leaves the
   running version in place.

## Keys

The payloads are signed with an Ed25519 key pair that only the project has.

- **Create it once:** `node scripts/app-update-keygen.mjs` prints a private and
  a public line.
- **Private key:** store the private line as the repository secret
  `APP_UPDATE_PRIVATE_KEY` (Settings > Secrets and variables > Actions) and
  nowhere else, not in the repository and not in a chat. The release workflow
  signs with it (`scripts/app-update-manifest.mjs`).
- **Public key:** paste the public line into
  `app/lib/data/update_public_key.dart` (`updatePublicKeyBase64`) and ship an
  app version with it. While the constant is empty the app never installs a
  payload.
- **Without the secret** the release workflow writes no `app-update.json` and
  the release is notify-only.
- **Losing the private key** means installed apps can no longer verify new
  releases signed with a new key: they keep working but cannot update in place
  and every user has to install the next version by hand once (it carries the
  new public key). Keep a copy of the private key in a password manager.
  **A leaked private key** means anyone can sign an update: create a new pair,
  replace the secret, ship an app with the new public key by hand and treat the
  old key as void.

## Checks

- `task release:test` covers the manifest and the signatures
  (`scripts/app-update-manifest.test.mjs`).
- `task app:test` covers the manifest parser, the verifier (a changed file, a
  wrong key, another version or platform are refused), the installers' plans and
  the controller (download, refuse, restart, failure keeps the version).
- What only a real machine shows: the macOS and Windows installers and the
  restart. Test them with a pre-release of a version above the installed one
  (`release-app.yml` with `publish` and `prerelease` on).
