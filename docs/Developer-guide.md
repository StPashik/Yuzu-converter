# Developer guide

Start with the [requirements](Requirements.md), [architecture](Architecture.md), and [conversion matrix](Conversion-matrix.md). They separate the target behavior from implemented routes and verified results. [Validation.md](Validation.md) keeps historical release results separate from pending checks. This guide describes the current source; it does not record a new build or test run.

## Read the source in this order

| Entry point | Responsibility |
| --- | --- |
| [App.swift](../Sources/YuzuApp/App.swift) | `YuzuMain`, app startup, source detection, the serial job queue, progress, and termination |
| [Wheel.swift](../Sources/YuzuApp/Wheel.swift) | Modifier trigger, geometry, real AppKit drag callbacks, source revalidation, and accessible sectors |
| [AccessStore.swift](../Sources/YuzuApp/AccessStore.swift) and [Actions.swift](../Sources/YuzuApp/Actions.swift) | Powerbox/bookmarks, `ScopedFiles`, system Actions, clipboard leases, and the shelf |
| [SourceFile.swift](../Sources/YuzuCore/SourceFile.swift), [FileFormat.swift](../Sources/YuzuCore/FileFormat.swift), and [ConversionEngine.swift](../Sources/YuzuCore/ConversionEngine.swift) | Content identification, format identity, available targets, dispatch, and output validation |
| [FileOperations.swift](../Sources/YuzuCore/FileOperations.swift), [Archive.swift](../Sources/YuzuCore/Archive.swift), and [ProcessRunner.swift](../Sources/YuzuCore/ProcessRunner.swift) | Safe file publication, ZIP creation, archive validation, bounded subprocesses, and cancellation |
| [Settings.swift](../Sources/YuzuApp/Settings.swift) and [Localization.swift](../Sources/YuzuApp/Localization.swift) | Preferences, the language picker, text lookup, and resource-bundle selection |
| [Core tests](../Tests/YuzuCoreTests/ConversionTests.swift), [App tests](../Tests/YuzuAppTests/WheelTests.swift), and [npm tests](../Tests/npm/installer.test.mjs) | Executable examples and regression boundaries |

Backend details live in `NativeDocuments.swift`, `NativeMedia.swift`, `Spreadsheet.swift`, `EPUB.swift`, and `TextFormats.swift` under `Sources/YuzuCore`.

## App versus Core

`YuzuApp` owns windows, AppKit callbacks, user preferences, localization, and file grants. Its UI controllers run on the main actor. `YuzuCore` receives usable URLs and owns conversion, parsing, filesystem validation, and technical diagnostics. Core may use system document/media frameworks; it must not present permission or destination dialogs.

Keep shared contracts small. Existing public entry points include `SourceFile(url:)`, `ConversionEngine.targets(for:)`, `convert(_:to:in:)`, `FileOperations.copy(_:to:move:)`, and `compress(_:in:)`. Read their English API/flow comments before changing ownership or failure behavior. Comments should explain guarantees and consequential choices, not repeat the next line.

## Drag data and security scopes

1. `WheelMonitor` observes mouse/modifier/Escape state to arm a destination with a 1% black background. A fully transparent window is skipped by WindowServer hit-testing before drag entry. It does not read the global drag pasteboard.
2. `WheelDragView` accepts file URLs from the actual `NSDraggingInfo.draggingPasteboard`. The wheel becomes visible only after a confirmed file drag; prepare/drop callbacks revalidate the source URLs.
3. `AppDelegate` creates `ScopedFiles` before deferring drop handling to the next main-queue tick. This lets the AppKit drop finish before Powerbox or sharing UI opens.
4. `ScopedFiles` retains the immutable URLs and only the grants successfully started; deinitialization balances those grants. Retain this object for the operation's full lifetime rather than retaining bare URLs alone.
5. `AccessStore.outputFolder(beside:)` restores or requests the actual parent folder and checks it with `isParent`. A dropped file does not grant write access to its parent. Queued jobs retain destination access and release it after completion or queue cancellation.

AirDrop retains source scopes until its sharing delegate completes. Clipboard Copy retains its lease until pasteboard `changeCount` changes. Shelves retain leases for their referenced files. These code paths do not replace the deferred physical Finder/Sandbox integration checks.

## Jobs, cancellation, and publication

`AppDelegate` queues `PendingJob` values for conversion, move, or compression. Work runs in `Task.detached`; `withTaskCancellationHandler` forwards UI cancellation to the worker. Format detection uses a generation identifier to discard stale results. Termination cancels queued/active work and waits for the current job and detection before answering AppKit.

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

- Work on `feature/*` from `develop`; obtain independent QA, merge with `--no-ff`, and reserve `main`/tags for releases. Never force-push or rewrite published tags/assets.
- Check package/plist versions, minimum macOS, both architectures, five-table key/placeholder parity, English fallback, live UI updates, and copied release resources. Keep physical checks explicitly deferred until performed.
- Run automated checks in separate scratch paths; do not share a Swift build directory between parallel runs:

```sh
npm ci --ignore-scripts
npm test
swift test --scratch-path .build/verification
```

The armed-wheel regression test uses the public WindowServer hit-test API. Run the App tests in a logged-in graphical macOS session; they do not simulate an end-to-end Finder drag.

- Build the archives sequentially, run the signed Sandbox app's `--self-check`, and verify signature/architecture/version and installation into temporary homes. Then pin the final archives and pack the installer:

```sh
bash scripts/build-app.sh arm64
bash scripts/build-app.sh x64
node scripts/prepare-npm.mjs dist
npm pack --pack-destination dist
```

- If an archive changes, regenerate its manifest/package/checksums. Keep `Release-checksums-0.1.0.txt` immutable. Check the actual final ZIPs and npm package, license notices, and English release notes before publishing. Record new results by version in [Validation.md](Validation.md); historical passes are not new verification.
