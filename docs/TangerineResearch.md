# Tangerine 2.0.2 — conversion and Actions research

Research date: October 27, 2026. Target: the installed `/Applications/Tangerine.app/Contents/MacOS/Tangerine`, version 2.0.2 (9), arm64, macOS 13+, `LSUIElement=true`. Executable SHA-256: `7691b34cc2c728aaf280041c0a13adef3e5192c43cb3e886a19ae4c69ea92928`; Mach-O UUID: `15C64A52-799E-379D-BDF0-2F29BCBC2617`.

This examines the shipped app, not Yuzu’s readiness. Proprietary code, resources, binaries, and pseudocode are not copied into the repository. File tools are outside the Actions investigation. The v0.1.1 documentation translation adds no new Tangerine execution or analysis evidence.

## Sources and confidence

The fresh REA overview used Ghidra 12.1.4 and reported 38,931 procedures and 71,978 strings: `ev_93a92bdfd820363e8d465862d7d8163f5ebd943cd0d2bcb99e9653fa37461f5e`. This is static analysis, not execution of Tangerine or observation of real dragging, clipboard, AirDrop, or Terminal behavior.

Conversion research reuses the owner’s October 22, 2026 findings for the same SHA-256: the earlier `docs/TangerineResearch.md`, `candidate-matrix.json`, `enum-reflection.json`, and REA evidence index under `Yuzu Mac App/build/research/tangerine-2.0.2/`. They are reference data only. No old Yuzu source or Git history is reused.

The report distinguishes **static facts** (explicit calls, bytes, or branches in evidence), **inferences** (interpretation of related observations), and **unverified behavior** (requiring runtime evidence or further control-flow analysis). Ghidra produces pseudocode, not original Swift. Swift closures, enum ABI, self/context, and jump tables may be recovered incompletely.

## Conversion and wheel behavior

Reference REA shows ordered targets. For N targets, the center angle of target `i` is `(N == 3 ? π : π/2) − i × 2π/N`, with inner radius 48.64 pt and outer radius 119.52 pt. Rendering and hit testing share one path. Gaps between petals are not targets. The center displays the selected target; idle source text is stored separately. Placement is clamped to the selected screen’s `visibleFrame`. Geometry evidence: `ev_95f12784ddb5a5864c2ca374be7b173e003d21ea27052591600cfc87fb2f4d3e`; hit testing: `ev_835a2c74068822d184d7423a7faffa0c8784cf3cdd72888bb08a9110305ab388`.

Tangerine globally polls `NSPasteboardNameDrag`, modifier keys, the left mouse button, and Escape. The timer switches between 0.1 s and 1/60 s. AppKit `NSDraggingDestination` accepts the eventual drop and rechecks URLs. Yuzu does not adopt global drag-pasteboard polling; its own supported-AppKit-drag requirement remains. Drop revalidation evidence: `ev_1097fb121cd6812c9119ec02c94498b9608dc6f6e74bf36c1022008d349d5ebb`.

Tangerine’s detector is not universally content-first: it starts with the name/extension, then uses ImageIO, media, ZIP/OLE, and package checks; EPERM can produce a provisional format. This does not weaken Yuzu’s content-identification requirement. Source/provisional evidence: `ev_cce1507c8ec17acb62081fb72e56735155300f96fef3d599ec9c0e9b79e5b446`.

Engine availability further filters candidate targets. For mixed inputs, the reference code requires one internal category and intersects permitted pairs for every source. ImageIO writers, FFmpeg, and individual encoder predicates affect availability. The inventory below therefore does not imply that every pair works on every Mac.

## Engines and output quality: earlier findings

