# Release validation record

Updated October 27, 2026. Results are version-specific. Translating the app and documentation does not turn historical checks into fresh runs.

## v0.4.0 — Bundled video engines

Fresh checks on October 27, 2026, macOS 26.6.2 on Apple Silicon:

| Check | Recorded result |
| --- | --- |
| Native arm64 Swift tests | 64 passed, 0 failed, 0 skipped: 40 Core and 24 App tests |
| Intel XCTest under Rosetta | 64 passed, 0 failed, 0 skipped using the separately built x86_64 bundle and explicit x86_64 XCTest launcher |
| Video matrix | 48 directed routes across MP4/MOV/MKV/WebM/AVI/WMV/GIF and MP3 extraction; real stream/frame counts, full output decoding, content-based format detection, and unchanged original bytes |
| Stream and failure gates | Silent-video MP3 hidden; video-to-MP3 catalogue is file-dependent; damaged input publishes nothing; descriptor copy retains seeking and refuses existing destinations |
| Playback and metadata | Known disabled/non-unit-volume audio/video tracks hide FFmpeg routes; native mute/half-gain and global/stream/chapter metadata-removal regressions ran and passed |
| Settings/localization | 170 matching keys in each of five tables; five-tab/format-editor render regression, shortcut/access/updater tests, and placeholders passed |
| Node installer tests | 16 passed, 0 failed, 0 skipped; fixtures follow the package version, including 0.3.0 upgrade and newer-version preservation |
| Engine builds | FFmpeg/FFprobe 9.0.2, libvpx 1.17.0, Opus 1.6.1, LAME 3.100; pinned upstream archive hashes; GPL/version3/nonfree disabled; only system runtime dependencies |
| Final ZIP inspection | Both exact archives passed deep strict codesign, expected CPU and macOS 13 load target, exactly two helper Sandbox/inherit entitlements, manifest/license bytes, and all five localization copies |
| Packaged Sandbox media | Both extracted signed apps passed with invalid external tool overrides and system-only PATH; all seven MOV targets, reverse video conversion, actual probe/decode, profiles, original preservation, and earlier document/archive checks passed |
| Final installation | Both final ZIPs installed into temporary homes; actual native version 0.4.0 and code signatures passed |
| Update signing | Both final archive signatures independently verified against the embedded production public key; both appcasts signed and verified with build 7 / version 0.4.0 |
| Sparkle HTTP fixtures | Available/current, tampered signed-feed rejection, and HTTP 500 checks reached the local server and passed with an isolated temporary key |
| npm package | Prepack accepted the final archive hashes; seven files, no dependencies, version-pinned GitHub installation |
| Public publication | English preview with nine assets; every GitHub-reported SHA-256/size matched local staging, and all nine unauthenticated public downloads passed the same digest/size checks |
| Live feed bytes and Sparkle | Both public main feeds matched the signed XML; real arm64/x86_64 production-key probes found build 7 from build 6 and reported build 7 current, without a Sparkle download/install |
| Public npm installation | npm 12.2.1 installed the published package; CLI and home app report 0.4.0; both bundled media helpers are present |
| Primary installation | Existing app quit normally; the verified public installer upgraded `/Applications`, and the primary app launched as one instance. Both installed copies report 0.4.0 / build 7 and pass deep strict codesign; the saved Russian interface preference remained selected |

The real-file matrix exposed a GIF-to-WebM failure because FFmpeg selected an experimental RGB/alpha VP9 pixel format. Explicit YUV 4:2:0 fixed it; the original round-trip assertion remains. The playback guard initially included chapter text tracks and skipped the metadata fixture. It now checks only audio/video playback state, and the final suites ran that fixture without skips. A cross-compiled test bundle rejected by an arm64 loader was not counted as an Intel test run; the recorded Intel result used the actual Rosetta XCTest process.

Final archive QA is a separate check through `scripts/verify-media-release.py`, outside the Swift unit-test build. It unpacks the distributable ZIPs and runs the actual signed apps, rather than launching developer tools or treating candidate names as proof of conversion. This establishes the private-container Sandbox path; it does not prove a physical Finder/Powerbox interaction. No new manual gates were performed.

FFmpeg and codec source archives are unmodified and their corresponding configurations/build recipe accompany the release. The seven upstream media license/notice files are copied exactly into each app. Helpers use inherited seekable file descriptors for user content; they have no network protocols or physical capture/output devices. The internal filter input is present for fixtures. The application and installer remain MIT.

