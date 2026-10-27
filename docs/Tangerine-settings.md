# Tangerine 2.0.2 Settings research

Research date: October 27, 2026. Target: `/Applications/Tangerine.app/Contents/MacOS/Tangerine`, version 2.0.2 (9), arm64. Executable SHA-256: `7691b34cc2c728aaf280041c0a13adef3e5192c43cb3e886a19ae4c69ea92928`.

The owner requested both the Settings design and all parameters relevant to Conversion and Actions. File tools remain excluded. This report records the reference; it does not establish implementation or validation of Yuzu's port. See [Requirements.md](Requirements.md), [Architecture.md](Architecture.md), and [Validation.md](Validation.md) for Yuzu's contracts and verification status.

## Evidence and boundaries

REA captured the exact running Settings window, PID 59860 and window ID 4042. macOS allowed selected-window screenshots but denied Accessibility automation. The owner opened Settings and selected each tab manually. The agent did not change a preference, register a login item, grant folder access, purchase anything, or run a conversion in Tangerine.

| View | Screenshot Evidence ID |
| --- | --- |
| General | `ev_248db863710def90b24c21238c49013c6eb20df00509195eff44b05a8cc4fb96` |
| Formats, with JPG selected | `ev_b1564c8b262e2de0e4c793c634a245295f5701dc3d6183691751e97d768b7f1c` |
| Compatibility, visible upper portion | `ev_284d139f9659c1329f959d0bcb3b90d56d0a08091626b7e023235c135906c5d9` |
| Folders | `ev_b5e56f9395ec69cf9c34ce75f7ed4d6f34893f05491ef509b4b5080082388da9` |
| About | `ev_a3aa36625746074c38210f2f5d5d0acb7224e5533f0b7bd5bd0861223a5bfcbe` |

These screenshots establish visible content and layout, not control bindings, persistence, default values, or backend effects. A displayed value is the current reference app state, not necessarily a factory default. Raw screenshots, proprietary resources, executable bytes, and decompiled pseudocode are not committed or distributed with Yuzu. Local REA evidence exports remain ignored research artifacts.

The completed session exported 18 records to local `build/research/tangerine-settings-evidence.json` (SHA-256 `a91f6b7115ef6692370ca32ed0da587cd3c308340c190216b21018ac5282ae21`) and preserved a snapshot (SHA-256 `ea4c2ae6a3e8d4af2f31a3c797dd87cb0480a14294cd9238466b4abfa150bb88`) before closing. These hashes identify the research artifacts, not a Yuzu build or test result.

## Observed layout

The captured window is 456 × 592 pixels, including its native title bar. A compact segmented control selects **General**, **Formats**, **Compatibility**, **Folders**, or **About**. The selected segment is orange. Content uses rounded grouped cards, small secondary section headings, separators, and native checkboxes and pop-up controls.

Static constructor evidence corroborates an `NSHostingController` inside an `NSWindow`, retained after closing, with a 456 × 560 pt content size and equal minimum and maximum sizes: `ev_2bfb0a0841bd0cff6ecab21216286cff04b892de8ebf369d38d6b2cad019825e`. This is recovered call structure, not original Swift source.

### General

The first card selects a Glass or Solid style. The next card contains launch at login, sound and haptic feedback, drag modifiers, Float behaviour, and the terminal application.

There are separate modifier pickers for the conversion, tools, and Actions wheels, followed by a short dragging instruction. The captured choices are Shift, Command, and Control respectively. The tools-wheel picker is outside Yuzu's scope. Float has a picker for creating a shelf versus adding to an existing one; the terminal picker displays Terminal. Earlier [Actions research](TangerineResearch.md#open-terminal) separately established Terminal/iTerm2 preference handling.

The screenshot does not establish which visual elements the style setting changes, which events trigger feedback, all modifier combinations, login approval handling, or the full pop-up menus.

### Formats

A narrow searchable sidebar groups formats by category. The selected format's detail area explains its role and output targets, then presents conversion settings. With JPG selected, the visible conversion controls are quality, metadata preservation, and restoring defaults.