| Area | Static observations and limits |
| --- | --- |
| Images | ImageIO/CGImageSource/CGImageDestination; the WebP branch uses FFmpeg/libwebp. A bundled tool’s presence alone does not prove every code path uses it |
| Audio/Video | FFmpeg branch with tool/encoder checks. Quality of every codec/container combination was not tested |
| Documents/PDF | Native dispatcher, PDFKit/CoreGraphics, Java bridge for Office, and JS resources for Pages/DOCX; the complete native-to-every-JS-entrypoint path was not traced |
| Slides/Spreadsheets | POI/PDFBox Java helper. PPT/PPTX image output goes through PDF. Complex objects may be rejected; this is not a full PowerPoint/Excel renderer |
| Pages | Writer modifies editable body text and supported objects, then rereads the package; layout fidelity and opening in Pages were not verified |
| Subtitles | Own SRT/VTT/TXT parser/serializer and atomic UTF-8 write. Complete cue/tag semantics were not verified |
| Archives | Extract into a temporary directory, then repack; GZIP targets receive `.tar.gz`. Security of every extraction/packing helper was not examined in the reference research |

Material Tangerine limits from the reference: PDF image rendering caps scale at 300 DPI, 8192 pixels per side, and 16 megapixels, so a large page is not guaranteed actual 300 DPI. PDF → PPTX inserts a picture of each page; PDF → XLSX extracts text pieces into string cells. Those do not reconstruct editable objects or tables. Yuzu’s actual-300-DPI and honest-editability requirements remain unchanged.

## Actions: dispatch and confirmed semantics

Six enum names were found: `airDrop`, `float`, `copy`, `move`, `copyPath`, and `openTerminal`. The common dispatcher `FUN_100030dc4` separates conversions, File tools, and Actions using high bits. The following tags and routes were confirmed in the Actions branch: `ev_0aacc56cdbaabd563a64bc7c11d1fa26bdd717f6c5c7f1593a40eaffd55564ad`.

| Tag | Action | Route |
| --- | --- | --- |
| `0x80` | AirDrop | `FUN_10003370c` |
| `0x81` | Float | `FUN_100033ae8` |
| `0x82` | Copy | `FUN_100145fc0` |
| `0x83` | Move | Main-queue callback `FUN_100039c78` → common helper `FUN_100033e94` → `FUN_100146ab0` |
| `0x84` | Copy Path | `FUN_100146450` |
| `0x85` | Open Terminal | Main-queue callback `FUN_100039b98` → common helper `FUN_100033e94` → `FUN_10030b3c8` |

Tag/reflection order alone does not prove the UI petal order. `copyPath`/`openTerminal` strings are at `0x1008a9a39`/`0x1008a9a42`. The read static object `0x1009dc230` contains 22 values, not the six Actions, and cannot establish their wheel order.

- AirDrop: `FUN_10003370c` constructs a sharing controller through a service factory, assigns completion, retains the controller in a UUID dictionary, and queues `FUN_10003af88` on the main queue. Constructor `FUN_100002310` standardizes inputs into `sourceURLs`, saves the service, and initializes empty `scopedURLs`, `hasStarted=false`, and `hasFinished=false`. Evidence: `ev_22faed1c28879b1d66a3352cf224ba0410566c49964dbc43ae748fb55fa92f58` and `ev_edc4cd80e9015490c15a28233367726e15c7a4c7ededb78154827edd0ed7997b`. This establishes a separate sharing lifecycle. The start callback decompiled as an empty body, so actual `performWithItems`, scope acquisition, successful delivery, and recipient UI were not established here.
- Shelf context-menu Copy: `FUN_10020749c` calls `NSPasteboard.general.clearContents` and `writeObjects(URLs)`: `ev_b81c7aa74b5cd1f02f35187f1d7d630e8c20ac8eaad8b7d049276a6971e543d7`. This establishes that shelf path, but by itself does not establish the wheel’s Copy dispatch.
- Reference strings include `FileClipboardController.swift` (`0x1008e7e40`), file/path clipboard errors (`0x1008e7e00`, `0x1008e7ea0`), and the local-path requirement (`0x1008e7e70`). Empty xrefs at a string or its address minus `0x20` do not establish non-use; Swift strings may be constructed differently.
- Terminal strings include `com.apple.Terminal` (`0x1008ed990`), `fileActionsTerminalApplication` (`0x1008ed9b0`), `TerminalFileAction.swift` (`0x1008edb70`), and the local-files/folders message (`0x1008edba0`). The directory-mapping helper below is confirmed; the default opener remains a separate boundary.
- Float strings describe adding to an existing shelf and creating a new one (`0x1008ed9d0`, `0x1008ed9f0`), `FloatingFileWindowController`, `FloatingFileDragSourceView`, “Close Float without deleting files,” “Remove from Float,” edge attachment, and detachment. They suggest several shelf modes, but do not establish storage or drag-out behavior.

