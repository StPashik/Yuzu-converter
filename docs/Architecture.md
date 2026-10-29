# Yuzu Converter architecture

Updated October 29, 2026. The manager accepted this architecture. It describes the design and intended contracts; it is not evidence that every capability has been verified. Version 0.1.1 added English project documentation and five selectable UI languages. Version 0.1.2 corrects wheel hit-testing; see [Validation.md](Validation.md) for version-specific evidence.

## Structure

One Swift package has two production targets:

- `YuzuCore` identifies content, catalogs formats/routes, converts files, runs cancellable jobs, safely publishes results, and provides file-operation contracts. It does not manage windows or present dialogs.
- `YuzuApp` owns the AppKit menu bar, drag destination, wheels, system Actions, and floating shelf. SwiftUI is used for settings content where it simplifies the code. The UI requests Powerbox access and passes usable URLs to Core.

Shared Core/UI/Finder contracts belong to the manager. Contributors must coordinate changes to those contracts. Add a wrapper or dependency only for a real need that existing code or a system API does not cover.

## Localization and developer explanations

Project documentation, release text, and code comments use English; conversations with the owner use Russian. Settings offers English (default), Russian, German, French, and Spanish for app-owned UI, with live updates. Five `en`/`ru`/`de`/`fr`/`es` `.lproj` tables use the same keys and an English fallback. Translated resource values are deliberate localization data, not a violation of the English source/documentation policy. Technical conversion diagnostics remain English.

Keep UI localization in YuzuApp; Core remains responsible for conversion and technical errors. Use English API/flow comments to explain file-grant ownership, cancellation, validation, and publication guarantees. [Developer-guide.md](Developer-guide.md) gives the source reading order and contribution checklist.

The owner authorized reuse of the app icon `Resources/YuzuAppIcon.icns` and menu bar icon `Sources/YuzuApp/Resources/YuzuMenuBar.pdf` from Yuzu Mac App. They are included in the app bundle; a separate icon generator is unnecessary. An app-icon PNG from the same owner-provided assets may be used only at `docs/images/app-icon.png` for documentation. These exceptions do not permit reuse of old source, other application resources, Git history, or Tangerine resources.

## Format catalog and engines

`ConversionOptions` is a Codable/Sendable value, validated against the output format before encoding. Settings stores profiles by stable output-format identifier, and `JobRequest` captures a value copy before queueing; ZIP Actions use the ZIP compression profile. Defaults, encoder mappings, supported fields, and unavailable layouts are explicit in [Settings.md](Settings.md). Metadata removal is an encoding policy with output-level fixtures, not only a saved checkbox. PCM match-source must preserve supported sample precision or reject the source depth.

Native-video metadata removal rebuilds track ranges without descriptive metadata while retaining enabled state, transforms, and volume. Export also applies an explicit audio mix to every audio track in both metadata modes: copied volume tags alone do not establish actual mute/gain. Invalid source gains fail rather than clamp. The regression checks real disabled video, hidden nonzero audio, mute, and half-gain output.

`ConversionEngine.availability(from:to:)` exposes the existing format-level gates to Settings without fabricating SourceFile inputs. Native media can report file-dependent availability; actual wheel targets still probe the real source. Settings performs catalogue/encoder discovery off the main actor.

One catalog feeds the UI, backend selection, and fixtures. Distinguish researched candidates, implemented routes, and verified pairs. Hide the current format and intersect available routes for mixed inputs. [Conversion-matrix.md](Conversion-matrix.md) preserves the target inventory and verification limits.

Prefer system ImageIO, PDFKit, and AVFoundation. Do not assume that they support every pair. Record a third-party engine’s version, architecture, license, and actual capabilities before distribution. Never take FFmpeg or other backends from Tangerine. Office/EPUB/Slides/Spreadsheets/Archives need real routes; QuickLook or text extraction does not replace editable reconstruction.

