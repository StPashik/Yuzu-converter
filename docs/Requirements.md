# Yuzu Converter requirements

Updated October 27, 2026. Repository: https://github.com/StPashik/Yuzu-converter.

## Goal and scope

Build a native macOS 13+ app from scratch, reproducing Tangerine’s conversion and Actions behavior. The research target is the installed Tangerine 2.0.2 (9), `/Applications/Tangerine.app/Contents/MacOS/Tangerine`, arm64, SHA-256 `7691b34cc2c728aaf280041c0a13adef3e5192c43cb3e886a19ae4c69ea92928`. REA findings must distinguish observations, inferences, and unknowns.

File tools, PDF tools, and Archive tools are excluded. PDF and archive format conversion remain in the target inventory. The owner separately requested **Compress to ZIP**, a seventh Yuzu Action in addition to the six Actions researched in Tangerine. It must not be attributed to REA findings about Tangerine.

Do not reuse old Yuzu source, binaries, resources, or Git history. The owner explicitly authorized these exceptions: the app icon at `Resources/YuzuAppIcon.icns`, the menu bar icon at `Sources/YuzuApp/Resources/YuzuMenuBar.pdf`, and an app-icon PNG used only in documentation at `docs/images/app-icon.png`, all from the owner’s Yuzu Mac App assets. The owner subsequently authorized reading that project's wheel design and applying its appearance to the current implementation; [Wheel-design.md](Wheel-design.md) records this narrow visual reference. The old checkout stays read-only, and unrelated code/settings/engines/caches are not imported. Do not copy proprietary Tangerine resources or binaries. Keep code readable, with short comments explaining the reasons behind decisions.

Project documentation, code comments, release titles, release notes, and technical converter diagnostics must be English. Communicate with the owner in Russian. The app-owned interface has a language picker for English (default), Russian, German, French, and Spanish; changing the selection updates the UI live. Some system dialogs apply the app-scoped language after restart; never change the Mac's global language. Deliberately translated values in localization resource tables are an explicit exception to the English project-text policy. Keep keys and English fallback text consistent across all five languages.

Version 0.1.1 introduced the language picker and English project documentation; version 0.1.2 corrects the armed wheel window's input handling. Version-specific checks are recorded in [Validation.md](Validation.md). API and flow comments must explain consequential contracts and ownership in clear English, rather than narrate obvious code.

## Conversion

Target groups: Images, Audio, Video, PDF, Documents, EPUB, Slides, Spreadsheets, Subtitles, and Archives. The full REA candidate inventory and implementation gaps are recorded in [Conversion-matrix.md](Conversion-matrix.md). A static catalog entry is not proof that a pair works. Do not reduce requirements to fit the first available backend; state missing capabilities explicitly.

Determine input type from content. Hide the current format for a single file or homogeneous group. For mixed inputs, show the intersection of routes that actually support every input. Do not offer targets known to be unavailable.

Save results beside the originals under available names. Never overwrite sources or existing results. Do not open Finder automatically. PDF → JPG/PNG must process every page at an actual 300 DPI, put the results in a separate folder, and return every output URL. Do not present raster images or extracted text as reconstructed editable documents.

Read files, convert content, and perform file operations off the main thread. Support cancellation, useful errors, and cleanup of incomplete results.

Packaged video conversion must include pinned, architecture-matched FFmpeg/FFprobe helpers and required codec libraries. Support MP4/MOV/MKV/WebM/AVI/WMV output, animated GIF, and MP3 extraction without external installation, subject to actual streams and documented playback/codec limits. Preserve native routes where compatible. Sign helpers to inherit the Sandbox, pass already-open files, disable network protocols, and distribute corresponding source, build instructions, and licenses with the release.

## Actions

The researched set is `airDrop`, `float` (the floating shelf), `copy`, `move`, `copyPath`, and `openTerminal`. Confirm order, parameters, and exact semantics through REA before claiming behavioral parity. Errors and cancellation must not lose source data.

Compress to ZIP combines selected files and folders into one archive beside the first selected input, using an available name. It preserves originals and existing files. It does not add File tools.

Preview Move limit: cross-volume folder moves are refused before copying, preserving the original. Cross-volume file moves compare the source’s size and modification time before and after copying; if a change is detected, both copies are kept. This is a metadata check, without content hashing. Full cross-volume folder movement remains future work.

## UI and file access