### Copy and Copy Path

**Static fact:** the wheel’s Copy writes file URLs to the clipboard rather than opening a copy-destination picker. `FUN_100145fc0` requires local file URLs, starts security-scoped access, clears prior clipboard state, and calls `clearContents` / `writeObjects`. Failed writing becomes an NSError. On success, the controller stores source URLs, clipboard changeCount, and a repeating 1 s timer: `ev_7cd73c69b99d1430cc4166e36d97b0592765601e6dc5d1df5a7ca8aa1b6fe948`.

Cleanup `FUN_100145f08` invalidates the timer, clears saved inputs, and calls `stopAccessingSecurityScopedResource` on previously opened URLs: `ev_77b30a281daff29d28889b288e642444114f53f9bcaff7fdc81504cbe9a93188`. Scope lifetime therefore extends beyond the Copy function’s return. The timer condition that triggers cleanup requires separate callback analysis.

**Static fact:** Copy Path `FUN_100146450` requires local URLs, obtains `standardizedFileURL.path`, joins paths with newline, and writes `NSPasteboardTypeString`. No shell quoting is visible in that path. Failed `setString` returns an error: `ev_5237a4296cd34b4776639d9ad16c2e2cafa2ab93b198bea431e47c1be1c9a792`.

### Move

`FUN_100146ab0` validates local URLs, standardizes them, and deduplicates paths. When a directory and its descendants are selected together, it keeps a top-level set and excludes descendants already covered by a selected directory. Nesting checks use `resolvingSymlinksInPath` and a prefix with `/` as separator. Scoped URLs are retained for the callback. It then invokes an injected destination chooser, initially pointing to the first filtered input’s parent: `ev_3fcb6a95df8d2cf479c60c6d51a70b1f13eab52c1fdc1f3417dd2ba829928690`.

**Inference:** Move uses destination selection followed by a callback, separately from clipboard Copy. Actual movement, collision handling, picker cancellation, and partial-failure behavior need worker/callback analysis; the entry function alone does not establish them.

### Open Terminal

`FUN_10030b3c8` rejects non-local URLs, resolves the selected terminal application URL, and reports an error when no application is found. Terminal/iTerm2 labels and an application preference are present. After acquiring scopes, it passes inputs to `FUN_10030d1b0`, then an injected opener with the application URL and completion: `ev_38fd3ed3657be8c34fa6420def603331b3089dd2587ad3de0798b4617a43ef47`.

`FUN_10030d1b0` checks `isDirectory` and `isPackage`. An ordinary directory uses its own `standardizedFileURL`; a file or package directory uses `deletingLastPathComponent().standardizedFileURL`. This matters for `.app` and similar packages: Terminal should open beside the package. Results are deduplicated by `.path`, retaining first-occurrence order: `ev_d5feaa832d64acf8ad7ba67c264fe696a9bf8fbe828ea71f0f6aee9716328fbe`.

Preference helper `FUN_10030d060` reads the saved choice, accepts the supported Terminal/iTerm2 options, and defaults to `com.apple.Terminal`: `ev_18d16b86411f7860552c9a48b713b11c4f50b30db26bf16a6f20d82c9003ba47`.

**Unverified:** the default opener implementation and actual system-terminal launch. An injected opener does not establish shell, AppleScript, or NSWorkspace usage. Yuzu independently chose NSWorkspace with folder URLs and the Terminal app URL; this investigation does not claim an identical Tangerine launch mechanism.

### Float

`FUN_100033ae8` separates adding to an existing shelf from creating a new one. The existing-shelf branch calls group-model add and `orderFrontRegardless`. The other branch creates `FloatingFileWindowController`, sets onDismiss, and retains it by UUID in `floatingFileControllers`; `floatingFileControllerOrder` separately stores order: `ev_bfdfd800bb7eb4fd66efdd956106887c0197810e16f95c1b044f591702cecb0e`.

