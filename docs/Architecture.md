# Yuzu Converter architecture

Updated October 27, 2026. The manager accepted this architecture. It describes the design and intended contracts; it is not evidence that every capability has been verified. Version 0.1.1 adds English project documentation and five selectable UI languages; fresh build and runtime validation is pending.

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

One catalog feeds the UI, backend selection, and fixtures. Distinguish researched candidates, implemented routes, and verified pairs. Hide the current format and intersect available routes for mixed inputs. [Conversion-matrix.md](Conversion-matrix.md) preserves the target inventory and verification limits.

Prefer system ImageIO, PDFKit, and AVFoundation. Do not assume that they support every pair. Record a third-party engine’s version, architecture, license, and actual capabilities before distribution. Never take FFmpeg or other backends from Tangerine. Office/EPUB/Slides/Spreadsheets/Archives need real routes; QuickLook or text extraction does not replace editable reconstruction.

Identify content and handle read failures. Invoke processes with argument arrays rather than shell interpolation. Bound logs and propagate errors and cancellation to the UI. The packaged Sandbox app uses system tools and frameworks; external FFmpeg/FFprobe/LibreOffice discovery is limited to unsandboxed developer runs.

## Files and jobs

Write to a private scratch directory first. Validate completed output, then publish it under an available name without replacing an existing file. Return every created URL. On failure or cancellation, remove only the operation’s incomplete files. Preserve sources until an explicitly requested move has succeeded.

`FileOperations.compress(_:in:) throws -> URL` creates one ZIP from selected files/folders and publishes it beside the first input under an available name. The UI acquires the required scopes and queues the operation. Originals remain unchanged. Compress to ZIP is a separate owner-requested Yuzu Action, not one of the six Tangerine Actions established by REA.

For a cross-volume file move, compare the original’s size and modification time before and after copying; keep both copies when a change is detected. This checks metadata, not content hashes. Cross-volume folder moves are refused before copying in the preview; recursive copy/delete is not used as a fallback.

The job queue performs reading, encoding, and file work off the main thread. Update UI state on the main actor. Propagate cancellation to active child processes. Do not run concurrent builds/tests in the same scratch directory.

## Dragging, wheels, and Actions

Accept data through `NSDraggingDestination.draggingEntered` / `draggingUpdated` and the corresponding `draggingPasteboard`. Do not read the global drag pasteboard. A temporary transparent drag destination may activate on the selected modifier, but draw the wheel only after a confirmed file drag. This approach still needs a physical Finder integration check.

Shift/Control switch the current wheel; Escape closes selection. Sectors expose system accessibility beyond visual hit testing. Open settings and the shelf only on explicit user action. The exact researched semantics and unknowns for `airDrop`, `float`, `copy`, `move`, `copyPath`, and `openTerminal` are recorded in [TangerineResearch.md](TangerineResearch.md).

Compress to ZIP is an additional wheel Action. It neither introduces File tools nor changes the 46-case target conversion inventory.

AppKit owns system sharing, pasteboard, workspace calls, and dialogs. Persist file access through scoped bookmarks. A file grant does not imply permission to write to its parent; use Powerbox when needed. Verify the distributed app’s signature, entitlements, and subprocess access rather than inferring them from developer runs.

## npm and GitHub Releases

A small Node installer and launch command select the declared macOS architecture, download exactly their package version from `StPashik/Yuzu-converter`, verify a pinned SHA-256, and install the app into `~/Applications` using system `ditto`. Keep the existing app until the replacement is ready. Do not execute downloaded shell scripts.

A release contains app ZIPs, the npm `.tgz`, checksums, and license notices. The `.tgz` can be installed by release URL without npm registry publication. Generate checksums from the final archives and check package version/tag/asset names. Describe architecture support, signing, and notarization only after validating the actual artifacts.

## Verification

- Swift unit tests cover content detection, route intersection, available names, errors, cancellation, and source preservation.
- Integration fixtures perform conversions, inspect output content, and verify every PDF page at 300 DPI.
- Node tests cover asset selection, checksum enforcement, download/extraction errors, and preservation of an existing app.
- Release smoke checks inspect the finished `.app`, `.tgz` contents, versions, and checksums. A checksum does not replace signing or notarization.

Independent QA compares the implementation with requirements and the matrix. Keep physical Finder drag, Sandbox grants, and system Actions marked unverified until tested. Historical v0.1.0 results are in [Validation.md](Validation.md); they are not fresh v0.1.1 runs.
