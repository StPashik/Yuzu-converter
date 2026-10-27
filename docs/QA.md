# Independent app QA — v0.1.0 preview

Review date: October 27, 2026. This records review of the working tree before the v0.1.0 release commit: `Sources/YuzuCore`, `Sources/YuzuApp`, their contracts and relevant fixtures, `scripts/build-app.sh`, `Package.swift`, `Resources/Info.plist`, and entitlements. This reviewer authored the npm installer, so their own npm tests were not treated as independent installer review; see the separate [NpmQA.md](NpmQA.md).

This is a translated historical record, followed by version-specific updates. Fresh v0.1.1 results are recorded separately in [Validation.md](Validation.md): 29 Swift tests per architecture, 13 installer tests, localization checks, signed Sandbox self-checks, and final ZIP installation. These are new runs, not inferred historical results.

## Verdict at review time

No significant unresolved finding remained in the statically rechecked scope. The implementation was suitable for a preview with the limits in [Conversion-matrix.md](Conversion-matrix.md). This did not establish full Tangerine parity or readiness of every candidate pair.

The manager owned the final automated run after the CR/LF/CRLF fix. This reviewer did not run a parallel Swift build, tests, the app, or manual Finder/Sandbox checks. At the original review time, final pass counts, archive readiness, and signed `.app --self-check` results were not confirmed by this reviewer. The manager later recorded those results below and in [Validation.md](Validation.md).

## Rechecked fixes

| Original scenario | What was checked in the code | Fixture evidence inspected |
| --- | --- | --- |
| Quitting during conversion could leave a process and scratch files | `applicationShouldTerminate` cancels jobs, waits for active work and format detection, then answers AppKit; the queue cannot restart during termination | Process cancellation fixture exists; this reviewer did not physically quit a running app |
| Powerbox could remember a different folder as the input’s parent | Fresh and restored URLs are checked by `AccessStore.isParent`; invalid grants are released and previously acquired folders are closed through `defer` after error/cancellation | `testOutputGrantMustBelongToTheActualSourceParent` |
| Sandbox release offered external FFmpeg/LibreOffice | `YuzuSandboxed=true` restricts `Tools.find` to `Bundle.Resources/Tools`; the native media fallback checks system reader/exporter availability | Native audio/video fixtures; finished signed-app execution was a separate check |
| A nested file change could be missed during a cross-volume folder move | `EXDEV` refuses folders before copy/delete and preserves the original; the limitation is explicit in requirements | Branch inspected statically; no real cross-volume folder move was run |
| ODS repeated counts could overflow `Int` | Bounds use remaining capacity before addition and multiplication | `testODSRepeatedCountsCannotOverflow` |
| XML prefixes and ODS row containers could produce empty/incomplete output | Namespace URIs identify elements/attributes; ODS header/group/rows containers are traversed; missing sheets cause an error | `testPrefixedXLSXAndWrappedODSKeepRowsAndNamespaces` |
| XML text was copied to every node on the stack | Each node stores its own ordered text/child fragments; mixed text and CDATA preserve order; ancestor duplication was removed | Mixed XML/CDATA assertion in the table fixture |
| Archive names could overwrite another extracted file | Duplicate, case, normalized-name, and implicit-parent checks; files use `O_EXCL`/`O_NOFOLLOW`; links and paths outside scratch are rejected | `testArchiveRejectsDuplicateCaseAndDirectoryAliasesWithoutTruncation` and link/traversal fixtures |
| RIFF/FORM offsets were counted as Unicode characters | Container markers use bytes `8..<12`, so binary lengths no longer shift WAVE/AIFF/AVI/WebP markers | `testRIFFByteOffsetsAndLargeQuotedCSVContentDetection` |
| Large CSV detection used a truncated quoted prefix | Tabular candidates parse the complete bounded text rather than an incomplete 64 KiB prefix | Large quoted CSV in the same fixture |
| Windows rows were skipped and CRLF inside fields changed | Detection uses `.newlines`; the parser distinguishes CR/LF/CRLF outside quotes, preserves the original newline inside quoted fields, and the writer quotes those fields | `windowsRows` round-trip assertion in the same fixture |
| Portrait JPEG became sideways PDF | ImageIO applies EXIF orientation at the original maximum size; PDF dimensions come from the transformed image | `testJPEGOrientationIsAppliedToPDFWithoutDownsampling` |

