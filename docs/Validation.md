# Release validation record

Updated October 27, 2026. Results are version-specific. Translating the app and documentation does not turn historical checks into fresh runs.

## v0.1.2 — wheel input fix

The owner reported that neither wheel appeared during file dragging with Shift/Control. The running `/Applications/Yuzu Converter.app` was 0.1.1 and matched the npm-installed binary; wheels were enabled. An AppKit probe reproduced the cause on this Mac: an armed panel with a fully clear background was visible but absent from WindowServer hit-testing. The same panel with a 1% black background received the hit.

The new `testArmedWindowReceivesHitsBeforeAFileDragIsConfirmed` exercises the actual monitor window and system hit-test, before any wheel is drawn. It failed against the original clear background and passed after the fix. This confirms the input-window regression; it does not establish an end-to-end Finder drop.

The test uses Apple's public [window hit-test API](https://developer.apple.com/documentation/appkit/nswindow/windownumber%28at%3Abelowwindowwithwindownumber%3A%29) and requires a logged-in graphical WindowServer session. The armed full-screen destination now adds a 1% black wash while waiting for the drag; no wheel content is shown before file URLs are confirmed.

Fresh checks on October 27, 2026, macOS 26.6.2 on Apple Silicon:

| Check | Recorded result |
| --- | --- |
| Native arm64 Swift tests | 30 passed, 0 failed, 0 skipped: 22 Core and 8 App tests |
| Intel XCTest under Rosetta | 30 passed, 0 failed, 0 skipped after a separate x86_64 build |
| Armed-window regression | Old background failed; corrected background passed on both architectures |
| npm 0.1.2 installer tests | 13 passed, including safe upgrade from 0.1.1 |
| Signed arm64/x64 archives | Final 0.1.2 archives passed Info.plist, strict codesign, and lipo checks |
| Signed Sandbox self-checks | Both architectures loaded all five languages and passed conversion and ZIP checks |
| Installation of final ZIPs | Both architectures installed in temporary homes; strict codesign and native version 0.1.2 passed |
| npm tarball | Prepack accepted both pinned hashes; 7 files and no dependencies |

Independent source/test review found no blocker; the shared arming path covers both wheel modes and retains file URL validation. Final hashes are in [Release-checksums-0.1.2.txt](Release-checksums-0.1.2.txt). Publication and installed-app upgrade results are recorded after completion. Physical Finder drag, Powerbox/bookmark recovery, VoiceOver, AirDrop, Terminal, shelf drag-out, Intel hardware, and macOS 13 remain unverified. The app is still an ad-hoc-signed preview without Apple notarization.

## v0.1.1 — multilingual preview

Fresh checks on October 27, 2026, macOS 26.6.2 on Apple Silicon:

| Check | Recorded result |
| --- | --- |
| Native arm64 Swift tests | 29 passed, 0 failed, 0 skipped: 22 Core and 7 App tests |
| Intel XCTest under Rosetta | 29 passed, 0 failed, 0 skipped after a separate x86_64 build |
| npm 0.1.1 installer tests | 13 passed, including safe upgrade from 0.1.0 |
| Five localization tables | 57 matching keys; identical format placeholders; native language names, English fallback, user-data interpolation, and action-label width checks passed |
| Signed arm64/x64 app archives | Info.plist, strict codesign, and lipo passed; final archives rebuilt after localization and comment changes |
| Signed Sandbox self-checks | Both architectures loaded all five language bundles and passed DOCX/textutil, spreadsheet, ZIP/TAR, and Compress to ZIP operations |
| Installation of final 0.1.1 ZIPs | Real arm64/x64 ZIPs installed in temporary homes; strict codesign and executable version 0.1.1 passed |
| Final npm tarball | Prepack accepted both pinned app hashes; package contains 7 installer/README/license files and no dependencies |
| Published GitHub Release | English release body matched the reviewed notes; GitHub-reported SHA-256 digests of all six assets matched local files |
| Upgrade from the public npm package URL | npm 12.2.1 upgraded the existing 0.1.0 installation; CLI and native executable report 0.1.1, installed Info.plist lists all five languages, and strict codesign passed |

