# Release validation record

Updated October 29, 2026. Results are version-specific. Translating the app and documentation does not turn historical checks into fresh runs.

## v0.7.1 — Startup checks and the automatic-checking checkbox

Local feature verification on October 29, 2026: **133 Swift tests**, **24 Node tests**, and **9 Python cache tests** passed without skips in the separate `.build/startup071-tests` scratch path. Both new updater tests cover packaged default/consent flags and the development-bundle startup guard. Five-language/light-dark Settings renders include the new About checkbox; English light and Russian dark renders were inspected. These are development previews, not physical Sandbox/other-Mac checks.

The arm64 feature signed own-container archive passed. Seventeen real signed-feed HTTP scenarios also passed in isolated fixture processes: four information-only checks and thirteen background/manual/preference/choice cases. They cover current/offline/tampered silence, repeated dismiss, disable persistence, manual checking while disabled, re-enable persistence, skipped-version suppression and manual recovery. The noninteractive driver rejects unexpected popups/downloads and only replies Dismiss/Skip; the HTTP server confirms no archive URL is requested. Temporary bundle identities and ephemeral test keys isolate the owner's app and release Keychain. Native arm64/Intel CI and final release evidence follow separately.

Physical startup-dialog interaction, actual download/installation/relaunch, macOS 13, VoiceOver, and other-Mac checks remain deferred/unverified. Release work never installs/restarts either owner app copy or global npm.

