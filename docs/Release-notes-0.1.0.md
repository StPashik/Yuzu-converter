# Yuzu Converter 0.1.0 Preview

A native macOS menu bar app for file conversion and Actions, built from scratch after static Tangerine analysis with REA. This first preview includes **Compress to ZIP** and the app/menu bar icons from Yuzu Mac App. File tools are excluded. Feature and visual parity with Tangerine remain incomplete.

## Installation

Requires macOS 13+, Apple Silicon or Intel, and Node.js 20.11+ with npm.

```sh
npm install -g https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.0/stpashik-yuzu-converter-0.1.0.tgz
yuzu-converter
```

For npm 12, explicitly allow this release URL and its installation script for the command:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.0/stpashik-yuzu-converter-0.1.0.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
```

See [npm's per-command configuration](https://docs.npmjs.com/cli/using-npm/config/#allow-remote). The installer selects arm64/x64, verifies a pinned SHA-256, and installs `Yuzu Converter.app` in `~/Applications`. The package is distributed through GitHub Releases. Alternatively, download the appropriate app ZIP and install it manually.

## Included

- Menu bar app with settings and quit controls.
- Shift for conversion, Control for Actions, configurable key swapping, wheel switching, and Escape cancellation.
- AirDrop, floating shelf, Copy Files, Move, Copy Path, Open Terminal, and Compress to ZIP.
- One ZIP for selected files/folders, created beside the first input under an available name. Originals are preserved.
- System image conversion; every PDF page exported to JPG/PNG at 300 DPI; existing PDF text exported to TXT/MD.
- Native audio export to WAV/AIFF/M4A and video export to MP4/MOV for inputs supported by macOS.
- Text/DOCX, simple EPUB reflow, values-only XLSX/ODS/CSV/TSV with all sheets, SRT/VTT/TXT, and ZIP/TAR/TAR.GZ conversion.
- Staged output, collision-safe publication, cancellation, and scoped bookmarks for output folders.

## Limitations

The Sandbox app does not bundle or launch external FFmpeg/FFprobe/LibreOffice. PAGES, PPT/PPTX, legacy XLS, textClipping, PDF-to-editable-Office, GIF conversion, and additional media encoders are unavailable. External engines are limited to developer builds.

Document layout and embedded objects are not fully preserved. EPUB uses simple text reflow. Spreadsheet conversion preserves values as strings; formulas, types, styles, charts, and embedded assets are not preserved. Markdown export is plain text. OCR is unavailable. PDF pages exceeding 32,768 pixels per side or 64 megapixels at 300 DPI are rejected. GZIP means TAR.GZ. Archive links, unsafe/colliding names, and oversized archives are rejected.

Cross-volume folder moves are refused before copying. Cross-volume file moves compare the original's size and modification time before/after copying; this is a metadata check. The floating shelf retains references for the current session.

**Signing is ad hoc. Developer ID and notarization are unavailable.** Gatekeeper may block the first launch. Manual Finder drag, Powerbox/bookmark recovery, AirDrop, Terminal, VoiceOver, and shelf drag-out checks remain deferred. Intel hardware and macOS 13 were not tested directly.

## Validation and assets

- 26/26 Swift tests passed on arm64 and x86_64 through Rosetta; 13/13 Node tests passed.
- Both signed Sandbox apps passed DOCX/textutil, spreadsheet, ZIP/TAR, and Compress to ZIP self-checks.
- Both final ZIPs passed installer, signature, architecture, and executable-version checks.
- Assets include arm64/x64 app ZIPs, the npm installer, SHA256SUMS, and license notices.

These fixtures do not verify every format pair or codec profile. See the [conversion matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.1.0/docs/Conversion-matrix.md), [REA research](https://github.com/StPashik/Yuzu-converter/blob/v0.1.0/docs/TangerineResearch.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.1.0/docs/Validation.md).