Identify content and handle read failures. Invoke processes with argument arrays rather than shell interpolation. Bound logs and propagate errors and cancellation to the UI. The packaged Sandbox app includes architecture-matched FFmpeg/FFprobe in `Contents/Helpers`, signed with only app-sandbox and inherit entitlements. Native media routes remain preferred when compatible. If AVFoundation reports its unknown-export error with an underlying VideoToolbox parameter error, MP4/MOV may retry through a capable bundled FFmpeg after discarding private partial output. Cancellation, unrelated failures, and sources with disabled tracks or non-unit audio gain do not use that retry. Media helpers receive seekable open-file descriptors; runtime media protocols are restricted to `fd`, so a child does not reopen a Powerbox-selected path or follow sidecar/network URLs. Full media encodes remain cancellable without the probe timeout. Externally installed FFmpeg/FFprobe/LibreOffice discovery is limited to unsandboxed developer runs. [Bundled-media.md](Bundled-media.md) records pinned codec builds, licenses, source distribution, and stream/playback limits.

## Files and jobs

Write to a private scratch directory first. Validate completed output, then publish it under an available name without replacing an existing file. Return every created URL. On failure or cancellation, remove only the operation’s incomplete files. Preserve sources until an explicitly requested move has succeeded.

`FileOperations.compress(_:in:) throws -> URL` creates one ZIP from selected files/folders and publishes it beside the first input under an available name. The UI acquires the required scopes and queues the operation. Originals remain unchanged. Compress to ZIP is a separate owner-requested Yuzu Action, not one of the six Tangerine Actions established by REA.

For a cross-volume file move, compare the original’s size and modification time before and after copying; keep both copies when a change is detected. This checks metadata, not content hashes. Cross-volume folder moves are refused before copying in the preview; recursive copy/delete is not used as a fallback.

The job queue performs reading, encoding, and file work off the main thread. Update UI state on the main actor. Propagate cancellation to active child processes. Do not run concurrent builds/tests in the same scratch directory.

## Dragging, wheels, and Actions

Settings uses five stable enum-identified pages and a retained resizable window. One Settings/AccessStore/AppUpdater instance is shared with the app. Closing or changing language does not recreate preferences, grants, or the updater. General reads ServiceManagement status for login registration and refreshes when the application becomes active; registration occurs only after the user toggles it.

Fifteen standard modifier combinations are available. Match complete chords, ignore Caps Lock/Fn, retain a latched wheel after key release, and suppress selection after Escape until mouse release. Resolve duplicate assignments by swapping, retaining the original preview's legacy swap preference during migration.

Glass uses a native masked backdrop, with the selected petal excluded to preserve its orange fill. Solid and Reduce Transparency use an opaque surface. Both share the existing geometry, accessible labels, and armed-window behavior. Feedback occurs only on entering a different nonempty sector, uses system Tink/alignment feedback, and is throttled; no proprietary sounds are bundled.

Accept data through `NSDraggingDestination.draggingEntered` / `draggingUpdated` and the corresponding `draggingPasteboard`. Do not read the global drag pasteboard. A temporary destination activates on the selected modifier with a 1% black background: WindowServer excludes fully transparent pixels from hit-testing, preventing drag entry before the wheel is drawn. Draw the wheel only after a confirmed file drag. The regression test checks the armed window's actual WindowServer hit; a physical Finder integration check remains open.

Shift/Control switch the current wheel; Escape closes selection. Sectors expose system accessibility beyond visual hit testing. Open settings and the shelf only on explicit user action. The exact researched semantics and unknowns for `airDrop`, `float`, `copy`, `move`, `copyPath`, and `openTerminal` are recorded in [TangerineResearch.md](TangerineResearch.md).

Version 0.2.1 applies the owner-authorized Yuzu Mac App visual reference: rounded translucent petals, a separate three-line center, top-first ordering, orange/white selection, text-only format labels, and SF Symbols for Actions. Drawing and selection share the same rounded `CGPath`. The content fade respects Reduce Motion while the armed destination remains hit-testable. See [Wheel-design.md](Wheel-design.md) for dimensions and rendered previews.