Physical Finder/Powerbox/bookmark recovery, login approval, AirDrop/Terminal, haptics/VoiceOver, real Intel hardware, macOS 13, and a full interactive Sparkle installation remain unverified. Advanced FFmpeg outputs select the first video and optional first audio, dropping extra streams/subtitles/attachments and transparency. Uncommon codecs/DRM can fail; playback flags in containers macOS cannot read are not reconstructed. Intel libvpx uses portable C and may encode more slowly. The preview remains ad-hoc signed without Developer ID or notarization.

The final decoder audit also confirmed that this build has no AV1 software decoder. Native decoding, if available for the actual asset, depends on the Mac. This is explicit in the published English notes and the current conversion matrix. The v0.4.0 tag and its nine assets remain immutable; these publication results and the decoder clarification are maintained on develop. The installed upgrade used the verified npm installer, not a full interactive Sparkle installation.

## v0.3.0 — Settings and output profiles

Fresh checks on October 27, 2026, macOS 26.6.2 on Apple Silicon:

| Check | Recorded result |
| --- | --- |
| Native arm64 Swift tests | 61 passed, 0 failed, 0 skipped: 37 Core and 24 App tests |
| Intel XCTest under Rosetta | 61 passed, 0 failed, 0 skipped from the separately built x86_64 test bundle |
| Native Settings renders | 64 PNGs: every tab/language/appearance plus seven additional format editors in both appearances; representative layouts reviewed independently |
| Localization | 168 matching keys parsed in each of five tables; unit placeholder/fallback/label checks passed |
| Profiles and shortcuts | Isolated preference persistence/reset, immutable snapshots, legacy swap migration, duplicate assignment swaps, full chords, Caps Lock/Fn handling, and Escape suppression passed |
| Wheel material/feedback | Backdrop does not intercept hits, selected petal is excluded from its mask, Solid hides it, and repeated same-sector updates emit no extra feedback |
| Encoder fixtures | Actual quality/metadata/orientation/color, 300-DPI pages, PCM depths and exact Int32 low bits, Float64 rejection, AAC bitrate, portrait video caps, archive compression, EPUB versions, and no-publication on invalid layouts passed |
| Developer encoders | Optional FFmpeg/FFprobe fixtures actually ran and passed, including GIF sizing/rate and global/stream/chapter metadata removal; these are not packaged app capabilities |
| Node installer tests | 16 passed, 0 failed, 0 skipped, including 0.2.1-to-0.3.0 upgrade and newer-version preservation |
| Signed release apps | Both architecture builds passed plist/lipo and deep strict codesign checks |
| Signed Sandbox self-checks | Both architectures passed the existing conversion/ZIP checks plus a real metadata-off image profile and maximum ZIP compression in private temporary directories |
| Update signing | Both final archive signatures independently verified; both appcasts signed and verified with build 6 / version 0.3.0 |
| Final artifacts | Both final ZIPs installed into temporary homes; native version 0.3.0 and codesign passed; manifest hashes, build/feed/key, license copies, and all five resource tables matched the archives |
| npm package | Prepack passed against final hashes; 7 files, no dependencies; final artifact checksums recorded in Release-checksums-0.3.0.txt |
| Public release | English preview published with all eight assets; GitHub-reported sizes and SHA-256 digests matched the reviewed local files |
| Live feed bytes | Both public HTTPS feeds matched the final signed XML byte for byte |
| Live Sparkle checks | Real arm64/x86_64 production-key probes: build 5 found build 6 available, and build 6 reported current; no update archive was downloaded or installed by the probes |
| Public npm installation | npm 12.2.1 installed the published package; CLI and home app report 0.3.0, and the home app passed deep strict codesign |
| Primary application | The primary copy was not running; the verified installer upgraded `/Applications`, then the app launched and remained running as one instance. Both installed copies report 0.3.0 / build 6, pass deep strict codesign, and the saved Russian language remained selected |

The first targeted Settings suite passed 6/6. A later full native run passed 59/60 and exposed a real native-video metadata leak: assigning an empty export metadata array still retained the source title. A fresh media-only composition fixed that path; the unchanged assertion was strengthened for unresized MOV as well as resized MP4. The targeted regression then passed, followed by both complete 60/60 suites before the final playback-state audit. Assertions were not weakened.

