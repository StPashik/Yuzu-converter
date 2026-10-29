# Application updates

## Using updates

Yuzu checks quietly at launch and about once a day by default. **Settings → About → Check for updates automatically** controls the saved Sparkle preference; turning it off disables future startup/scheduled checks while preserving **Check for Updates…** in the menu bar and Settings. An explicit previously saved preference is honored when upgrading.

When an update is found, choose **Install Update**, **Remind Me Later**, or **Skip This Version**. Closing the window and Remind Me Later dismiss the offer; it may return on a later launch or scheduled check (normally daily). Skip This Version suppresses that specific version until you check manually or a newer version is published. A current version or background network/signature failure produces no error/no-update popup. Manual checks retain their normal progress/result/error UI. When a new version is available, Sparkle shows its English Release Notes in the update window and offers a download, followed by installation and restart with your confirmation. It checks the signed feed and the update archive before extraction. A failed network request or cancelled installation leaves the current app usable.

The updater waits for the current conversion/file-operation queue to finish. Once installation starts, Yuzu stops accepting new file drags. If installation fails or is cancelled while the app remains open, dragging is restored.

Version 0.2.0 is the first release with this feature. Earlier versions need one direct-download or npm installation first. Updates apply to the running app bundle. Keep using the same copy if you have installations in both `/Applications` and `~/Applications`; updating one does not replace the other. A newer app is preserved when an older npm launcher runs. In-app updates do not update the npm package itself.

## Implementation

[AppUpdater.swift](../Sources/YuzuApp/AppUpdater.swift) owns one Sparkle controller shared by both entry points. Sparkle's standard interface handles version comparison, progress, user confirmation, authorization when necessary, installation, and relaunch. English code comments describe the queue/restart ownership. App-owned strings are translated into all five languages; Sparkle dialogs may require restarting after a language change.

The dependency is pinned to Sparkle 2.10.1 in [Package.resolved](../Package.resolved). The app enables outgoing network access and the Installer launcher service, with the two required mach lookup exceptions. The rest of the application remains sandboxed. No Node.js runtime is bundled or required by the native updater.

Current builds use ad-hoc signing. Their build disables library validation because an ad-hoc signature has no Team ID for loading a bundled dynamic framework. A Developer ID build retains library validation. Developer ID signing and Apple notarization are still absent from these builds; Ed25519 update signatures do not provide notarization.

## Signing and publishing a release

The public Ed25519 key is embedded as `SUPublicEDKey`. The private key is in the owner's login Keychain under the Sparkle account `com.stpashik.yuzu-converter`. It was generated for this project and was never exported or committed. Keep a secure backup of the Keychain: losing this key prevents seamless updates of these ad-hoc-signed builds. Never put a private signing key in Git or release assets.

Follow [Releasing.md](Releasing.md): feature PR → develop, release PR → main, tag the release-PR merge commit, draft/verify/publish as stable Latest, publish legacy bridge feeds by a separate PR, and merge the release branch back by PR. CI checks native Apple Silicon and Intel builds without receiving the production signing key. Never push shared branches directly or install the release for the owner.

`prepare-updates.mjs` embeds `docs/Release-notes-<version>.md` as native Sparkle Markdown inside the signed feed. Both architecture feeds and the GitHub release use the same reviewed English notes; missing or wrong-version notes stop preparation before signing. Existing Sparkle clients can display them without first installing this patch. CDATA-like content is preserved safely. `SUShowReleaseNotes` is explicitly enabled.

`prepare-updates.mjs` writes signed appcasts into the artifact directory, not the live `updates/` directory. New apps use their architecture-specific appcast attached to `releases/latest`; its enclosure remains an immutable versioned GitHub ZIP URL. Publishing Latest therefore switches a complete public release. Normal releases do not use GitHub's prerelease flag; ad-hoc signing and absent notarization are disclosed separately.

Versions through 0.4.0 still use `raw.githubusercontent.com/.../main/updates/`. Keep this compatibility bridge and advance its exact signed bytes through a PR only after the referenced assets are public. The first owner-initiated upgrade moves the installed app to the Latest-release feed. Do not replace the existing public update key during this migration. Version 0.4.2 restores Intel after native CI and signed Sandbox verification passed. Its signed x64 bridge advances only after the new x64 archive is public. The npm installer selects the pinned archive for the running Node CPU and rejects unsupported CPUs before any download or replacement.

The owner controls automatic checking with the checkbox and chooses whether to download, install, and restart. Verify releases using temporary homes and isolated information-only probes; do not run a global npm install, quit/relaunch, or replace either installed copy during publication. Signing verifies future updates and does not itself authorize installation.

The npm archive guard permits only Sparkle's nine canonical, fixed-target framework symlinks. It rejects other links, duplicate paths, empty path components, and members below a symlink before extraction.

After building the selected app, run `python3 scripts/test-updates.py --arch arm64` (or `x64`) with Swift and Node on PATH. This exercises Sparkle's real HTTP and signature/version logic against a local server: available update, current version, tampered signed feed, and HTTP 500. The fixture uses a temporary test key and an isolated app identity; it neither accesses the release Keychain key nor downloads/installs an update. These passes do not replace verification of the production signatures/feed or a full interactive installation.

See [Sparkle setup](https://sparkle-project.org/documentation/), [Sandbox integration](https://sparkle-project.org/documentation/sandboxing/), and [publishing updates](https://sparkle-project.org/documentation/publishing/) for the upstream contracts. Test results and unverified physical gates belong in [Validation.md](Validation.md).

## Startup and preference verification (0.7.1)

`SUEnableAutomaticChecks` defaults to true. Install 0.7.1 once through the existing manual update command to enable this behavior; older binaries do not gain startup checking from a feed change alone.

`AppUpdater.start` invokes `checkForUpdatesInBackground` once immediately after starting Sparkle, only when its persisted preference is enabled. A SwiftPM development run never starts the updater. KVO keeps the five-language Settings checkbox synchronized; its setter delegates persistence/scheduling directly to Sparkle rather than maintaining a second preference. Sparkle owns the reminder timer and skipped-version state. `SUAutomaticallyUpdate` and `SUAllowsAutomaticUpdates` remain false, so automatic checking cannot opt the user into automatic downloads/installation. Existing file-queue/relaunch safeguards remain.

The HTTP fixture now also checks background offer/current/tampered/offline behavior, dismiss/remind, disable and re-enable persistence across processes, manual checks while disabled, skipped versions, and manual recovery. A noninteractive standard-driver subclass replies only Dismiss/Skip, fails if any download or unexpected popup is attempted, and uses a signed temporary app identity/test key. No owner app or production signing key is involved. Both native CI jobs run this fixture after validating their signed archives. Physical dialog interaction/macOS 13 checks remain deferred/unverified.

The startup call follows [Sparkle’s API guidance](https://sparkle-project.org/documentation/api-reference/Classes/SPUUpdater.html); default checking and mandatory installation consent use [its supported configuration](https://sparkle-project.org/documentation/customization/).
