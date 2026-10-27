# Application updates

## Using updates

Choose **Check for Updates…** from either the menu bar or Settings. Yuzu checks only when asked. When a new version is available, Sparkle offers a download, followed by installation and restart with your confirmation. It checks the signed feed and the update archive before extraction. A failed network request or cancelled installation leaves the current app usable.

The updater waits for the current conversion/file-operation queue to finish. Once installation starts, Yuzu stops accepting new file drags. If installation fails or is cancelled while the app remains open, dragging is restored.

Version 0.2.0 is the first release with this feature. Earlier versions need one direct-download or npm installation first. Updates apply to the running app bundle. Keep using the same copy if you have installations in both `/Applications` and `~/Applications`; updating one does not replace the other. A newer app is preserved when an older npm launcher runs. In-app updates do not update the npm package itself.

## Implementation

[AppUpdater.swift](../Sources/YuzuApp/AppUpdater.swift) owns one Sparkle controller shared by both entry points. Sparkle's standard interface handles version comparison, progress, user confirmation, authorization when necessary, installation, and relaunch. English code comments describe the queue/restart ownership. App-owned strings are translated into all five languages; Sparkle dialogs may require restarting after a language change.

The dependency is pinned to Sparkle 2.10.1 in [Package.resolved](../Package.resolved). The app enables outgoing network access and the Installer launcher service, with the two required mach lookup exceptions. The rest of the application remains sandboxed. No Node.js runtime is bundled or required by the native updater.

Current preview apps use ad-hoc signing. Their build disables library validation because an ad-hoc signature has no Team ID for loading a bundled dynamic framework. A Developer ID build retains library validation. Developer ID signing and Apple notarization are still absent from this preview; Ed25519 update signatures do not provide notarization.

## Signing and publishing a release

The public Ed25519 key is embedded as `SUPublicEDKey`. The private key is in the owner's login Keychain under the Sparkle account `com.stpashik.yuzu-converter`. It was generated for this project and was never exported or committed. Keep a secure backup of the Keychain: losing this key prevents seamless updates of these ad-hoc-signed builds. Never put a private signing key in Git or release assets.

1. Bump `package.json`, its lockfile, and `CFBundleShortVersionString`. Increase the integer `CFBundleVersion` on every release: Sparkle compares that build number.
2. Run the tests, build arm64 and x64 separately, and run both signed apps' self-checks.
3. Run `node scripts/prepare-npm.mjs dist`, then `node scripts/prepare-updates.mjs dist`.
4. The update script signs both final ZIPs using Sparkle's Keychain tools, independently verifies those signatures against the embedded public key with Node's crypto API, and signs/verifies both XML feeds. It refuses stale archive hashes. Do not rebuild an archive after signing without regenerating its manifest, feeds, npm package, and checksums.
5. Pack the npm installer, record final checksums, and follow GitFlow. Commit the feeds into the release so `main/updates/appcast-arm64.xml` and `appcast-x64.xml` advance together with the source. Upload those exact ZIPs and XML feeds to the new GitHub Release. Never rewrite a published tag or replace an old release's assets.

The feeds are served over HTTPS from `raw.githubusercontent.com/StPashik/Yuzu-converter/main/updates/`; each build embeds its own architecture's URL. Downloads use immutable versioned GitHub Release URLs. A brief publication or cache delay may return an error until the new assets are available; retrying does not replace the installed app prematurely.

The npm archive guard permits only Sparkle's nine canonical, fixed-target framework symlinks. It rejects other links, duplicate paths, empty path components, and members below a symlink before extraction.

See [Sparkle setup](https://sparkle-project.org/documentation/), [Sandbox integration](https://sparkle-project.org/documentation/sandboxing/), and [publishing updates](https://sparkle-project.org/documentation/publishing/) for the upstream contracts. Test results and unverified physical gates belong in [Validation.md](Validation.md).