Independent source review found no localization regression in persistence, live refresh wiring, format arguments, bundle lookup, or source/output grant ownership. English comments explain the API contracts and safeguards, and the [developer guide](Developer-guide.md) maps the implementation. Non-English values are confined to intentional localization resources; project documentation and comments remain English.

Final artifact hashes are in [Release-checksums-0.1.1.txt](Release-checksums-0.1.1.txt). The public npm installation used a command-scoped remote allowance and permitted postinstall by the exact release URL; no global npm policy changed. The CLI is installed in `~/.local/bin` and the app in `~/Applications`. Historical v0.1.0 artifacts/checksums remain unchanged. Physical UI/language switching, restart, VoiceOver, Finder/Powerbox, and external service checks remain unverified.

## v0.1.0 — completed checks

October 27, 2026, macOS 26.6.2 on Apple Silicon. Source was frozen after ZIP/QA/CRLF fixes. Independent findings are in [QA.md](QA.md) and [NpmQA.md](NpmQA.md).

| Check | Recorded result |
| --- | --- |
| `swift test --scratch-path .build/verification` | 26 passed, 0 failed, 0 skipped |
| Intel bundle: `swift test --arch x86_64 --scratch-path .build/verification-x64` + `arch -x86_64 .../xctest <bundle>` | Build succeeded. The normal arm64 SwiftPM helper could not load the Intel bundle; Intel XCTest then ran 26/26 successfully under Rosetta |
| `npm ci --ignore-scripts --offline`, `npm test` | 13 passed, 0 failed, 0 skipped; no runtime-only dependencies |
| `bash scripts/build-app.sh arm64` and `x64` | Archives built; Info.plist, strict codesign, and lipo checks passed |
| `.app/Contents/MacOS/YuzuApp --self-check` | Sandbox arm64 and x64 under Rosetta passed DOCX/textutil round-trip, CSV/XLSX, ZIP/TAR, and Compress to ZIP checks in private temporary directories |
| `npm pack --pack-destination dist` | Package built with both pinned SHA-256 values; prepack passed; 7 files, no binaries or dependencies |
| Installation of both final app ZIPs | Installer extracted the real arm64/x64 archives into temporary homes; strict codesign and `--version` passed; temporary directories were removed |
| Installation from the published GitHub Release | npm 12.2.1 installed the CLI into `~/.local/bin` and the app into `~/Applications`; the remote dependency was allowed for that command and postinstall was permitted by the exact release URL |
| App/menu bar icons | SHA-256 of both copies matched the authorized Yuzu Mac App originals |

Swift fixtures exercised every PDF page at 300 DPI, EXIF orientation, native audio/video, DOCX/EPUB structure, quoted/CRLF CSV, XLSX/ODS namespaces/row groups/overflow, ZIP creation, archive collisions/traversal/symlinks, subprocess cancellation, and preservation of existing files. The FFmpeg fixture passed with a separately installed tool in developer context; the packaged Sandbox app does not launch external FFmpeg.

The build script ran outside the agent sandbox because nested SwiftPM sandboxing could not run its manifest in the restricted environment. That was a tooling limitation; the finished app’s Sandbox entitlements were retained and verified.

Physical Finder drag, Powerbox/bookmark recovery with external files, AirDrop, Terminal, VoiceOver, and shelf drag-out were not manually tested under the owner’s existing constraint. Container-local Sandbox self-checks do not replace them. Intel hardware, macOS 13, and other macOS versions were not tested directly. A real folder `EXDEV` was not simulated; refusal before copying was inspected statically. Cross-volume file moves compare source size/mtime only, without hashing.

Signing was ad hoc. Developer ID and notarization were absent. The release was therefore marked preview; full Tangerine compatibility was not claimed.

The final v0.1.0 app archives and npm package checksums are in [Release-checksums-0.1.0.txt](Release-checksums-0.1.0.txt). This historical file is immutable. For a new release, regenerate its manifest, npm package, and new checksum record from that release’s final archives rather than altering the v0.1.0 record.
