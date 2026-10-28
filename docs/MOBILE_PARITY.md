# Mobile parity checklist

The checklist of the mobile port (epic #289, issue #528): every page and every function of the Flutter client, worked through on the real devices, so the phone and the handhelds lack nothing the desktop has and the desktop is unchanged. [`PARITY.md`](PARITY.md) is the same list for the port from the web client. How the mobile layouts work is in [`FLUTTER.md`](FLUTTER.md) (section "Mobile (Android and iOS)").

## How to check

Install the APK and the IPA of a release (the IPA is unsigned: sign and install it with KravaSigner, see "Install" in [`FLUTTER.md`](FLUTTER.md)) (for a spot check before a release, the `android-apk` and `ios-ipa` artifacts of a pull request's CI run; the debug APK is signed with another key than the releases, so uninstall it before installing a release APK) and sign in against the real backend with a large backlog (about 2000 entries). Each row is checked on every column:

| Column | Device | Input |
| --- | --- | --- |
| **iP** | iPhone 16 Pro, portrait (compact layout) | touch |
| **iL** | iPhone 16 Pro, landscape (medium layout) | touch |
| **RP** | Retroid Pocket 6, landscape (medium layout) | touch |
| **RG** | Retroid Pocket 6 | gamepad only (D-pad, A, B, X, Y, shoulders, Start, Select) |
| **OP** | AYN Odin 3, landscape (medium layout) | touch |
| **OG** | AYN Odin 3 | gamepad only |
| **D** | desktop (macOS, Windows or Linux) | mouse and keyboard, nothing may have changed |

Mark a cell `ok`, `n/a` (with the reason in the notes), or the number of the issue that tracks the gap. A row is done when no cell is empty and no issue in it is open.

What the automated tests already cover (so a failure there is a regression, not a gap): every page without overflow at 402x874, 874x402, 732x412 and 960x540 and goldens of the main pages at those sizes (`test/features/mobile_pages_test.dart`, `test/shell/mobile_shell_test.dart`), 48 dp tap targets (`test/features/touch_test.dart`), the gamepad mapping (`test/shell/gamepad_test.dart`), the long-press menus (`test/features/library/touch_interactions_test.dart`), the biometric lock (`test/auth/`), the update paths (`test/features/updates/`, `test/platform/update_installer_test.dart`), the lighter effects (`test/design/light_effects_test.dart`) and the emulator smoke test (`integration_test/mobile_smoke_test.dart`, Android 14).

## Pages

| Page | iP | iL | RP | RG | OP | OG | D | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sign-in: password, two-factor code, backup code, server address, autofill | | | | | | | | |
| Setup wizard: profile, Steam, API keys, theme | | | | | | | | |
| Home: Up next, short games first, recently completed, stats | | | | | | | | |
| Library: groups, covers and rows, collapsing groups | | | | | | | | |
| Library: search, filters, sort, group by | | | | | | | | |
| Library: selection, bulk status, bulk delete, bulk categories | | | | | | | | |
| Library: long press / context menu, move to status, categories (drag and drop on the desktop) | | | | | | | | |
| Inspector: every tab, autosave, status, categories, rating, review, playtime, mods, platforms | | | | | | | | |
| Inspector: trailer, Keyforsteam prices, update image, wrong game | | | | | | | | |
| Add game sheet: search, deep search, cover picker, duplicate check | | | | | | | | |
| Creation tool: every field, "Add to" personal or space | | | | | | | | |
| Import CSV: file picker, mapping, preview, skipped rows, import | | | | | | | | |
| Export: CSV and JSON to the share sheet (desktop: save dialog) | | | | | | | | |
| Steam: library import, wishlist import and sync, playtime sync | | | | | | | | |
| Shared space: invite, accept, entries, per-member data, leave | | | | | | | | |
| Appearance: themes, theme editor, preview, custom themes | | | | | | | | |
| Settings > General: profile picture, default sort, motion and blur switches, "Lighter Effects" note | | | | | | | | |
| Settings > Security: password, two-factor on and off, backup codes, sign out everywhere, biometric lock | | | | | | | | |
| Settings > Integrations: IGDB, Steam, SteamGridDB keys | | | | | | | | |
| Settings > Backups: create, restore, download to the share sheet, space backups and restore approval | | | | | | | | |
| Settings > Updates: check, channel, install (Android), KravaSigner note (iOS), restart (desktop) | | | | | | | | |
| Settings > About: version, source link | | | | | | | | |

## Sheets and tools

| Function | iP | iL | RP | RG | OP | OG | D | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Command palette (desktop: Cmd/Ctrl+K; mobile: from More) | | | | | | | | |
| Keyboard shortcuts sheet (desktop only, `n/a` on mobile without a keyboard) | | | | | | | | |
| Random pull | | | | | | | | |
| Duplicate games | | | | | | | | |
| IGDB sync, including the "stopped while in the background" message | | | | | | | | |
| Achievements | | | | | | | | |
| Category manager | | | | | | | | |

## Shell and platform

| Function | iP | iL | RP | RG | OP | OG | D | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Navigation: bottom bar (portrait), rail (landscape), More drawer, desktop sidebar | | | | | | | | |
| Back: system back gesture, B button, top bar back; never behind the lock | | | | | | | | |
| Turning the device keeps the page and its state | | | | | | | | |
| Safe areas: notch, Dynamic Island, home indicator, rounded corners | | | | | | | | |
| On-screen keyboard: fields stay visible, matching keyboard types | | | | | | | | |
| Gamepad: focus visible everywhere, D-pad reaches every control, A activates, shoulders switch groups | | | | | | | | |
| Biometric lock: at start, after five minutes in the background, app switcher shows no backlog | | | | | | | | |
| Share sheet and file pickers (CSV, pictures) | | | | | | | | |
| Long-running streams (Steam, IGDB, CSV) after a trip to the background | | | | | | | | |
| Update: Android installs from the app after the "install unknown apps" permission; iOS shows the notice | | | | | | | | |
| Lighter effects in battery saver / Low Power Mode, back to full when it is off | | | | | | | | |
| Scrolling the library with about 2000 entries: no visible jank | | | | | | | | |
| Sign out, session expiry, offline and server errors | | | | | | | | |

## Gaps

Every gap found here gets an issue (part of #289) and its number in the cell; the list below keeps them in one place.

| Issue | Gap | Status |
| --- | --- | --- |
| | | |

## Sign-off

| Device | Checked by | Date | Version |
| --- | --- | --- | --- |
| iPhone 16 Pro | | | |
| Retroid Pocket 6 | | | |
| AYN Odin 3 | | | |
| Desktop | | | |
