# Developer guide

Start with the [requirements](Requirements.md), [architecture](Architecture.md), and [conversion matrix](Conversion-matrix.md). They separate the target behavior from implemented routes and verified results. [Validation.md](Validation.md) keeps historical release results separate from pending checks. This guide describes the current source; it does not record a new build or test run.

## Read the source in this order

| Entry point | Responsibility |
| --- | --- |
| [App.swift](../Sources/YuzuApp/App.swift) | `YuzuMain`, app startup, source detection, shared shelf/wheel request preparation, and termination |
| [Wheel.swift](../Sources/YuzuApp/Wheel.swift) | Modifier trigger, geometry, real AppKit drag callbacks, source revalidation, and accessible sectors |
| [AccessStore.swift](../Sources/YuzuApp/AccessStore.swift) and [Actions.swift](../Sources/YuzuApp/Actions.swift) | Powerbox/bookmarks, `ScopedFiles`, system Actions, clipboard leases, and shelf presentation |
| [JobQueue.swift](../Sources/YuzuApp/JobQueue.swift) and [QueueWindow.swift](../Sources/YuzuApp/QueueWindow.swift) | Serial worker, cancellation, publication history, and the shared-style operations panel |
| [Shelf.swift](../Sources/YuzuApp/Shelf.swift) | Menu-bar anchoring, native glass/material/opaque surfaces, lazy Quick Look previews, file drops/drag-out, and reference/grant ownership |
| [ShelfShortcut.swift](../Sources/YuzuApp/ShelfShortcut.swift) and [FinderSelection.swift](../Sources/YuzuApp/FinderSelection.swift) | In-app chord recording, Finder-only native registration, fixed-source selection requests, and strict file-descriptor validation |
| [SourceFile.swift](../Sources/YuzuCore/SourceFile.swift), [FileFormat.swift](../Sources/YuzuCore/FileFormat.swift), and [ConversionEngine.swift](../Sources/YuzuCore/ConversionEngine.swift) | Content identification, format identity, available targets, dispatch, and output validation |
| [FileOperations.swift](../Sources/YuzuCore/FileOperations.swift), [Archive.swift](../Sources/YuzuCore/Archive.swift), and [ProcessRunner.swift](../Sources/YuzuCore/ProcessRunner.swift) | Safe file publication, ZIP creation, archive validation, bounded subprocesses, and cancellation |
| [Settings.swift](../Sources/YuzuApp/Settings.swift), [SettingsView.swift](../Sources/YuzuApp/SettingsView.swift), and [SystemPreferences.swift](../Sources/YuzuApp/SystemPreferences.swift) | Five-tab settings, per-output profiles, shortcut migration, folder access, and real login-item/terminal choices |
| [ConversionOptions.swift](../Sources/YuzuCore/ConversionOptions.swift) and [Localization.swift](../Sources/YuzuApp/Localization.swift) | Validated encoding parameters and five-language UI lookup |
| [Core tests](../Tests/YuzuCoreTests/ConversionTests.swift), [App tests](../Tests/YuzuAppTests/WheelTests.swift), and [npm tests](../Tests/npm/installer.test.mjs) | Executable examples and regression boundaries |

Backend details live in `NativeDocuments.swift`, `NativeMedia.swift`, `Spreadsheet.swift`, `EPUB.swift`, and `TextFormats.swift` under `Sources/YuzuCore`.

## App versus Core

`YuzuApp` owns windows, AppKit callbacks, user preferences, localization, and file grants. Its UI controllers run on the main actor. `YuzuCore` receives usable URLs and owns conversion, parsing, filesystem validation, and technical diagnostics. Core may use system document/media frameworks; it must not present permission or destination dialogs.

Keep shared contracts small. Existing public entry points include `SourceFile(url:)`, `ConversionEngine.targets(for:)`, `convert(_:to:in:)`, `FileOperations.copy(_:to:move:)`, and `compress(_:in:)`. Read their English API/flow comments before changing ownership or failure behavior. Comments should explain guarantees and consequential choices, not repeat the next line.

## Drag data and security scopes