Constructor `FUN_100219fd8` creates a group model from inputs and a transparent panel with level 3, `hidesOnDeactivate=false`, `releasedWhenClosed=false`, a SwiftUI hosting view, and explicit callbacks. `onFilesDropped` points to group-model helper `FUN_1001fd2f0`: `ev_4387a8009997fd6ce364c9e1107ead8d973e3ea187ec203929521070f9bac285`.

Group-model wrapper `FUN_1001fe134` calls that same `FUN_1001fd2f0`; a change triggers paper-clip retraction feedback with a generation token and 0.36 s delay: `ev_3a5c72bd435d1e7832e8de721d0a3887c6a4d8834ada3618727c30a2f1e1548d`. This does not prove files are copied onto disk. Item storage, deduplication, scope lifetime, persistence across launches, and drag-out behavior remain separate questions.

Real AppKit drag-source entrypoints exist: `mouseDragged:` delegates to `FUN_100203834`, while `draggingSession:endedAtPoint:operation:` delegates to `FUN_100233830`. Evidence: `ev_d1daef634695eaefff077ba34ec03c6ca34044130f0b9600684b2bbf091663c9` and `ev_0c31ee9736caa2985a9aed718e4e57e082209f6dd2837f7c97e29b685a3da87e`. Those helper bodies were not examined, so source-operation masks, removal after drop, and file promises remain unknown.

Context-menu `removeFromFloat` calls `onFilesRemoved(items)` when assigned. The entrypoint itself does not call filesystem deletion: `ev_991546377d0bfdb85cadd6dd0cec285f42c871425983eb9375146f922e5e27ba47`. Without examining the callback, this does not establish the complete Remove behavior; “Close Float without deleting files” is also present as a string.

## Applying the findings to Yuzu

Yuzu uses its own implementation and owner-authorized assets. Clipboard Copy versus destination Move, Terminal’s parent-directory rule, available-pair filtering, and mixed-input intersection are based on the observations above. Public AppKit/NSWorkspace mechanisms, Yuzu’s enum-based Actions order, and styling are independent design choices. Compress to ZIP was separately requested by the owner; it is not a researched Tangerine Action.

Tangerine’s exact UI order was not established. Yuzu’s styles, petal gaps, control points, animations, and effects are approximations; pixel parity was not checked. Yuzu’s supported-file-drag, content-identification, and actual-300-DPI requirements are not replaced by limitations of the original.

## Question coverage

| Question | Status and boundary |
| --- | --- |
| Six Actions and common dispatch | Tags/routes statically established; UI order unknown |
| AirDrop | Source standardization, service factory, controller retention/completion established; start/perform boundary and runtime not traced |
| Copy: clipboard or destination | File-URL clipboard confirmed; controller retains scopes; timer callback not examined |
| Copy Path | Standardized paths, newline, string pasteboard, and write error established |
| Move | Local validation, deduplication/ancestor filtering, and destination-picker boundary established; worker/collisions/partial failure not traced |
| Terminal | Local validation, Terminal/iTerm2 selection, directory or file/package parent, and deduplication established; default opener/runtime unknown |
| Float | Existing/new branches, controller UUID/order, model callbacks, drag-source entrypoints, and Remove callback established; storage/persistence/drag-out helpers not traced |
| Conversion | All 46 static candidate rows and reference engine/UI evidence retained; runtime fidelity unverified |

New evidence was exported to local `build/research/rea-evidence.json`, containing 39 records when this report was completed. The manager’s main REA session produced it; the researcher read the export. The researcher’s isolated session had no open target, so no duplicate import or target switch was performed. Raw pseudocode and resources are not added to Git.

The manager then closed the main session and preserved local artifacts: `rea-evidence.json` SHA-256 `1ecc6de967cf1be4b4a25c49069aa8d0b491faf13ab48e7a9682d93a89997bca`; `rea-snapshot.json` SHA-256 `fb3835b98369b65b4fefa8b9a63ef0e7bc4f2a2b254b8a05ea35650aa0beb69c`. These raw files are not committed.

## Verification and unknowns