A final independent audit found that rebuilt tracks could become enabled, and that copied volume tags alone did not preserve mute during export. Tracks now retain their enabled state, and every native-video audio track gets an explicit validated mix in both metadata modes. A genuine disabled-video/hidden-commentary fixture checks mute and half gain, including nonempty audible output; its PCM decoder validates little-endian Float32 rather than misreading big-endian samples. The strict audibility assertions passed, followed by both final 61/61 suites.

Independent QA also found and fixed Int32 precision loss through Float32 processing and incomplete developer FFmpeg metadata removal. Regression fixtures compare actual nonzero low-bit PCM samples and tagged global/stream/chapter output. UI review corrected clipped search placeholders, inherited XCTest version text, About icon corners, duplicate login errors, and status refresh after returning from System Settings. General scrolling and inactive native-control coloring are intentional; the development preview does not establish active-window Glass compositing or VoiceOver behavior.

The five Tangerine pages were observed separately through REA; [Tangerine-settings.md](Tangerine-settings.md) preserves evidence IDs and unknowns. No original preference values, grants, artwork, sounds, pseudocode, binaries, or source were imported. [Settings.md](Settings.md) explains Yuzu's own numeric mappings and route-dependent limits. Physical Finder/Powerbox/bookmark recovery, ancestor child-scope derivation, login-item approval, real terminal/AirDrop use, haptics/VoiceOver, Intel hardware, macOS 13, and a full interactive Sparkle install/relaunch remain unverified. The preview remains ad-hoc signed without notarization.

The installed upgrade used the public npm installer and its normal verification/staging path, not an interactive Sparkle installation. The v0.3.0 release tag and its assets remain unchanged; this later publication record is maintained on develop.

## v0.2.1 — Yuzu wheel appearance

At the owner's explicit request, the old Yuzu Mac App wheel was read only as a design reference and its appearance was applied to the current AppKit implementation. [Wheel-design.md](Wheel-design.md) records dimensions, colors, typography, motion, and native rendered previews. No old engines, settings, source modules, history, or caches were imported.

Fresh checks on October 27, 2026, macOS 26.6.2 on Apple Silicon:

| Check | Recorded result |
| --- | --- |
| Native arm64 Swift tests | 36 passed, 0 failed, 0 skipped: 22 Core and 14 App tests |
| Intel XCTest under Rosetta | 36 passed, 0 failed, 0 skipped after a separate x86_64 build |
| Wheel geometry and state | Rounded visible/hit paths, gaps/corners, top-first labels, white selection, and shrinking the option list while hovering passed |
| Native previews | Conversion and Actions rendered in both light/dark appearances; all four PNGs were visually reviewed |
| Localization | 62 matching keys and compatible placeholders in all five languages |
| Node installer tests | 16 passed, including upgrade from 0.2.0 and preservation of newer app versions |
| Signed release apps | Both ZIPs passed plist, architecture, and deep strict codesign checks; both signed Sandbox self-checks passed |
| Final ZIP installation | Both archives installed into temporary homes; native version 0.2.1 and codesign passed |
| Update signing | Both archives independently verified against the embedded public key; both appcasts signed and verified, using build 5 / short version 0.2.1 |
| npm package | Prepack accepted final ZIP hashes; 7 files, no npm dependencies |
| Published release | English notes matched the reviewed file; all eight GitHub-reported asset digests matched local artifacts, and both live feeds matched the signed XML byte for byte |
| Live update checks | Real arm64/x86_64 Sparkle probes accepted the production feeds/key: build 4 found build 5 available; build 5 reported current on both architectures. These probes did not download or install updates |
| Public installation | npm 12.2.1 upgraded the published launcher/home app to 0.2.1; the same verified installer upgraded `/Applications`. CLI/native versions are 0.2.1 and both installed apps passed deep strict codesign |
| Active application | The old installed instance quit gracefully; `/Applications/Yuzu Converter.app` was launched with the new design. The saved Russian language remained selected |

The first targeted wheel run passed 7/7. A later full native run passed 35 tests but failed the WindowServer gate while the hit belonged to `loginwindow`; a separate layered/non-layered control probe saw the same owner. After the owner confirmed the Mac was unlocked, both complete suites passed 36/36. The assertion and product input handling were not weakened to bypass this environment condition.