Compress to ZIP is an additional wheel Action. It neither introduces File tools nor changes the 46-case target conversion inventory.

`ShelfController` owns a compact nonactivating panel positioned under the current status-bar button. Clamp its frame to that display's visible area, follow status-window/display changes, grow through five rows, and scroll longer lists. Show Shelf presents every retained collection, creating an empty shelf only when none remain. Float still follows the existing add-to-current/new-shelf setting and may append to the latest hidden shelf. Discard only empty closed controllers. Closing cancels pending preview requests but retains files, grants, and completed previews for reopening; present reloads the table to request any cancelled preview again.

The owner requested retention only within the running app. Keep closed collections in `ActionController` without serializing their file lists or recovery bookmarks. User-approved folder permissions remain owned by `AccessStore`. Explicit remove/clear releases references; exiting Yuzu ends the session. All retained shelves reopen through Show Shelf, so independent hidden collections are not stranded behind the newest one.

`ShelfShortcutController` owns the saved chord and exclusive public Carbon hotkey registration. AppDelegate enables it only while Finder is frontmost, releasing it in other apps and during shutdown/update installation. Settings records key-down events only inside its own focused window; Escape cancels and Delete disables. Accept Control chords or Command with another standard modifier, reject unsupported keys, and preserve the previous preference when native registration fails. Store the physical key and show its name using the current keyboard layout.

The explicit shortcut starts one bounded background `FinderSelection` request at a time. Its fixed AppleScript asks only Finder for selected aliases; no filenames enter executable source, no clipboard is changed, and no Accessibility permission is used. The Sandbox exception targets only `com.apple.finder`, with a localized Automation explanation. Validate actual file descriptors before extracting URLs. `AccessStore.shelfFiles` restores/requests independently owned parent access through Powerbox for every Sandbox batch; readability alone can borrow another shelf or job’s active grant. Reuse one acquired ancestor for the same batch’s descendants. Successful scopes transfer into `ScopedFiles` and live as long as the shelf references. The updater waits for this request/authorization to finish. Physical Finder, Automation approval/denial, and external-file Sandbox access remain separate unverified gates.

On macOS 26+, embed the shelf content in `NSGlassEffectView.contentView`; earlier systems use an active behind-window `NSVisualEffectView` with the popover material. Reduce Transparency replaces either with an opaque surface and responds to accessibility changes live. Quick Look thumbnails are requested lazily for displayed rows, retain their source grants through completion, and fall back to system icons. Cancel and reject stale requests when references are removed. Incoming file drops use only the supplied dragging pasteboard; outgoing drags remain URL copies. Clear/remove/close never delete files, and grants remain tied to the references and pending work that need them.

AppKit owns system sharing, pasteboard, workspace calls, and dialogs. Persist file access through scoped bookmarks. A file grant does not imply permission to write to its parent; use Powerbox when needed. Verify the distributed app’s signature, entitlements, and subprocess access rather than inferring them from developer runs.

For saved ancestor access, resolve scopes without UI/mounting, validate canonical path components, and derive an independently scoped child bookmark for the actual output parent while the ancestor is active. Transfer the child scope to the job and release the ancestor. Removing a saved bookmark changes only future access. Real Sandbox descendant-bookmark recovery remains a deferred physical gate. Terminal selection is limited to the known Terminal/iTerm2 bundle identifiers and retains source grants through launch completion.

## npm and GitHub Releases

A small Node installer and launch command select the declared macOS architecture, download their package version from `StPashik/Yuzu-converter` when needed, verify a pinned SHA-256, and install the app into `~/Applications` using system `ditto`. Preserve the same or a newer installed numeric release so an old launcher cannot undo a Sparkle update. Keep the existing app until the replacement is ready. Do not execute downloaded shell scripts.