1. `WheelMonitor` observes mouse/modifier/Escape state to arm a destination with a 1% black background. A fully transparent window is skipped by WindowServer hit-testing before drag entry. It does not read the global drag pasteboard.
2. `WheelDragView` accepts file URLs from the actual `NSDraggingInfo.draggingPasteboard`. The wheel becomes visible only after a confirmed file drag; prepare/drop callbacks revalidate the source URLs.
3. `AppDelegate` creates `ScopedFiles` before deferring drop handling to the next main-queue tick. This lets the AppKit drop finish before Powerbox or sharing UI opens.
4. `ScopedFiles` retains immutable URLs, grants successfully started for those URLs, and any already-active parent grants explicitly transferred by `AccessStore.shelfFiles`. Deinitialization balances those grants. Retain this object for the operation's full lifetime rather than retaining bare URLs alone; callers must not stop transferred scopes a second time.
5. `AccessStore.outputFolder(beside:)` restores or requests the actual parent folder and checks it with `isParent`. A dropped file does not grant write access to its parent. Queued jobs retain destination access and release it after completion or queue cancellation.

AirDrop retains source scopes until its sharing delegate completes. Clipboard Copy retains its lease until pasteboard `changeCount` changes. Shelves retain leases for their referenced files and pending Quick Look requests, including while a shelf window is closed. Closing cancels preview work but keeps the session's collection; remove/clear explicitly releases references, and exiting Yuzu ends the session. Stale preview callbacks cannot repopulate removed rows. These code paths do not replace the deferred physical Finder/Sandbox integration checks.

The shelf hotkey uses `RegisterEventHotKey` with exclusive registration so a reported conflict cannot silently replace the saved choice. `NSWorkspace` activation changes enable it only in Finder. Its recorder observes local key-down events while the settings field is active, unregistering nothing in another app and requesting no Accessibility permission. `FinderSelection.read` runs serially off the main thread, uses a fixed ten-second AppleScript, and accepts only alias/file-URL descriptors: Foundation can otherwise coerce arbitrary text into a file URL. Automation permission identifies the selected files but does not establish readable Sandbox access. `AccessStore.shelfFiles` uses the shared validated folder-grant path for every Sandbox batch, even when another shelf currently makes the file readable; cancellation releases acquired scopes without opening a partial shelf. Keep the Finder exception limited to its one bundle identifier and localize `InfoPlist.strings` alongside the app's UI tables.

## Jobs, cancellation, and publication

JobRequest also captures ConversionOptions by value. Read a profile for the selected output format before queueing, including ZIP Action compression. Do not read mutable preferences from background encoders. Keep UI applicability aligned with validation and actual backend execution; an unavailable layout must not become an enabled control that does nothing. [Settings.md](Settings.md) records the encoding choices and limits.

`AppDelegate` submits `JobRequest` values to `JobQueue` for conversion, move, or compression. Work runs in `Task.detached`; `withTaskCancellationHandler` forwards UI cancellation to the worker. Format detection uses a generation identifier to discard stale results. Termination cancels queued/active work and waits for the current job and detection before answering AppKit.

Keep cancellation checks around expensive stages and before publication. `ProcessRunner` bounds output and time, terminates cancelled processes, and escalates termination when necessary. Conversion uses private scratch with `defer` cleanup. Multi-page output is validated and published as one folder. `FileOperations.publish` uses `RENAME_EXCL` and available-name retries, avoiding a check-then-overwrite race.

Atomicity is per published item or output set, not across an entire multi-input job. Earlier completed items remain when a later item fails or is cancelled. Move also has no whole-batch rollback. Cross-volume folders are refused; cross-volume files compare source size/mtime around copying without content hashing. Preserve these limits in user-facing documentation.

## Add a format or backend safely