Independent read-only review found no blocker in geometry, selection reset, input validation, generation checks, access scopes, or jobs, and reviewed all four previews. Final checksums are in [Release-checksums-0.2.1.txt](Release-checksums-0.2.1.txt). The installed upgrade used the npm installer, not a full interactive Sparkle cycle. Physical Finder drag, VoiceOver, Powerbox recovery, external services, a full interactive Sparkle install/relaunch, Intel hardware, and macOS 13 remain unverified. The preview is ad-hoc signed without Apple notarization.

## v0.2.0 — in-app updates

Fresh local checks on October 27, 2026, macOS 26.6.2 on Apple Silicon:

| Check | Recorded result |
| --- | --- |
| Native arm64 Swift tests | 34 passed, 0 failed, 0 skipped: 22 Core and 12 App tests |
| Intel XCTest under Rosetta | 34 passed, 0 failed, 0 skipped after a separate x86_64 build |
| Updater lifecycle | Tests verify queue deferral, one-time resumption, cancellation cleanup, and the actual optional Sparkle delegate selectors |
| Node installer tests | 16 passed, including approved framework symlinks, rejection of unsafe paths/links, 0.1.2-to-0.2.0 upgrade, and preservation of newer in-app updates |
| Localization | All five tables have 60 matching keys and compatible placeholders; compact wheel captions still fit |
| Release apps | Both architecture ZIPs passed Info.plist/lipo and deep strict codesign, including the Sparkle framework and nested helpers |
| Signed Sandbox self-checks | Both apps loaded Sparkle and all five languages, then passed the existing conversion/ZIP self-checks |
| Final ZIP installation | Both archives installed into temporary homes; native version 0.2.0 and codesign passed |
| npm package | Prepack passed with final pinned ZIP hashes; 7 files, no npm dependencies |
| Sparkle HTTP fixtures | Real probing checks reached the local HTTP server: available update, current version, tampered-feed rejection, and HTTP 500 handling all passed with an isolated ephemeral test key |
| Production signatures | Sparkle signed and verified both feeds; Node independently verified both feed and archive Ed25519 signatures against the public key embedded in Info.plist, and both archive SHA-256 values matched the npm manifest |
| Published release | The English body matched the reviewed notes; all eight GitHub-reported asset digests matched local artifacts |
| Live feed bytes | Both public HTTPS feeds matched the signed local XML byte for byte |
| Live Sparkle checks | Real arm64 and x86_64 Sparkle probes accepted the production feeds/public key: build 3 found build 4 available, and build 4 reported current on both architectures; no update was downloaded or installed by these probes |
| Public npm upgrade | npm 12.2.1 installed the published 0.2.0 package; the CLI and native app report 0.2.0 |
| Installed application upgrade | Both `~/Applications` and `/Applications` were updated from the public release; deep strict codesign and executable versions passed for both. The `/Applications` copy was launched and its process stayed running; the saved Russian language remained selected |

Independent source review covered the shared controller, optional delegate contracts, abort recovery, busy queue/restart handling, Sandbox configuration, signing order, archive aliases, and prevention of npm downgrades. Reported issues were fixed before final builds/tests.

Production signing completed after the initial background Keychain access wait. The private release signing key stayed in the login Keychain, not Git or release assets; HTTP fixtures used a separate temporary key and did not install anything. The installed upgrade used the verified npm installer, not an interactive Sparkle installation. Full interactive updater installation/relaunch, Finder/Powerbox, VoiceOver, AirDrop/Terminal, shelf drag-out, Intel hardware, and macOS 13 remain unverified. This remains an ad-hoc-signed preview without Apple notarization.

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
| Published release | English notes matched the reviewed file; GitHub-reported SHA-256 digests of all six assets matched local artifacts |
| Public npm upgrade | npm 12.2.1 upgraded 0.1.1 to 0.1.2; installed CLI and native executable report 0.1.2 |
| Active application upgrade | The old `/Applications` instance quit gracefully; the existing verified installer updated that location from the public release with rollback staging, and the new app was launched |
| Installed application verification | `/Applications` and `~/Applications` native binaries matched the final arm64 build; both report 0.1.2, and strict codesign passed for the active application |

Independent source/test review found no blocker; the shared arming path covers both wheel modes and retains file URL validation. Final hashes are in [Release-checksums-0.1.2.txt](Release-checksums-0.1.2.txt). Installation retained the app's existing language/settings container; no global npm or macOS security policy changed. Physical Finder drag, Powerbox/bookmark recovery, VoiceOver, AirDrop, Terminal, shelf drag-out, Intel hardware, and macOS 13 remain unverified. The app is still an ad-hoc-signed preview without Apple notarization.

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