[Feature PR #37](https://github.com/StPashik/Yuzu-converter/pull/37) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40944698338) on the final feature commit. Both arm64 and native Intel ran 133 Swift tests, 24 Node tests, signed own-container Sandbox archives, and all 17 signed HTTP scenarios (four information checks plus thirteen startup/preference/choice cases), without skips or update downloads.

| Final 0.7.1 / build 17 preparation | Recorded result |
| --- | --- |
| Archives | Both final ZIPs passed deep strict codesign, exact main/helper CPU slices, versions/resources/icons/notices, and signed own-container media/document/retry/move checks |
| Compatibility | SDK 26+, minimum macOS 13, weak native-glass class imports on both main executables; local x64 execution uses Rosetta independently of native Intel CI |
| Update behavior | All 17 real signed-feed HTTP scenarios passed against each final architecture fixture; saved checkbox choices, background silence, dismiss/skip/manual recovery, and no unauthorized archive request verified |
| npm | Local ci with scripts disabled and 24 final Node tests passed; seven exact package files; both actual ZIPs installed/version/CPU/codesign-checked only in temporary homes, without UI launch |
| Source/licenses | 24 corresponding-source/configuration files, four pinned upstream archives, both helper hashes/configurations, seven exact upstream media notices, and exact bundled Sparkle artifact licenses verified |
| Signatures/notes | Both archive signatures independently verified with the embedded production key; exact reviewed English Markdown in both signed feeds; automatic checking enabled while automatic download/installation remains disallowed |
| Frozen assets | Nine files; eight payload hashes in [Release-checksums-0.7.1.txt](Release-checksums-0.7.1.txt); legacy feeds held until asset publication |

[Release PR #38](https://github.com/StPashik/Yuzu-converter/pull/38) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40947344569): each CPU ran 133 Swift tests, 24 Node tests, signed Sandbox archives, and all 17 real signed HTTP scenarios without skips or unauthorized downloads. Tag `v0.7.1` points to exact main merge `b53447376e8549f866446f1a9d08b7d3189c1de2`, whose tree matches the verified release head.

The draft's exact English notes and all nine uploaded sizes/digests matched the frozen files before stable Latest publication. All nine public unauthenticated versioned downloads matched SHA-256. Both normal Latest feed URLs returned the exact signed Markdown XML. Twelve production-key Sparkle information checks passed across arm64/x64: simulated builds 7, 13, 14, 15, and 16 find build 17 and its notes; build 17 reports current. These probes did not download or install an update.

Both legacy bridges are exact copies of those public signed feeds, prepared only after compatible assets became public. Their publication uses a separate PR without regenerating signatures/URLs or changing the application-release tag. Checking can now be automatic, but installation remains the owner's choice.

[Legacy publication PR #39](https://github.com/StPashik/Yuzu-converter/pull/39) passed its [metadata-only CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40949888322); native jobs were correctly skipped for its exact two-feed/validation scope. Both ordinary `main/updates` URLs return byte-for-byte public signed 0.7.1 feeds. Twelve additional production-key Sparkle information checks passed across both CPUs and simulated builds 7, 13, 14, 15, 16, and 17. Combined with Latest checks, all 24 offer/current-version/Markdown checks passed without downloading or installing an update.

The publication audit confirmed all 16 prior release records/assets and 32 prior annotated/peeled tag refs remain unchanged. The application tag still points to the original main release merge; the legacy merge is separate. Both main merge commits are retained when the release branch returns to develop.

## v0.7.0 — Document fidelity, local OCR, and video tracks

**131 Swift tests**, **24 Node tests**, and **9 Python cache tests** passed locally without skips. Local feature checks use the separate `.build/feature070-tests` scratch path and private temporary files with bundled media required. The styled XLSX fixture's rendered PDF was visually inspected: merged blue header, white bold title, source borders, date, currency, and percentage values. The new suite also covers row/column style defaults, both Excel date systems, large decimal precision, malformed overlapping merges, oversized merged-row/column-band pagination, five-language OCR, mixed text/scan PDFs, multipage oriented TIFF, blank/cancelled OCR, exact Save As, real multitrack media, subtitle text, languages, chapters, metadata removal, ASS styling warnings, default/forced flag comparisons, and retained queue warnings.

The feature arm64 signed own-container Sandbox archive passed local OCR and multitrack audio/subtitle/chapter checks. This fixture is not a published 0.7.0 artifact. Physical Finder/browser/Powerbox/Sandbox interoperability, VoiceOver, macOS 13, other-Mac appearance, bitmap subtitle content, hardware-dependent AV1 samples, and cross-volume devices remain deferred/unverified. Owner app copies and global npm are not test targets. Full native CI and final release evidence will be recorded below.

[Feature PR #33](https://github.com/StPashik/Yuzu-converter/pull/33) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40900479845) on the exact final feature commit. Both arm64 and native Intel ran 131 Swift tests and 24 Node tests without skips, verified their pinned media caches, and passed their signed own-container Sandbox archives, including local OCR and separate audio/subtitle/chapter exports. Bitmap subtitle content, AV1 hardware samples, and physical OS/application/device interactions remain unverified.

| Final 0.7.0 / build 16 preparation | Recorded result |
| --- | --- |
| Archives | Both final ZIPs passed deep strict codesign, exact main/helper CPU slices, versions/resources/icons/notices, and signed own-container OCR/media/document/retry/move checks |
| Compatibility | SDK 26+, minimum macOS 13, weak native-glass class imports on both final executables; local x64 execution used Rosetta, separately from native Intel CI |
| npm | Local npm ci with scripts disabled and 24 final Node tests passed; seven exact package files; both actual ZIPs installed/version/CPU/codesign-checked only in temporary homes, without UI launch |
| Source/licenses | 24 corresponding-source/configuration files, four pinned upstream archives, both helper hashes/portable configurations, seven exact upstream media notices, and exact bundled Sparkle artifact licenses verified |
| Updates | Both archive signatures independently verified with the embedded production key; exact reviewed English Markdown in both signed feeds; real HTTP Sparkle available/current/tampered/500 fixture passed without installation |
| Frozen assets | Nine files; eight payload SHA-256 values in [Release-checksums-0.7.0.txt](Release-checksums-0.7.0.txt); legacy feeds held until asset publication |

[Release PR #34](https://github.com/StPashik/Yuzu-converter/pull/34) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40914736167): each CPU ran 131 Swift tests and 24 Node tests without skips, plus its signed Sandbox OCR/multitrack archive. Tag `v0.7.0` points to the exact main merge `45582cf218a5026035fe7d8c84ae49f0b2a7400c`, whose tree matches the verified release head.

The draft's exact English notes and all nine uploaded sizes/digests matched the frozen files before stable Latest publication. All nine public unauthenticated versioned downloads matched SHA-256. Both ordinary Latest feed URLs returned the exact signed Markdown XML. Ten production-key Sparkle information checks passed across arm64/x64: simulated builds 7, 13, 14, and 15 find build 16 and its notes; build 16 reports current. No update was downloaded or installed by these probes.

Both legacy bridges are exact copies of those public signed feeds, prepared only after their compatible assets became public, without regenerating signatures or URLs. Their publication uses a separate PR; the application-release tag stays unchanged. The owner installs personally through Check for Updates.

[Legacy publication PR #35](https://github.com/StPashik/Yuzu-converter/pull/35) passed its [metadata-only CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40917430983); native jobs were correctly skipped for its exact two-feed/validation scope. Both ordinary `main/updates` URLs return byte-for-byte public signed 0.7.0 feeds. Ten additional production-key Sparkle information checks passed on these legacy URLs across both CPUs and simulated builds 7, 13, 14, 15, and 16. Combined with Latest checks, all 20 offers/current-version/Markdown checks passed without downloading or installing an update.

A publication audit confirmed all 15 prior release records and their asset metadata, plus 30 prior annotated/peeled tag refs, remain unchanged. The release tag still points to the original main application merge; the later legacy bridge merge is separate. The release branch now includes both main merge commits before returning to develop.

## v0.6.3 — Retry remaining inputs and repair shelf references

Local Apple Silicon checks on October 29, 2026: **120 Swift tests**, **24 Node tests**, and **9 Python cache tests** passed without skips, with bundled media required. Tests use the separate `.build/patch063-tests` scratch path and private temporary files. New five-language/light-dark Operations and missing-reference shelf renders were inspected; images use the opaque accessibility fallback.

The new only-error-window test first failed: Retry removed the row before appending it, publishing an intermediate empty list that closed Operations. The fix reorders a local list and assigns one complete snapshot. The full 120-test pass includes that regression, FIFO/options retention, actual per-file destination retry without duplicate outputs, failed grant retention/clear, partial permission-failed Move, hidden shelves/children, queued/failed requests following known moves, collision naming, directory URL variants, visible deletion polling/reopen, and localized recovery families.

Image fixtures verify a retained prepared promise is consumed only once, retry/clear cleanup, unavailable promise replay rejection, and an actual transient HTTP 503 followed by successful Retry. Public-copy cleanup failure is simulated at the executor boundary: the published copy is preserved, its input is not retried, and no source deletion is attempted. Core move fixtures separately exercise actual rename/no-op/copy callbacks, normalized directories, collisions and symlink-target exclusions.

[Retry and reference recovery](Retry-and-references.md) records behavior and limits. Physical Finder/browser/Powerbox/Sandbox interoperability, VoiceOver, macOS 13, other-Mac appearance, and cross-volume devices remain deferred/unverified. Signed own-container archive/native CI evidence will be recorded separately. Installed owner app copies are not test targets.

[Feature PR #29](https://github.com/StPashik/Yuzu-converter/pull/29) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40882383387) on arm64 and native Intel. Each ran 120 Swift tests and 24 Node tests without skips, restored verified media tools, and passed its signed own-container Sandbox archive, including the new retry/completed-move self-check.

| Final 0.6.3 / build 15 preparation | Recorded result |
| --- | --- |
| Archives | Both final ZIPs passed deep strict codesign, exact main/helper CPU slices, versions/resources/icons/notices, and signed own-container document/media/batch/exclusive-save/retry/move checks |
| Compatibility | SDK 26+, minimum macOS 13, weak native-glass class imports on both final main executables; local x64 execution used Rosetta, independently of native Intel CI |
| npm | Local npm ci with scripts disabled and 24 final Node tests passed; seven exact package files; both actual ZIPs installed/version/CPU/codesign-checked only in temporary homes |
| Source/licenses | 24 corresponding-source/configuration files, four pinned upstream archives, both helper hashes/portable configurations, seven exact upstream media notices, and exact pinned Sparkle license verified |
| Updates | Both archive signatures independently verified with the embedded production key; exact reviewed English Markdown in both signed feeds; HTTP Sparkle available/current/tampered/500 fixture passed without installation |
| Frozen assets | Nine files; eight payload SHA-256 values in [Release-checksums-0.6.3.txt](Release-checksums-0.6.3.txt); legacy feeds have not advanced |

[Release PR #30](https://github.com/StPashik/Yuzu-converter/pull/30) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40885923000): each CPU ran 120 Swift tests and 24 Node tests without skips, plus its signed Sandbox archive including retry/completed-move checks. Tag `v0.6.3` points to the exact main merge `227d950d46ac3029c44d2af29a92f46fb14d18e8`, whose tree matches the verified release head.

The draft's English notes and nine uploaded sizes/digests matched the frozen files before stable Latest publication. All nine public unauthenticated versioned downloads matched SHA-256. Both normal Latest feed URLs returned the exact signed Markdown XML. Eight real production-key Sparkle information checks passed across arm64/x64: builds 7, 13, and 14 find build 15 and its Markdown notes; build 15 reports current. No update was downloaded or installed by these probes.

Both legacy bridges are copied from those exact public signed feeds after their compatible assets are public, without regenerating signatures or URLs. The original application-release tag remains unchanged. The owner installs personally; installed app copies are not release test targets.

[Legacy feed PR #31](https://github.com/StPashik/Yuzu-converter/pull/31) passed [metadata/feed CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40888163558): nine Python tests, six Node release tests, and both signed-feed checks. Native matrix expansion was correctly skipped for only documentation/feed changes. Both normal raw main/updates URLs returned the exact signed public XML. Eight further production-key Sparkle checks passed for the same old/current builds and Markdown notes across both CPUs, for **16 information-only production checks** in total. No owner installation or restart was performed.

The history audit preserved all 14 earlier release records, their asset IDs/digests/sizes, and all 14 earlier tag objects. The release branch carries main's application-release and legacy-publication merge history into the GitFlow merge-back. New physical/other-device checks remain explicitly unverified.

## v0.6.2 — Drag workflow, compact operations, and table PDFs

Local Apple Silicon checks on October 29, 2026: **103 Swift tests**, **24 Node tests**, and **9 Python cache tests** passed without skips, with bundled media required. Final review additionally exercises optional/zero XLSX sizing hints. Tests run in project-specific scratch paths; installed owner app copies are not test targets.

The wheel fixtures cover hidden empty conversions with an Actions mode switch, cached visible/hit geometry, and asynchronous cold/rapid sound playback. PDF batch tests verify page order/colors, one publication, cancellation/failure cleanup, source preservation, and collision naming. Spreadsheet tests exercise grid pixels, widths, wrapping, cached/uncached formulas, every sheet, multi-page output, empty sheets, and bounded sparse layouts. Table PDF export remains a readable uniform grid, not full Excel layout or calculation fidelity.

Virtual-image fixtures cover lazy pasteboard reads, a screenshot-style file/promise combination, a controlled file-promise receiver, temporary-file lifetime, containment/symlink rejection, and bounded loopback HTTP success/failure/cancellation. The exact-path save refuses replacement. A mocked provider/own-container test does not establish real browser or external Powerbox interoperability; see [Virtual image drops](Virtual-image-drops.md).

Operations renders were visually reviewed after adding a real 20-point AppKit inset. Automated previews cover five languages in both appearances; assertions verify the hosting frame and compact window dimensions. Success rows expire after one second and an emptied window closes; errors/cancellations remain. No determinate bar is shown for operations without universal measurable progress.

The owner reported that PDF rasterization and wheel sound in 0.6.1 work. This is owner feedback about that version, separate from the new background playback path. Physical Finder/browser/screenshot drags, audible/haptic timing, external-file Sandbox/Save-panel grants, native-glass composition, VoiceOver, macOS 13, and macOS 26 Intel appearance remain deferred/unverified. Signed own-container archive checks and required native CI results are recorded separately when completed.

[Feature PR #25](https://github.com/StPashik/Yuzu-converter/pull/25) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40863375606) on arm64 and native Intel. Each ran 103 Swift tests and 24 Node tests without skips, restored verified media tools, and passed the signed own-container Sandbox archive, including batch PDF, exact-file exclusive save, table PDF, and media checks.

| Final 0.6.2 / build 14 preparation | Recorded result |
| --- | --- |
| Archives | Both final ZIPs passed deep strict codesign, exact main/helper CPU slices, versions, resources, icons/notices, and signed own-container Sandbox document/table/batch/exclusive-save/media checks |
| Compatibility | SDK 26+, minimum macOS 13, weak native-glass class imports on both final main executables; local x64 execution used Rosetta, independently of native Intel CI |
| npm | Local npm ci with scripts disabled passed; 24 final Node tests without skips; seven exact package files and actual archive installs/version/CPU/codesign checks only in temporary homes |
| Media source/licenses | 24 corresponding-source/configuration files, four pinned upstream archives, both helper hashes/configuration records, seven exact upstream media notices, and exact pinned Sparkle license verified |
| Updates | Both final archives independently verified against the embedded production key; both signed feeds include the exact English Markdown notes; real HTTP Sparkle available/current/tampered/HTTP-500 fixture passed without installation |
| Frozen publication set | Nine files; eight payload SHA-256 values in [Release-checksums-0.6.2.txt](Release-checksums-0.6.2.txt); legacy feeds have not advanced |

[Release PR #26](https://github.com/StPashik/Yuzu-converter/pull/26) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40864894298): each CPU ran 103 Swift tests, 24 Node tests without skips, and signed Sandbox archive checks. Tag `v0.6.2` points to its exact main merge commit `b80a7fd38b33db46b49f602ccd171b402ba2f786`, with a tree identical to the verified release head.

The reviewed draft's English notes and nine uploaded asset sizes/digests matched the frozen files before stable Latest publication. All nine unauthenticated versioned downloads matched SHA-256. Both normal Latest feed URLs returned the exact signed Markdown XML. Eight real production-key Sparkle information checks passed across arm64/x64: builds 7, 12, and 13 find build 14 and its Markdown notes; build 14 reports current. No update was downloaded or installed by these probes.

Both legacy bridges are copied from those exact public signed feeds after their compatible assets are public; no signatures or archive URLs are regenerated. The application-release tag remains unchanged. Installed owner app copies are not release test targets.

[Legacy feed PR #27](https://github.com/StPashik/Yuzu-converter/pull/27) passed [metadata/feed CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40866394899): nine Python tests, six Node release tests, and both signed-feed checks. Native matrix expansion was correctly skipped for only documentation/feed changes. Both normal raw main/updates URLs then returned the exact public signed XML. Eight further production-key Sparkle checks passed for the same old/current builds and Markdown notes across both CPUs, for **16 information-only production checks** in total. No owner installation or restart was performed.

A history audit preserved all 13 earlier release records, all their asset IDs/digests/sizes, and all 13 earlier tag objects. The release branch includes main's application-release and legacy-publication merge history for the GitFlow merge-back into develop. New physical/other-device gates remain explicitly unverified.

## v0.6.1 — Shelf, queue, PDF, and update-note polish

Local Apple Silicon checks on October 29, 2026: **90 Swift tests**, **24 Node tests**, and **9 Python cache tests** passed without skips, using the bundled media tools with `YUZU_MEDIA_REQUIRED=1`. Final PDF assertions also check the rotated blue corner and full-page black coverage. The HTTP Sparkle fixture verified available/current/tampered/HTTP-500 behavior and parsed the expected native Markdown notes, without downloading or installing an update.

The new pixel fixture reproduced the reported small-content/white-canvas symptom: `CGPDFPageGetDrawingTransform` centers and only scales down, leaving PDF points unscaled in the 300-DPI bitmap. The fix establishes the explicit points-to-pixels scale before page placement, and uses the visible crop intersected with the media bounds. JPG and PNG fixtures cover four rotations and nonzero crop origins. The owner's source PDF remains unavailable, so that exact file is unverified.

Shelf fixtures now check the absence of command menus, the folder button's position/accessibility, actual shelf URL callbacks into conversion and all seven wheel Action targets, a real queued conversion, and retained source batches after removal. Queue fixtures check normal window level, compact sizing, rounded layer clipping, success expiry, empty-window close, and retained failures. The wheel fixture checks four immediate distinct highlights, no replay inside one petal, and the disabled feedback setting.

Current previews show the real opaque fallback in both themes/five languages. Physical Finder/Powerbox drag sessions, Finder reveal, external-file Sandbox access, audible/haptic perception, native-glass corner composition, VoiceOver, macOS 13, and macOS 26 Intel appearance remain unverified. [Feature PR #21](https://github.com/StPashik/Yuzu-converter/pull/21) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40848737346) on arm64 and native Intel: each ran 90 Swift tests and 24 Node tests without skips, restored verified media tools, and verified its signed Sandbox archive. Final release-asset checks follow below. Installed owner app copies are not test targets.

| Final 0.6.1 / build 13 preparation | Recorded result |
| --- | --- |
| Archives | Separate final arm64/x64 ZIPs passed strict signatures, exact CPU slices, versions/resources/notices, and signed Sandbox document/spreadsheet/archive/media checks |
| Compatibility | Both main executables use SDK 26+, minimum OS 13, and weak native-glass imports; local x64 execution uses Rosetta, separate from native Intel CI |
| npm | 24 tests without skips; seven exact package files, executable CLI, and both actual archives installed/version/CPU/codesign-checked only in temporary homes |
| Media source/licenses | 24 exact source/configuration files, four pinned upstream archives, both helper records, seven exact upstream media notices; app Sparkle license matches its pinned artifact |
| Updates | Both archive signatures independently verified against the embedded production key; signed feeds contain the exact reviewed English Markdown; live bridges remain unchanged until assets are public |
| Frozen assets | Nine files; eight payload hashes in [Release-checksums-0.6.1.txt](Release-checksums-0.6.1.txt) |

[Release PR #22](https://github.com/StPashik/Yuzu-converter/pull/22) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40850867126): each architecture ran 90 Swift tests, 24 Node tests without skips, and the signed Sandbox archive checks. Tag `v0.6.1` points to its exact main merge commit `289e3d9220eb7c203043cdc9d5367395a72e063f`, with a tree identical to the verified release head.

The reviewed draft's English body and nine uploaded sizes/digests matched the frozen files before stable Latest publication. All nine public versioned downloads matched SHA-256. Both Latest feed URLs returned the exact signed Markdown XML. Eight real production-key Sparkle information checks passed across arm64/x64: builds 7, 11, and 12 find build 13 and its Markdown notes; build 13 reports current. No update was downloaded or installed by these probes. Both legacy bridges are copied from those exact public signed feeds, preserving the application-release tag.

[Legacy feed PR #23](https://github.com/StPashik/Yuzu-converter/pull/23) passed [metadata/feed CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40852795642), including nine Python and six Node release tests. Native jobs were correctly omitted for signed-feed/documentation-only changes. Both normal raw main/updates URLs then returned the exact signed release XML. Eight further production-key Sparkle checks passed with the same versions and Markdown assertions, for **16 information-only production checks** across both CPUs/channels in total. The v0.6.1 application tag remains unchanged.

A final history audit preserved 12 earlier release records, all their asset IDs/digests/sizes, and all 12 earlier tag objects. The release branch carries main's application-release and feed-publication merge history back to develop. The owner installs personally; no owner installation, quit, or relaunch was performed.

## v0.6.0 — Shelf commands, operations, and shared glass

Local checks on October 28, 2026, macOS 26.6.2 / Apple Silicon: **86 Swift tests**, **22 Node tests**, and **9 Python cache tests** passed, with no skips. Swift used the rebuilt bundled media tools with `YUZU_MEDIA_REQUIRED=1`. Both media architectures were rebuilt from the pinned source and final cache recipe. Verified local cache hits took 0.21 seconds (arm64) and 0.26 seconds (x64); these are local verification timings, not an end-to-end CI claim.

New fixtures check serial execution, waiting/running cancellation, grant lifetime, continuation after errors, real conversion without overwriting an existing result, preserved earlier outputs, normalized folder Move, partial Move publication, ZIP, and invalid destinations. Shelf commands check actual target intersection, all seven Actions, stale conversion-menu rejection, cross-batch leases after removal, and contextual row selection. Closing/material changes leave jobs intact. Layout previews cover five languages in both appearances and the opaque accessibility fallback; native glass is inspected structurally.

Reviewing the rendered queue exposed intrinsic host sizing and cached mixed-language labels; the host now fills a constrained scrollable panel and receives an explicit language snapshot. A new language-refresh assertion also reproduced shelf selection loss; reload now preserves selected URLs while suppressing transient selection notifications. The final 86-test pass includes those fixes. Previews are in [Shelf workflow](Shelf-workflow.md).

Cache tests reject recipe/toolchain/architecture changes, missing/corrupt files, malformed/extra-path receipts, symlinked tools, changed upstream archives, and runtime dependency/CPU failures. Portable configurations remain verifiable after the original temporary build directory is removed. [Feature PR #17](https://github.com/StPashik/Yuzu-converter/pull/17) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40748227346) on both CPUs: each ran 86 Swift tests, 22 Node tests without skips, and signed Sandbox archive/media verification. Cold media compilation took 338 seconds on arm64 and 503 seconds on native Intel. Final release-asset results follow.

| Final 0.6.0 / build 12 preparation | Recorded result |
| --- | --- |
| App archives | Separate arm64/x64 ZIPs; actual main/helper slices, strict signatures, Sandbox entitlements, system-only media dependencies, five localization tables/Automation explanations, icons, and notices verified |
| Native glass compatibility | Both actual main executables built with SDK 26+, minimum OS 13.0, and a weak native-glass class import |
| Signed Sandbox execution | Both extracted final archives passed spreadsheet/document/archive/ZIP and bundled media self-checks; local x64 execution used Rosetta, independently of required native Intel CI |
| Update signatures | Both final archives independently verified with Node Ed25519 against the embedded Yuzu public key; both appcasts signed and verified with the existing project Keychain account |
| Real Sparkle fixture | Local HTTP available/current/tampered/HTTP-500 checks passed with temporary identities/test keys; no installation |
| npm | 22 tests passed without skips after manifest generation; seven exact tarball files and executable CLI verified; both actual ZIPs installed/codesign/version-checked only in temporary homes |
| Corresponding media source | 24 files: exact recipes/manifest/guide, four SHA-pinned archives, both architectures' seven portable configurations and binary-info records verified |
| Licenses | All seven media license/notice copies matched their exact pinned upstream archive bytes |
| Frozen publication set | Nine assets, eight payload SHA-256 values in [Release-checksums-0.6.0.txt](Release-checksums-0.6.0.txt); historical releases/tags/assets are not replaced |

[Release PR #18](https://github.com/StPashik/Yuzu-converter/pull/18) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40751460121) on both CPUs, again with 86 Swift tests, 22 Node tests without skips, and signed Sandbox archive/media verification. Tag `v0.6.0` points to its exact main merge commit, `c58d5f4058c3413e70d8d7b7c0482b8b53461bf1`, whose tree matches the verified release head.

The draft's nine asset sizes/digests and English body matched the prepared files before stable Latest publication. All nine public unauthenticated versioned downloads then matched final SHA-256 values. Both normal Latest feed URLs returned the exact signed XML. Real production-key Sparkle checks passed for arm64/x64: builds 7, 10, and 11 see build 12; build 12 reports current. These eight checks used temporary identities and performed no installation. Legacy bridge files are copied from those exact public signed bytes through their own publication PR.

[Legacy publication PR #19](https://github.com/StPashik/Yuzu-converter/pull/19) passed [metadata/feed CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40755823168): nine Python checks and four Node signed-feed tests passed, with native jobs correctly omitted for feed/documentation-only changes. Both normal raw main/updates URLs then returned the exact public XML. Eight further real Sparkle checks passed across the same old/current build numbers and both CPUs, using temporary identities without installation. The application-release tag remains unchanged.

The reviewed main [cold cache workflow](https://github.com/StPashik/Yuzu-converter/actions/runs/40755439163) built and saved both media entries successfully. The next [main workflow](https://github.com/StPashik/Yuzu-converter/actions/runs/40755952247) restored both and logged `Verified media cache hit` for arm64 and x64, with receipt/source/CPU/runtime validation retained. This verifies real GitHub cache reuse; native application test/archive gates remain independent. Corrupt source archives fail closed on their pinned SHA and require removal before retrying, as clarified in [CI.md](CI.md).

Physical Finder/Powerbox, real Clipboard/AirDrop/Terminal, external-file Sandbox Quick Look, VoiceOver, macOS 13, and macOS 26 Intel appearance remain unverified. Source rows may become stale after Move. Session-only history/references and cooperative filesystem cancellation are documented limits. Developer ID/notarization are still absent. The owner's installed copies are not release test targets.

## v0.5.1 — Shelf retention and a configurable Finder shortcut

The owner requested retention when closing/reopening shelf windows within the running app, without persistence after exiting Yuzu. The new ActionController regression failed eight assertions against 0.5.0 behavior, demonstrating both collection clearing and removal of hidden controllers. The retention fix first passed all 71 local Swift tests with required bundled media; the previous feature head also passed both native CI jobs. The subsequent shortcut work requires its own final-head CI below.

Five shelf tests now include the actual close button, Escape, Show Shelf, same-window reopening, a retained source lease, appending to a hidden shelf, independent shelves in new-shelf mode, and original-byte preservation. Existing geometry, material, selection-contrast, drag/drop, and 18 shelf layout-snapshot checks remain.

The final local run passed **78 Swift tests**, with required bundled-media fixtures, and **22 Node tests** without skips. The owner selected **Control+C**; it is tested as the default and shown in regenerated previews. The new shortcut checks exercise native exclusive registration and release, conflicting replacements without losing previous registrations/preferences, recording/cancel/disable, invalid or unsafe chords, persisted disable and corrupt preferences, strict Finder file-descriptor parsing including real aliases and Unicode paths, readable source preservation, and all five Automation explanation resources. The descriptor regression caught Foundation coercing arbitrary text into a file URL; parsing now rejects text before coercion. Real alias tests compare canonical paths because macOS resolves `/var` to `/private/var`. Settings previews also scroll to the new control in every language and both appearances.

The scope-ownership regression failed two assertions before the fix: already-readable inputs had no independently owned parent scopes. With Sandbox policy explicitly enabled in the fixture, each batch now starts its own real Foundation bookmark scope and deduplicates parents within the batch. This runs without Finder or Powerbox and does not establish physical Sandbox grant recovery. A separate native registration regression failed two assertions before re-recording an inactive saved chord was checked for conflicts. Both fixes are included in the final 78-test pass. The shipped fixed Finder query also compiled with the system AppleScript compiler without being executed.

[Feature PR #13](https://github.com/StPashik/Yuzu-converter/pull/13) merged into develop after [final-head native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40729337089): each CPU passed 78 Swift tests, 22 Node tests without skips, and the signed Sandbox archive. Local optimized builds also passed for both architectures using Xcode 26 in separate scratch paths. A system AppleScript fixture returned the real `alis` descriptor expected by the parser, using only a probe-owned temporary file and no Finder request.

| Release preparation | Recorded result |
| --- | --- |
| Metadata | Package, lockfile, both final executables/plists agree on 0.5.1 / build 11; separate arm64 and x64 archives |
| Final ZIPs | Deep strict signatures, exact main/helper CPU slices, macOS 13 minimum, SDK 26+, and weak native-glass class imports passed |
| Permissions/resources | Finder-only Apple-event exception, Automation capability, five permission explanation tables, UI strings, media manifests/licenses, unchanged icons, and notices match the reviewed source |
| Signed Sandbox | Both final extracted apps passed bundled media/probe/decode/return conversion, image metadata, documents, spreadsheets, archives, and Compress to ZIP with external tools disabled |
| npm/source | All seven npm files match source and pinned ZIP hashes; launcher mode/shebang verified; all four upstream source hashes, recipe/manifest/guide, and both actual CPU configurations match the 23-file corresponding-source archive |
| Temporary installation | Both final ZIPs installed only into temporary homes, passed signature/version checks, and were removed |
| Update signing | Both archive signatures independently verified against the production public key; both build-11 appcasts signed and verified using the existing project Keychain account; live legacy feeds remain unchanged |
| HTTP fixtures | Real Sparkle available/current/tampered/HTTP-500 requests passed with an ephemeral key and isolated app identity; no update installation |
| Staging | Nine final files; eight payload SHA-256 values rechecked and recorded in [Release-checksums-0.5.1.txt](Release-checksums-0.5.1.txt) |
| Signing limitation | Actual code signatures are ad hoc without a Team ID; Developer ID and Apple notarization remain absent |
| Release PR/tag | [PR #14](https://github.com/StPashik/Yuzu-converter/pull/14) passed [native release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40733121773); v0.5.1 tags its exact main merge commit `edd9765f78d8732070d20ad7b484c62675693b74`, whose tree matches the verified release head |
| Release CI | Each native CPU passed 78 Swift tests, 22 Node tests without skips, and the actual 0.5.1 signed Sandbox archive |
| Public release | Stable Latest v0.5.1, draft=false/prerelease=false; exact English notes and all nine uploaded asset sizes/digests matched staging, then all nine unauthenticated public downloads passed size/SHA-256 verification |
| Latest feeds/Sparkle | Both normal Latest XML URLs matched the signed release assets exactly; real production-key checks found build 11 from builds 7/9/10 and reported build 11 current on both CPUs without installing |
| Historical preservation | All ten prior release bodies/statuses, asset IDs/digests/sizes/dates, and existing remote tag objects/dereferenced commits remained unchanged |
| Legacy feeds/Sparkle | [PR #15](https://github.com/StPashik/Yuzu-converter/pull/15) passed [feed-only CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40738168128) and merged; both normal main/updates URLs then matched the public signed XML exactly, and real production-key checks found build 11 from builds 7/9/10 and reported build 11 current on both CPUs without installing |

Both native release gates passed before tagging the exact main merge commit and publishing. The legacy XML was copied unchanged from the verified public signed assets only after every public download and normal Latest endpoint passed. Its separate publication PR merged after feed CI, then both normal legacy URLs and information-only Sparkle checks passed. The application tag remains unchanged. The release branch returns to develop through a PR with native CI and a merge commit.

Physical Finder selection/Automation approval or denial, external-file Sandbox grants, VoiceOver, macOS 13, macOS 26 Intel appearance, and a complete interactive updater installation remain unverified. No owner app was installed, quit, or relaunched.

## v0.5.0 — A menu bar shelf

Fresh local checks on October 28, 2026, macOS 26.6.2 on Apple Silicon: 70 Swift tests passed without failures, including four shelf regressions and the existing conversion/settings/wheel suite. All bundled-media fixtures were required. Eighteen layout snapshots cover five languages, both appearances, empty/single/scrolling states, and opaque surfaces, with a color-content check that rejects blank compositor masks.

A separate temporary app compiled production `Shelf.swift` with Xcode 26 and displayed native Liquid Glass over its own synthetic backdrop. The actual WindowServer capture and its limits are in [Shelf-design.md](Shelf-design.md). The active-selection contrast regression failed in both appearances before the row-style correction, then the full 70-test suite passed. All 22 Node installer/feed tests also passed locally.

[Feature PR #9](https://github.com/StPashik/Yuzu-converter/pull/9) merged into develop after [final-head native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40694585829): each CPU passed 70 Swift tests, 22 Node tests without skips, and the signed Sandbox app. Apple Silicon CI used native glass on macOS 26; Intel macOS 15/Xcode 16 compiled the older material fallback. Both release archives use Xcode 26; their SDK/weak-import/version/resource/signature checks are separate gates. No installed app was updated, quit, or relaunched. Physical Finder/Sandbox, VoiceOver, macOS 13, and macOS 26 Intel appearance remain unverified.

| Release preparation | Recorded result |
| --- | --- |
| Metadata | Package, lockfile, both final executables/plists agree on 0.5.0 / build 10; CPU list remains arm64 and x64 |
| Native glass and deployment | Both main executables have SDK 26+, minimum macOS 13, and a weak `NSGlassEffectView` class import; main/helper CPU slices are exact |
| Final signed ZIPs | Deep strict signatures, helper Sandbox/inherit entitlements, helper macOS 13 targets/system libraries, exact manifests/licenses/localizations, and unchanged icon bytes passed |
| Signed Sandbox | Both extracted final apps passed bundled media, actual probe/decode/return conversions, image metadata, documents, spreadsheets, archives, and Compress to ZIP with external developer tools disabled |
| Temporary installation | Both final ZIPs installed into isolated temporary homes, passed code-signature and executable-version checks, and were removed |
| Update signing | Both archive signatures independently verified against the production public key; both signed appcasts verified for build 10 and CPU-compatible pinned downloads |
| HTTP fixtures | Real Sparkle available/current/tampered/HTTP-500 requests passed with an ephemeral test key and isolated app identity; no update installation |
| npm/source | Exactly seven npm files match tested source/metadata and final ZIP hashes; all four upstream source hashes, recipe/manifest/guide, and actual configurations for both CPUs match the source archive |
| Staging | Nine final assets; eight payload checksums recorded in [Release-checksums-0.5.0.txt](Release-checksums-0.5.0.txt) |
| Release PR/tag | [PR #10](https://github.com/StPashik/Yuzu-converter/pull/10) passed [release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40700794201); v0.5.0 tags its exact main merge commit `6061e1163fafd16b05d6f95b142e53f7fa58f4f1` |
| Release CI | Each native CPU passed 70 Swift tests, 22 Node tests without skips, and the signed Sandbox archive |
| Public release | Stable Latest v0.5.0, draft=false/prerelease=false; exact English notes and all nine uploaded sizes/digests matched staging; all nine unauthenticated public downloads passed size/SHA-256 verification |
| Latest feeds/Sparkle | Both normal Latest XML URLs matched the signed assets exactly; real production-key checks found build 10 from builds 7 and 9 and reported build 10 current on both CPUs; no installation |
| Legacy feeds/Sparkle | [PR #11](https://github.com/StPashik/Yuzu-converter/pull/11) passed [feed-only CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40703739174) and merged; both normal main/updates URLs matched the public signed XML; real production-key checks found build 10 from builds 7 and 9 and reported build 10 current on both CPUs without installing |
| Historical preservation | Original 0.4.0/0.4.1/0.4.2 release bodies/statuses, asset IDs/sizes/digests, and publication dates stayed unchanged |
| Owner control | Primary 0.4.2 / build 9 and home 0.4.0 / build 7 executable hashes remained unchanged during preparation; no global npm install, quit, or relaunch |

Both native release CI gates passed before the exact main release-PR merge commit was tagged. All public bytes and Latest Sparkle checks passed before copying the exact signed XML into the legacy bridges through a separate publication PR. After its merge, real information-only probes passed against both normal legacy URLs. The release branch returns to develop through the same native CI and merge-commit requirement. Historical tags/assets remain immutable. Physical Finder/Powerbox/bookmark recovery, login approval, AirDrop/Terminal, haptics/VoiceOver, macOS 13, macOS 26 Intel appearance, external-file Sandbox Quick Look, and a full interactive updater installation remain unverified. Signing is ad hoc, without Developer ID or Apple notarization.

## v0.4.2 — Intel support restored

Fresh checks on October 28, 2026. The owner reopened Intel support; [Intel-compatibility.md](Intel-compatibility.md) separates the observed error, recovery policy, verified results, and remaining unknowns.

| Check | Recorded result |
| --- | --- |
| Feature review | [PR #5](https://github.com/StPashik/Yuzu-converter/pull/5) merged into develop after [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40674356437) passed |
| Swift tests | 66 passed on native macOS 15 Intel, 66 on native macOS 26 Apple Silicon; local Apple Silicon also passed all 66 with no skips |
| Former failure | Both signed Sandbox apps passed the small MPEG-4 MOV → MP4 high-quality/metadata-off/72-pixel profile, probe/decode, and return conversion |
| Safety regressions | Exact native error classification and actual MP4/MOV profile dimensions/frames/original bytes are checked; existing gain, disabled-track, cancellation, and malformed-input tests remain |
| Installer tests | 22 Node tests passed locally without skips, including Intel x64 selection, preservation of the previous app during download, and rejection of unsupported CPUs before writes |
| Metadata | Package, lockfile, both final executables/plists agree on 0.4.2 / build 9; CPU list is arm64 and x64 |
| Final archives | Both extracted ZIPs passed deep strict signatures, exact main/helper CPU slices, helper entitlements, macOS 13 helper targets, system runtime dependencies, and exact license/manifest/localization bytes |
| Signed Sandbox | Both final apps passed media targets, decoding/return conversion, image metadata, documents, spreadsheets, archives, and Compress to ZIP with developer tool overrides disabled |
| Temporary installation | Both final ZIPs installed into temporary homes, passed signature/version checks, and were removed without modifying installed copies |
| Signing | Both final archive signatures independently verified against the production public key; both signed appcasts verified for build 9 and compatible CPU-specific URLs |
| HTTP fixtures | Real Sparkle available/current/tampered/HTTP-500 requests passed using a temporary test key and isolated identity; no update install |
| Source/package | All four upstream source hashes and actual configuration records for both CPUs are included; npm tarball bytes/metadata/pinned archive hashes match tested source |
| Staging | Nine assets staged; eight payload SHA-256 values are in [Release-checksums-0.4.2.txt](Release-checksums-0.4.2.txt) |
| Release PR/tag | [PR #6](https://github.com/StPashik/Yuzu-converter/pull/6) passed [release CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40678614523); v0.4.2 tags its exact main merge commit `25bec80dc406de5633bdbd55bf001f190c4478bb` |
| Release CI | Both native CPU jobs passed 66 Swift tests, 22 Node tests without skips, and the signed Sandbox archive including the former Intel MOV → MP4 failure |
| Public release | Stable Latest v0.4.2, draft=false/prerelease=false; the English body and all nine uploaded sizes/digests matched staging; all nine unauthenticated public downloads passed SHA-256/size verification |
| Latest feeds/Sparkle | Both public XML files matched the signed assets exactly; production-key probes found build 9 from arm64 build 8 and x64 build 7, and reported build 9 current on both CPUs; no installation |
| Legacy feeds/Sparkle | [PR #7](https://github.com/StPashik/Yuzu-converter/pull/7) passed [feed CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40681334121) and merged; both normal main/updates URLs matched the public signed assets; real production-key Sparkle checks found build 9 from arm64 build 8 and x64 build 7, and reported build 9 current on both CPUs without installing |
| Historical preservation | Original v0.4.0/v0.4.1 tags, release bodies/statuses, asset IDs, sizes, SHA-256 values, and publication timestamps remained unchanged after publication |
| Owner control | Installed executable hashes stayed unchanged during preparation: primary 0.4.1 / build 8, home copy 0.4.0 / build 7; no global install, quit, or relaunch |

The release passed both native CI gates before its exact main release-PR merge commit was tagged. Public downloads and Latest feeds passed verification before copying the exact signed XML into both legacy bridges through a separate publication PR. After that merge, real information-only Sparkle checks passed against both normal legacy URLs. The release branch returns to develop through the same CI and merge-commit requirement. Historical 0.4.0/0.4.1 tags and assets remain immutable.

Physical Finder/Powerbox/bookmark recovery, login approval, AirDrop/Terminal, haptics/VoiceOver, macOS 13, macOS 26 Intel UI behavior, and a full interactive Intel Sparkle installation remain unverified. The internal Apple reason for the VideoToolbox parameter rejection remains unknown. Builds are ad-hoc signed without Developer ID or notarization. FFmpeg's existing codec, first-stream, metadata, and transparency limits remain in [Bundled-media.md](Bundled-media.md).

## v0.4.1 — Stable Apple Silicon releases and manual updates

Fresh preparation on October 27, 2026. Starting with this version, the owner requested Apple Silicon (arm64) only. Existing Intel 0.4.0 tags, binaries, and the exact signed legacy x64 feed remain unchanged. There is no universal or new Intel app in this release.

| Check | Recorded result |
| --- | --- |
| GitFlow feature review | [PR #1](https://github.com/StPashik/Yuzu-converter/pull/1) merged into develop with a merge commit after [independent CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40561703972) passed |
| Release PR/tag | [PR #2](https://github.com/StPashik/Yuzu-converter/pull/2) passed [CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40564312499); v0.4.1 tags its exact main merge commit `9a1a07e182cacee7bbbecd8ef4f4730443e8452f` |
| Native CI | macOS 26 arm64: 64 Swift tests passed, zero failures; all 48 media routes and 64 settings renders ran |
| Installer/feed tests | 21 Node tests passed, zero skips; unsupported Intel installation is rejected before downloading or modifying an existing app |
| Version/CPU metadata | Package, lockfile, final executable, and app plist agree on 0.4.1 / build 8; package CPU is arm64 only |
| Final signed ZIP | Deep strict signatures, exact arm64 main/helper slices, helper entitlements, minimum macOS 13, system runtime dependencies, five language tables, and exact media license/manifest bytes passed |
| Sandbox | The final ZIP's app passed bundled media targets, probe/decode/return conversions, image metadata removal, documents, spreadsheets, and archives without developer tools |
| Isolated installation | Final ZIP installed into a temporary home; executable version and code signature passed; the temporary home was removed |
| Update authentication | Final archive signature independently verified against the production key; arm64 XML signed and independently verified for build 8 |
| Sparkle HTTP fixtures | Available/current/tampered/HTTP-500 cases passed with real requests and isolated app identities; no download or installation |
| Corresponding source | All four exact upstream archive hashes and recipe/manifest/guide bytes matched; actual arm64 build configurations are included |
| npm package | Packed files match the tested source, version, CPU declaration, and pinned arm64 archive hash |
| Release staging | Seven assets staged; six payload SHA-256 values recorded in [Release-checksums-0.4.1.txt](Release-checksums-0.4.1.txt) |
| Public release | Stable Latest v0.4.1, draft=false/prerelease=false; all seven uploaded digests/sizes and unauthenticated public downloads match staging |
| Latest feed/Sparkle | Public Latest XML is byte-identical to the signed asset; real production-key probes found build 8 from build 7 and reported build 8 current without installing |
| Legacy feed/Sparkle | [PR #3](https://github.com/StPashik/Yuzu-converter/pull/3) passed feed-only CI and merged; public XML bytes matched, arm64 build 7 found build 8, build 8 was current, and Intel build 7 remained current; no installation |
| Historical preservation | The v0.4.0 tag, prerelease status, and all nine original asset sizes/SHA-256 digests remain unchanged |
| Owner installations | Before publication, both copies were still 0.4.0 / build 7 with their original executable hashes; no global npm install, quit, or relaunch was performed |

The release PR passed before its exact main merge commit was tagged and published. The arm64 legacy bridge copied the exact public signed feed through a separate publication PR after its downloads were public. Initial Sparkle requests briefly saw the prior cached feed; repeated information-only checks then passed against the normal URL. The x64 bridge stays on 0.4.0. The release branch follows the same CI/merge-commit requirement when returning to develop. Publication never installs or restarts an owner app.

Physical Finder/Powerbox/bookmark recovery, login approval, AirDrop/Terminal, haptics/VoiceOver, macOS 13, and a complete interactive Sparkle installation/relaunch remain unverified. Signing is ad hoc, without Developer ID or Apple notarization. Conversion/stream/codec limitations remain in [Conversion-matrix.md](Conversion-matrix.md) and [Bundled-media.md](Bundled-media.md).

Historical Intel follow-up: native macOS 15 CI passed 64 Swift tests, but the signed Sandbox self-check failed with a generic operation error; the published 0.4.0 archive reproduced that failure. Its cause was not established. macOS 26 Intel UI-test preparation also did not complete in hosted CI. Those checks do not establish Intel runtime compatibility, and no new Intel support is claimed here.

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