1. Add the format identity/category to `FileFormat` and a content-based detection path to `SourceFile`. Do not treat an extension or a static candidate entry as proof of support.
2. Update the candidate/availability checks and execution route in `ConversionEngine`. Mixed-input intersections and hiding the current format must still work. Availability must reflect the real decoder, writer, or encoder.
3. Reuse the existing backend and staging patterns. Validate hostile input, archive/XML boundaries, resource limits, and the actual output. Preserve cancellation and non-overwriting publication. Do not bypass the Sandbox tool gate to make a route appear available.
4. Add a small end-to-end fixture that reads the produced content and checks the meaningful promise: pages/DPI, text, values, timing, or media readability. Include a relevant error case when introducing a parser or filesystem boundary.
5. Update the matrix and notices honestly. Before bundling a third-party engine, review its license/source obligations, architecture, signature, and Sandbox behavior. Do not copy Tangerine binaries or resources.

## Localization and English project text

Communicate with the owner in Russian. Keep project documentation, code/API comments, and release copy in English. App-owned UI supports English (default), Russian, German, French, and Spanish. Technical converter diagnostics remain English for support reports. Translated resource values are intentionally localized data and are allowed to contain their target language.

`AppLanguage` in [Localization.swift](../Sources/YuzuApp/Localization.swift) defines stable `en`/`ru`/`de`/`fr`/`es` codes. `L10n.language` persists the choice in the app's UserDefaults. Use `L10n.text(_:_:)` for the selected language and `L10n.string(_:language:arguments:)` when a specific language is needed. Keys themselves are readable English fallbacks: a missing table or entry returns the English key.

The five sibling `Resources/<code>.lproj/Localizable.strings` tables must have identical keys: [English](../Sources/YuzuApp/Resources/en.lproj/Localizable.strings), [Russian](../Sources/YuzuApp/Resources/ru.lproj/Localizable.strings), [German](../Sources/YuzuApp/Resources/de.lproj/Localizable.strings), [French](../Sources/YuzuApp/Resources/fr.lproj/Localizable.strings), and [Spanish](../Sources/YuzuApp/Resources/es.lproj/Localizable.strings). Start with English; add each key to every language and preserve format placeholders and argument types. Pass arguments separately, for example `L10n.text("Converting to %@", format.label)`, rather than interpolate a new lookup key. Keep table comments and keys English; translate values deliberately.

[Package.swift](../Package.swift) declares `defaultLocalization: "en"` and processes App resources. [build-app.sh](../scripts/build-app.sh) copies the `.lproj` folders into `Contents/Resources` before signing. Lookup uses `Bundle.main` for the packaged app and `Bundle.module` for SwiftPM. Check both layouts; a developer-run success does not prove release resources were copied.

App-owned UI refreshes live when the setting changes. The app-scoped `AppleLanguages` preference lets some standard system dialogs use the new language after restart; it does not change the Mac's global language. Preserve that distinction when testing or documenting localization.

## Build and release checklist

Build release archives with Xcode 26 or later to include the native `NSGlassEffectView` implementation. Its runtime availability check keeps those binaries compatible with macOS 13+. Xcode 16 builds, including native macOS 15 Intel CI, compile the same shelf with the older popover material. Offscreen bitmap tests verify shelf content/layout and opaque surfaces; WindowServer's dynamic glass composition and physical Finder interaction remain separate verification gates.

`AppUpdater.swift` shares the updater between the menu and Settings, retains a postponed installation while jobs run, and restores drag monitoring after cancellation/failure. Its delegate selector tests protect against silently mistyping optional Objective-C methods in Swift. Read [Updates.md](Updates.md) before signing a release; the private signing key stays in Keychain.

- Follow [Releasing.md](Releasing.md): feature PR into develop, release PR into main, tag its exact merge commit, publish stable Latest, and merge back through a PR. Wait for CI and keep merge commits. Do not push shared branches directly, rewrite published tags/assets, or install/restart the owner's app during release work.
- Check package/plist versions, minimum macOS, both native architectures, five-table key/placeholder parity, English fallback, live UI updates, and copied release resources. Keep physical checks explicitly deferred until performed.
- Run automated checks in separate scratch paths; do not share a Swift build directory between parallel runs:

```sh
npm ci --ignore-scripts
npm test
swift test --scratch-path .build/verification
```