A separate Image Compression section contains compression and image-size controls plus its own reset button. That section belongs to the excluded File tools work and is not part of this port. Its presence does not make image compression a seventh researched Tangerine Action; Yuzu's Compress to ZIP remains the owner's separate request.

Only the selected JPG detail was captured. Other format-specific fields below come from static bytes, not from observing every format editor.

### Compatibility

The visible page contains grouped input/output matrices, starting with Images and Documents. Checkmarks distinguish candidate pairs from empty cells; a scrollable continuation is visible. The lower groups and every cell were not captured in this pass.

These checkmarks are UI observations. They do not prove that the associated decoder, encoder, or conversion works for a given file or Mac. Yuzu must derive its own displayed availability from its current engines and retain the limits in [Conversion-matrix.md](Conversion-matrix.md).

### Folders

The page displays an explanation of output-folder grants, an existing folder entry, a remove-access control, and an Add Folder button. The text says a parent-folder grant covers descendants. This is an observed explanation, not a traced Sandbox implementation or a successful access test.

Yuzu must manage only its own user-approved bookmarks. It must not import Tangerine's grants, stored paths, or settings. Removing a remembered bookmark must not invalidate scopes already retained by an active operation.

### About

The centered page shows the app icon, name, version, a remaining-use counter, purchase and restore controls, and support. Yuzu uses its own authorized icon, version, documentation, and manual update control. Trial accounting, payments, and purchase restoration are outside this project's scope.

## Statically observed conversion parameters

REA read two complete 512-byte ranges at `0x1008a7d00` and `0x1008deba0`: `ev_8def7110026f144604a9810a10d2fa61249590cefe45817b2f7a2530d9e93f07` and `ev_db658d3fa0dac6f0e590cc85172a2a8d2e600e053e22df552a89e55321f2a27a`. Their strings establish the following names and nearby enum cases. Proximity alone does not prove a particular format binding or encoding effect.

| Field name | Observed cases or remaining question |
| --- | --- |
| `quality` | `compact`, `balanced`, `high` |
| `preserveMetadata` | Name present; exact preservation/stripping policy unverified |
| `videoMaxHeight` | Name present; numeric choices and scaling policy unverified |
| `audioBitrate` | Name present; units, choices, and codec applicability unverified |
| `audioSampleDepth` | `matchSource`, `bit16`, `bit24`, `bit32`, `float32` |
| `gifFrameRate` | Name present; choices and timing policy unverified |
| `gifMaxWidth` | Name present; choices and scaling policy unverified |
| `compression` | `fast`, `balanced`, `maximum`; exact format applicability unverified |
| `epubLayout` | `adjustableText`, `preservePages` |
| `epubReflowVersion` | Name present; numeric versions and writer behavior unverified |
| `pdfOfficeLayout` | `editable`, `preservePages` |

The report does not assign Tangerine's undocumented numeric values to Yuzu's controls. Those mappings require either further reference evidence or an explicitly documented Yuzu implementation choice.

## Reconstruction requirements

- Recreate the five-tab organization and grouped visual hierarchy with Yuzu's own code and native controls. Keep all five interface languages and the shared updater functional.
- Wire enabled controls to actual behavior. Capture immutable conversion options when a job is queued, so later preference edits cannot alter an operation already in progress.
- Preserve file safety, cancellation, real 300-DPI PDF image output, color and orientation correctness, and bounded resources. A metadata-off option needs output-level tests for sensitive metadata removal.
- Present unsupported route-dependent settings honestly. A setting must not imply that packaged GIF encoding, editable PDF-to-Office reconstruction, or another unavailable route has been added.
- Use Yuzu's own conversion capabilities for Formats and Compatibility. Keep unsupported formats and option limitations recorded rather than replacing the target requirements with the current backend's limits.
- Keep the File tools wheel, image-compression editor, proprietary assets, commercial account state, and purchase UI out of this port.

## Remaining unknowns

Tangerine's full option menus, reset values, persistence semantics, per-format field applicability, encoder mappings, metadata policy, style rendering, feedback events, and lower compatibility groups were not exercised in this pass. Screenshots and string ranges do not resolve those questions. No new physical Finder, Sandbox recovery, Terminal, login-item, or accessibility acceptance gate was completed for Yuzu by this research.