Release changes move through feature/develop, release/main, and release/develop pull requests with CI and merge commits. Tag the main release-PR merge commit. Stable Latest is the default; a beta/RC requires an explicit owner request. Publication does not install, quit, or relaunch the owner's app. [Releasing.md](Releasing.md) defines the release/legacy-feed sequence.

Version 0.4.1 was Apple Silicon only. Native Intel CI and signed Sandbox verification passed after the owner reopened support on October 28, 2026. Version 0.4.2 restores separate arm64/x64 app archives, CPU-matched npm assets, corresponding source/configuration records, and signed feeds. Both native architectures remain required CI targets. Legacy feeds advance only after their compatible assets are public.

A release contains separate arm64 and x64 app ZIPs, the npm `.tgz`, checksums, and license notices. The `.tgz` can be installed by release URL without npm registry publication. Generate checksums from the final archives and check package version/tag/asset names. Describe architecture support, signing, and notarization only after validating the actual artifacts.

## In-app updates

Version 0.2.0 adds a shared `AppUpdater` to the menu and Settings. Sparkle 2.10.1 owns network checks, update UI, Ed25519 verification, installation, and relaunch. Checks are manual and installation requires user confirmation. New builds read their signed architecture-specific appcast from GitHub's Latest release assets. Versions through 0.4.0 retain the main/updates bridge, advanced by a PR only after the referenced assets are public. Both the feed and archive must verify against the public key embedded in the app, before archive extraction.

Postpone relaunch while the file queue is nonempty. When the queue drains, stop new drags/jobs before resuming Sparkle's installation handler. A finished/cancelled/failed cycle clears the retained handler and restores the monitor if the application is still alive. Normal termination retains its cancellation/cleanup safety net.

The Sandbox app enables outgoing network access, the Installer launcher service, and its two mach lookups. Sign helper tools inside out, preserving service entitlements. Ad-hoc builds disable library validation solely to load the bundled dynamic framework without a Team ID. See [Updates.md](Updates.md) for key custody, per-architecture feeds, license attribution, and release commands.

## Verification

- Swift unit tests cover content detection, route intersection, available names, errors, cancellation, and source preservation.
- Integration fixtures perform conversions, inspect output content, and verify every PDF page at 300 DPI.
- Node tests cover asset selection, checksum enforcement, download/extraction errors, and preservation of an existing app.
- Release smoke checks inspect the finished `.app`, `.tgz` contents, versions, and checksums. A checksum does not replace signing or notarization.

Independent QA compares the implementation with requirements and the matrix. Keep physical Finder drag, Sandbox grants, and system Actions marked unverified until tested. Historical v0.1.0 results are in [Validation.md](Validation.md); they are not fresh v0.1.1 runs.

## Shelf workflow and queue (0.6.2)

Shelf rows publish file URLs with explicit local and external copy masks. The shelf exposes no conversion/Actions menus. Its folder button checks the referenced path off-main before selecting it in Finder. `ActionController.scopedFiles` retains matching original shelf batches for wheel probing and drop handling; the pasteboard's file URLs alone are insufficient to preserve inherited parent scopes after row removal. Right-click only selects/removes references. Float in the wheel/hotkey still honors the existing shelf preference.

`AppDelegate.handleRequest` receives wheel requests, acquiring destination grants on the main actor and capturing `ConversionOptions` into `JobRequest`. The request owns active destination scopes through RAII; selection leases keep parent grants alive independently of rows. `JobQueue` owns a serial detached worker, forwards cancellation, releases waiting requests immediately on cancellation, and drops successful/cancelled request grants. Failed requests retain their remaining inputs and access leases for explicit Retry; UI entries retain labels, recovery information, and output URLs. Conversion publishes progress after each input; Move retains Core's normalized whole-selection semantics, and its publication callback preserves result URLs even if a later move fails. ZIP and Move remain indeterminate while inside their synchronous Core operation.