The owner requested Tangerine's Settings design and all parameters relevant to Conversion and Actions. Use five tabs (General, Formats, Compatibility, Folders, About), native grouped controls, and all five languages. General includes Glass/Solid wheel style, actual macOS launch-at-login status, system sound/haptic feedback, independent modifier combinations, Float behaviour, and Terminal/iTerm2 selection. Do not add a File tools shortcut or commercial purchase controls. [Tangerine-settings.md](Tangerine-settings.md) records observed UI and static parameters separately from unknown proprietary behavior.

Persist output-format profiles and capture immutable values when queueing jobs. Quality, metadata policy, media size/bitrate/depth, archive compression, and EPUB version must affect their supported encoders. Validate persisted values before file work. Preserve 300-DPI PDF image output and image orientation/color. Unsupported original-page EPUB and PDF-to-Office layouts must be visibly explained and rejected, not enabled no-op controls; their implementation remains an open capability requirement in [Conversion-matrix.md](Conversion-matrix.md).

Formats and Compatibility must use Yuzu's own backend checks, distinguish file-dependent media support, and retain the full documented target inventory. Folders lists/adds/forgets only Yuzu's own bookmarks. A user-approved ancestor may cover descendants after canonical containment checks, but the returned output URL must remain the actual source parent with balanced scope ownership. Forgetting future access must preserve files and active jobs. [Settings.md](Settings.md) documents implemented choices and limits.

Run as a menu bar app without a Dock icon or main window. The menu contains **Settings…**, **Check for Updates…**, and **Quit**. Open settings and the shelf only in response to an explicit user action.

Provide the same update check in Settings. Checks are user-initiated, and downloading/installing a new version requires confirmation. Authenticate the feed and archives, select the correct architecture, and finish queued file work before restarting. A failed or cancelled installation must restore normal operation. A stale npm launcher must not downgrade an app updated in place. See [Updates.md](Updates.md).

Shift selects conversion; Control selects Actions by default. Allow independent nonempty combinations of Shift, Control, Option, and Command; choosing a conflicting combination swaps the two. Migrate the original swap preference and allow an open wheel to switch modes. The tooltip must show the keys even when wheels are disabled. Escape cancels selection. An empty drag must not show the wheel.

Use real AppKit file dragging, including from an inactive Finder. Global drag-pasteboard polling, private APIs, or extra permissions are not substitutes for supported integration. Wheel sectors and settings must expose system accessibility.

The armed destination must participate in WindowServer hit-testing before any file drag is confirmed. Keep the wheel itself hidden until AppKit supplies file URLs; a fully transparent window cannot bootstrap its own drag entry.

Use Powerbox and security-scoped bookmarks in the Sandbox. Reuse and restore existing grants without repeated dialogs. Request initial output-folder access if the file drag did not provide it; access to a file does not imply access to its parent folder.

## Distribution

Provide a native `.app`, installable through `npm install -g`, and direct Apple Silicon/Intel app downloads. GitHub Releases contain the finished app archives, npm installer `.tgz`, SHA-256 checksums, and applicable dependency licenses. Installing the release `.tgz` URL is supported; do not assume an npm registry account.

The owner installs updates personally through Check for Updates. Release work must not install globally, replace either installed copy, quit, or relaunch the owner's app. Use isolated installation fixtures. New clients use signed appcasts attached to the Latest release; older main/updates clients receive a signed bridge only after assets are public.

Document reproducible build and installation steps. Release notes must describe verified routes, available backends, supported architectures, and remaining limits. Do not label unverified capabilities as supported. Describe signing and notarization according to the actual artifacts.

## Verification and release process

The manager accepted [Architecture.md](Architecture.md). Shared Core/UI/Finder contracts belong to the manager. Use GitHub PRs from `feature/*` to `develop`, then `release/<version>` to `main` and back to `develop`. Wait for CI and preserve merge commits. Tag the exact main release-PR merge commit. Do not push shared branches directly. Publish normal versions as stable Latest releases; prereleases require an explicit owner request. See [Releasing.md](Releasing.md). Never force-push. Leave old checkouts and caches untouched.

Use separate scratch paths for automated tests. New manual checks requested from the owner remain deferred. Physical Finder drag, Sandbox grant/bookmark recovery, and integration with real system apps remain unverified until corresponding evidence exists. Passing builds and unit tests do not establish full parity or production readiness.

These requirements combine the owner’s current requests with the requirements previously recorded in the neighboring `Yuzu-converter/docs/Requirements.md`, read only as text reference. No old source or Git history was reused; the icon exceptions were explicitly authorized by the owner.