A fixture’s presence means its content was inspected. The final run log, rather than its existence, establishes execution results.

## Compress to ZIP and the UI queue

`FileOperations.compress(_:in:) throws -> URL` is a public synchronous Core operation. It normalizes selected inputs, removes duplicates and already-included descendants, rejects duplicate top-level names and links, and refuses to place the ZIP inside a selected directory. Data is copied into private scratch first; `ArchiveReader` validates the finished ZIP, then `RENAME_EXCL` publishes it under an available name. Sources are never moved or removed. Cancellation is checked before work, during traversal/copying, in the process, and before publication.

The UI acquires access to the first input’s parent and queues the ZIP Action as `JobKind.compress`; Core runs in `Task.detached`. The job retains source scopes and destination permission, propagates cancellation to the worker, and releases destination permission after completion. `testCompressFilesAndFolderWithoutOverwritingOrFollowingLinks` and `testCompressCancellationCreatesNoArchive` check contents, available names, preservation of originals, rejection of links/duplicate names, and cancellation.

Drop handling waits until the next main-queue tick after constructing `ScopedFiles`, allowing AppKit drop to finish before Powerbox/sharing. Clipboard Copy retains its source lease until `NSPasteboard.changeCount` changes. These were code observations; physical grant transfer among Finder, clipboard, and the app remains a deferred check.

## Packaging and authorized icons

The historical release/npm contracts matched: `Yuzu Converter.app`, executable `YuzuApp`, bundle ID `com.stpashik.yuzu-converter`, version `0.1.0`, minimum macOS `13.0`, and assets `Yuzu-Converter-0.1.0-arm64.zip` / `Yuzu-Converter-0.1.0-x64.zip`. The build script restricts architecture, compares package/plist versions, signs with entitlements, checks `lipo`, and uses `ditto --norsrc --keepParent` for one app root. It does not touch the user’s installed app.

The owner explicitly allowed two app icons from Yuzu Mac App. Read-only SHA-256 comparison confirmed both originals matched their copies:

- `Resources/YuzuAppIcon.icns`: `6a250b9e4853a92ad09a82b6b1e3e9bceb0b4063a2e6a3a37d001286737a5b86`.
- `Sources/YuzuApp/Resources/YuzuMenuBar.pdf`: `41876c86fa4ea93f5e9efcd27213aa210d67f338ad54694ddef341462713b518`.

The app icon is copied to `Contents/Resources/Yuzu.icns` and referenced by Info.plist. The menu bar PDF is copied into app resources; the app reads it through `Bundle.main`, with a `Bundle.module` fallback for developer runs. This review transferred no other old source/history or Tangerine resources. The later v0.1.1 request also permits an app-icon PNG solely for documentation; that is not an additional historical app asset check.

## Exact preview boundaries

- Cross-volume file Move compares the source’s size and `modificationDate` before/after copying. There is no hash comparison, locking, or filesystem snapshot, so protection against concurrent changes with unchanged metadata is not claimed. Detected changes keep both copies. Cross-volume folders are refused before copying; this reviewer did not exercise a real `EXDEV`.
- The full Tangerine matrix is not implemented. Format, codec/layout, and values-only limits remain in the conversion matrix. Archive limits and link/collision rejection also apply to created ZIP validation.
- The owner deferred physical Finder drag, VoiceOver during drag, Powerbox/bookmark recovery, clipboard paste, AirDrop, Terminal, and shelf drag-out. No new manual checks were requested or performed.
- An x64 build does not prove Intel hardware execution; minimum macOS 13 metadata does not prove testing on macOS 13. Report signing, notarization, Gatekeeper, and published-release installation only from actual distribution evidence.

The original review changed only this record and created no code commits or background processes.

## Manager’s subsequent v0.1.0 results

The final 26 Swift tests passed on native arm64 and x86_64 under Rosetta; 13 Node tests passed. Both signed Sandbox archives passed self-checks, installation into temporary homes, strict codesign, and version checks. [Validation.md](Validation.md) records commands and evidence limits. These were the manager’s additions to the independent static review; deferred physical checks remained open. They do not establish v0.1.1 results.