`QueueWindowController` retains a nonactivating normal-level panel sized to up to three rows; Close/Escape hide its UI without cancelling the worker. Success rows expire after one second using their unique job IDs; failures and cancellations remain. A nonempty-to-empty list transition closes the panel. Automatic presentation does not activate the app. Show Operations explicitly activates it. There is no Show Results control. Its SwiftUI host fills the panel with automatic intrinsic sizing disabled, so a long history scrolls rather than resizing the content beyond the window. Each root carries an explicit language snapshot; changing language reuses the queue without mixing old cached labels. `AppSurface` centralizes native glass/material/opaque fallback and clips backing layers to the shared rounded corners. `WheelMaterialView` masks that shared glass surface and deliberately returns no hit-test target. Reduce Transparency/Glass/Solid updates keep existing wheel geometry and accessible buttons.

Updater relaunch waits for both the queue and modal request preparation, including reentrant Powerbox loops. Termination cancels waiting/active work and awaits worker cleanup. Queue history, shelf references, and output profiles are not serialized together: profiles persist, but jobs and references are session-only.

The media cache stores only architecture-specific helpers, their exact portable build configurations/receipt, and four SHA-pinned source archives. Cache identity binds the source manifest, build/cache recipes, SDK version/build, clang version, architecture, and macOS 13 deployment contract. Verification requires the complete fixed file set, matching hashes, executable matching CPU, system runtime dependencies, and source hashes. Invalid tools/configurations trigger a rebuild; a pinned source SHA mismatch stops the build until the bad archive/cache entry is removed. PR workflows restore only; a separate main/develop workflow saves reviewed entries. Full native tests and signed Sandbox archive checks still run on every code PR. [CI.md](CI.md) documents cache scope and diagnostics.

## Publication, PDF geometry, and update notes

The shared atomic `FileOperations.publish` keeps the requested name first, then tries `_yuzu`, `_yuzu_2`, and subsequent suffixes under `RENAME_EXCL`. Conversion already derives its stem directly from the source; it does not strip or shorten the user's original filename. PDF raster output explicitly scales the bitmap context from PDF points to 300-DPI pixels before placing the page: CGPDFPageGetDrawingTransform only scales down. It uses the visible CropBox for both 300-DPI sizing and the page drawing transform, including nonzero origins and rotations. Pixel fixtures check content coverage, not just image dimensions. The owner's original PDF has not been supplied; its exact case remains unverified.

Wheel feedback restarts the existing system sound before playing it on each highlight change. There is no shared 80 ms throttle; the drag view already suppresses repeated feedback within one petal. Physical sound/haptic perception remains a manual gate.

`prepare-updates.mjs` reads the reviewed version-specific English Markdown release notes, validates their heading/size, and embeds them as Sparkle Markdown in each signed feed. CDATA delimiters are escaped without changing text. Sparkle's native text view displays the notes before download/installation, including to existing clients; no remote webpage or custom updater UI is needed. The real HTTP probe verifies Sparkle parses the expected Markdown.

## Batch conversion, virtual images, and responsive feedback (0.6.2)

`ConversionEngine.targets` intersects the first source's ordered candidates with every source's actual routes, rather than requiring one category. A combined image-to-PDF request captures a single destination grant; its worker classifies every input, writes one oriented first frame per image through `NativeDocuments.imagesPDF`, validates the complete staged PDF, and atomically publishes once. Failure/cancellation publishes no partial document. Other batches retain the existing per-file partial-publication contract.

`ImageDrop` is main-actor isolated and snapshots the accepted drag representation. A promise-content marker distinguishes unsaved screenshot data even when the item also advertises a local URL. Pasteboard raster data is read only at acceptance, never on hover. File promises begin reception in AppKit's drop callback; a retained result survives the Save panel. Remote URL requests begin only after Save. Their ephemeral URLSession has no cookies/credential storage and enforces response/MIME/size/redirect/time limits. Promised output must be a regular, non-symlink raster inside the private directory; metadata is checked before decoding. `ScopedFiles` can own this disposable directory and removes it when the last lease ends.