The armed-wheel regression test uses the public WindowServer hit-test API. Run the App tests in a logged-in graphical macOS session; they do not simulate an end-to-end Finder drag.

- Build the pinned media engines with `python3 scripts/build-media.py arm64` and `x64`; follow [Bundled media](Bundled-media.md). Rebuild them whenever the recipe or source manifest changes. Run Swift tests with the matching `YUZU_FFMPEG`, `YUZU_FFPROBE`, and `YUZU_MEDIA_REQUIRED=1`; the release video fixtures must not skip. Package the complete corresponding media source with `python3 scripts/package-media-sources.py`.
- Build the archives sequentially, run the signed Sandbox app's `--self-check`, and verify signature/architecture/version and installation into temporary homes. Then pin the final archives and pack the installer:

```sh
bash scripts/build-app.sh arm64
bash scripts/build-app.sh x64
node scripts/prepare-npm.mjs dist
node scripts/prepare-updates.mjs dist
node scripts/verify-update-feeds.mjs dist
npm pack --pack-destination dist
```

- If an archive changes, regenerate its manifest/package/checksums. Keep `Release-checksums-0.1.0.txt` immutable. Check the actual final ZIPs and npm package, license notices, and English release notes before publishing. Record new results by version in [Validation.md](Validation.md); historical passes are not new verification.

### Shelf/queue verification and media caching

[Shelf workflow](Shelf-workflow.md) describes selection, output, cancellation, and session lifetime. The injected queue executor lets regressions suspend work deterministically, verify serial ordering/cancellation, and assert grant lifetime without system dialogs. Real request fixtures also cover conversion, normalized Move, partial publication, ZIP, and invalid destination counts. Material/layout fixtures render five languages in both appearances and inspect native glass structurally; physical Finder/Sandbox and visual checks on other Macs remain separate gates.

Run `python3 -m unittest discover -s Tests/scripts -v` for cache validation. `python3 scripts/build-media.py arm64 --reuse` verifies an exact receipt before reuse; omit `--reuse` to force a fresh build. Never restore `.build` wholesale or cache signing identities. See [CI.md](CI.md) for architecture/toolchain keys and trusted cache warming.

Current shelf interaction tests exercise file-URL callbacks into the wheel, all seven Action targets, a real queued conversion, and scope retention after row removal. They replace the removed shelf menu tests. Queue tests verify successful-row expiry and empty-window closing while failures remain. PDF fixtures inspect visible pixels and dimensions for four rotations and both JPG/PNG: the drawing transform only scales down, so the bitmap context must explicitly scale points to 300 DPI first. The real Sparkle HTTP fixture checks parsed Markdown notes without downloading or installing an app. Physical integrations remain separate gates.

The 0.6.2 workflow also touches `ImageDrop.swift` (accepted representations, promises, bounded ephemeral download, cancellation and disposable grants), `SpreadsheetPDF.swift` (CoreText grid/pagination) and `QueueInsetView` (AppKit-owned margins). Batch tests inspect page order, pixels, table geometry, cached/missing formulas, sparse-layout bounds, same-format image saving and existing-file preservation. Image tests use a private lazy pasteboard, dual screenshot representations, a controlled file-promise receiver and a loopback HTTP server. They cover MIME/size/stream/redirect rejection, cancellation and temporary-path containment. Never equate these fixtures with physical browser/Finder/Powerbox or VoiceOver validation.


The 0.6.3 workflow adds input-identity checkpoints, pending request retention, cached virtual-image retry and atomic row requeueing to `JobQueue`. Keep destination leases shared when copying a request; never transfer the same started scope twice. `FileMove`/`onMove` differs from `onPublish`: the latter may precede a failed source deletion. Only completed move effects update shelf/queued paths. Availability probes use generations and retained source leases; UI replacement preserves selection and rejects stale thumbnail/probe callbacks. Tests cover actual partial conversion/Move, queued folder children, collision naming, directory URL variants, FIFO retry, published-copy cleanup failure, promise replay prevention, temporary-source cleanup, and the only-error-window regression. [Retry and reference recovery](Retry-and-references.md) records user behavior and limits.