Real Tangerine conversion, dragging/Escape, clipboard, AirDrop, Terminal, Float, Sandbox dialogs, and file fidelity were not exercised. New manual owner checks were deferred. The saved candidate rows match the same executable, but are not new runtime tests. Limitations of Tangerine do not change Yuzu’s functional requirements.

## Full static candidate inventory

The following are all 46 input enum cases from reference `candidate-matrix.json`. The current format and global input-only targets are already removed from each row. Input-only targets are RAR, PPT, XLS, RTF, RTFD, and textClipping. SVG is not an image output. HTML has no input targets, despite being an export target.

Basis: assembly `ev_1bb1103bb8603c78d2e6023a61c0a2ddccdf9f907e59c243c316077a3f6dc403`; jump-table bytes `ev_bbdfeda58ef6e4e484d39096289033716985a08d8cf636698b8748946e04dcce`; target-array bytes `ev_851021840dc352177b2b80cf6635866ba0ca740f5bf1e4f9d242d66ce932948a`; single-format filtering `ev_b50f9b7323dd6e8ab35ee0bad484d7c977203be02ecc627442db0e295199d95d`; group intersection `ev_ed9142b85c43b0158675029b7105b60ed04366a0df9cbcfeb9fa599d6e8c3e09`.

| Input | Static candidates before runtime availability |
| --- | --- |
| jpg | png, webp, heic, tiff, avif, bmp, pdf |
| png | jpg, webp, heic, tiff, avif, bmp, pdf |
| webp | jpg, png, heic, tiff, avif, bmp, pdf |
| heic | jpg, png, webp, tiff, avif, bmp, pdf |
| tiff | jpg, png, webp, heic, avif, bmp, pdf |
| svg | jpg, png, webp, heic, tiff, avif, bmp, pdf |
| avif | jpg, png, webp, heic, tiff, bmp, pdf |
| bmp | jpg, png, webp, heic, tiff, avif, pdf |
| pdf | docx, pages, pptx, xlsx, jpg, png, epub, txt, md |
| mp3 | m4a, wav, flac, ogg, opus, aiff, wma |
| m4a | mp3, wav, flac, ogg, opus, aiff, wma |
| wav | mp3, m4a, flac, ogg, opus, aiff, wma |
| flac | mp3, m4a, wav, ogg, opus, aiff, wma |
| ogg | mp3, m4a, wav, flac, opus, aiff, wma |
| opus | mp3, m4a, wav, flac, ogg, aiff, wma |
| aiff | mp3, m4a, wav, flac, ogg, opus, wma |
| wma | mp3, m4a, wav, flac, ogg, opus, aiff |
| mp4 | mov, mkv, webm, avi, wmv, gif, mp3 |
| mov | mp4, mkv, webm, avi, wmv, gif, mp3 |
| mkv | mp4, mov, webm, avi, wmv, gif, mp3 |
| webm | mp4, mov, mkv, avi, wmv, gif, mp3 |
| avi | mp4, mov, mkv, webm, wmv, gif, mp3 |
| wmv | mp4, mov, mkv, webm, avi, gif, mp3 |
| gif | mp4, mov, mkv, webm, avi, wmv |
| docx | pages, pdf, txt, md, html, epub, png, jpg |
| pages | docx, pdf, txt, md, html, epub, png, jpg |
| ppt | pdf, jpg, png |
| pptx | pdf, jpg, png |
| txt | docx, pages, pdf, md, html, epub, jpg, png |
| md | docx, pages, pdf, txt, html, epub, png, jpg |
| rtf | docx, pages, pdf, txt, md, html, epub, png, jpg |
| rtfd | docx, pages, pdf, txt, md, html, epub, png, jpg |
| textClipping | docx, pages, pdf, txt, md, html, epub, png, jpg |
| html | — |
| epub | pdf, docx, pages, txt, md, html |
| xlsx | ods, csv, tsv, pdf |
| xls | xlsx, ods, csv, tsv, pdf |
| ods | xlsx, csv, tsv, pdf |
| csv | xlsx, ods, tsv, pdf |
| tsv | xlsx, ods, csv, pdf |
| srt | vtt, txt |
| vtt | srt, txt |
| zip | tar, gzip |
| tar | zip, gzip |
| gzip | zip, tar |
| rar | zip, tar, gzip |