`JobKind.importedImage` waits for materialization, observes cancellation, and invokes `saveDroppedImage`. NSSavePanel grants an exact destination URL, so Foundation supplies a same-volume item replacement directory and `RENAME_EXCL` publishes that exact path without sibling-name attempts or replacement. The picker rejects existing names; a publication race fails safely. Physical external-file Powerbox and real browser promise interoperability remain unverified.

`WheelDragView` caches geometry and reuses one CAShapeLayer with implicit actions disabled. Pending/empty options have no visible wheel. Once route discovery resolves empty, the monitor orders its panel out while retaining drag/mode state, allowing Actions to restore it. Feedback uses a serial sound queue so cold audio service initialization cannot hold draggingUpdated. The haptic performer is acquired before hover and requests feedback after drawing. A stalled sound fixture checks callback responsiveness and per-petal replay.

`QueueInsetView` owns the 20-point AppKit inset; the SwiftUI host is constrained inside it. Empty-state footer controls are hidden, copy wraps vertically, and long lists scroll. No percentage/progress view remains. Successful-entry expiration is one second; error/cancellation retention and queue lifecycle remain unchanged.

`SpreadsheetPDF` prints A4 tables using CoreText and CoreGraphics. It wraps/continues long rows, paginates column bands, carries source column widths/row heights, and starts each sheet on a new page. Cached formula values remain data; missing cached formulas are tracked separately for PDF display so values-only exports retain their contract. Uniform grid borders and a system font are intentional readability defaults, not reconstructed Excel styles. Dense-layout and page-count limits bound work for sparse or extreme inputs.

## Retry and reference recovery (0.6.3)

`QueueProgress.finishedSources` records completed input identities independently of output count; `JobRequest.remaining` filters both source URLs and their corresponding per-file destinations. The request value shares its original destination lease rather than adopting active scopes twice. A failed row retains only the pending request snapshot; that snapshot may retain an original batch lease when grants were acquired together. Clear Finished and success/cancellation release retained requests. Retry moves the same row ID to the tail in one published list assignment, preserves earlier output URLs, and resets the attempt state/count. `allowsRetry` closes the new entry point during update handoff and termination. `JobRecovery` classifies stable Cocoa/POSIX/network codes for five-language instructions; Details retains the original diagnostic and Copy Details includes it in full.

`FileOperations.copy` keeps `onPublish` as its final/default callback for existing callers. A separate `onMove(FileMove)` runs after rename or verified cross-volume source removal; same-parent no-ops report completion too. `FileMove.relocating` uses lexical path components because the old path may already be gone. Its directory flag excludes symlink-target descendants. Move progress records preserved publication even when removal fails, so Retry cannot produce another copy of an already published input. Actual move effects and a lease retaining the chosen destination scope reach `ActionController.filesMoved`, every shelf, and other waiting/failed requests. Beside-source output parents follow known source moves; explicit folders follow their own directory move. Exact image Save As destinations remain fixed.

`ShelfController` replaces references in place, merges duplicate path identities, retains the incoming destination/picker lease, preserves selected path identities, and cancels obsolete thumbnail requests. Matching grants by standardized path handles directory URLs with/without a trailing slash. Availability uses a cancellable detached probe with a generation and source-list guard. A two-second timer launches a probe only while visible and none is pending; closing stops polling/probes while keeping references. Known missing/access-denied rows show a search button; Locate Original uses Powerbox and replaces only the reference. External filesystem changes are detected as availability changes, not treated as authority to search or follow arbitrary paths.

A virtual-image worker reports a validated prepared `ScopedFiles` before encoding. Failure retains that disposable source until Retry/Clear Finished/session exit. Successful retry reuses the cached bytes, including single-use promises, and releases the private directory after publication. A failed promise before materialization cannot offer a replay. Remote HTTP failures include their status in the diagnostic and use network recovery advice; downloads retain all existing bounds and credential isolation.
