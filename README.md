# Yuzu Converter

<img src="docs/images/app-icon.png" width="112" alt="Yuzu Converter icon">

File conversion and useful file actions from your Mac’s menu bar. Hold a key while dragging a file, choose a destination on the wheel, and drop.

**v0.1.1 is the multilingual UI preview.** It adds five interface languages and developer documentation while retaining the conversion and Actions behavior of v0.1.0. File tools are outside the scope of this release.

## Download

Requires **macOS 13 or later**. Choose your Mac:

- [Download for Apple Silicon](https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.1/Yuzu-Converter-0.1.1-arm64.zip)
- [Download for Intel](https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.1/Yuzu-Converter-0.1.1-x64.zip)

Unzip the download, move **Yuzu Converter.app** to Applications, and launch it. The app appears in the menu bar. Builds use an ad hoc signature, without Developer ID or notarization, so Gatekeeper may block the first launch.

See the [quick start](docs/Quick-start.md) for installation, permissions, and npm options.

## Use it

1. Start dragging a file or a group of files.
2. Hold **Shift** for conversion or **Control** for Actions.
3. Drop onto a wheel sector. Press **Escape** to cancel, or hold the other modifier to switch wheels.

Open **Settings…** from the menu bar to swap the keys or choose whether new files join an existing shelf. Converted files are saved beside their originals under an available name. The app may ask for access to that folder the first time.

Choose the interface language in Settings: **English** (default), **Russian**, **German**, **French**, or **Spanish**. App-owned UI updates live; some system dialogs use the new language after an app restart. Your Mac's global language is unchanged. Technical converter diagnostics, project documentation, code comments, and releases remain English.

Actions include **AirDrop**, **Float**, **Copy Files**, **Move**, **Copy Path**, **Open Terminal**, and **Compress to ZIP**. Float keeps file references for the current session. Compress to ZIP creates one archive beside the first selected item and preserves the originals.

## Format support

| Area | Preview support |
| --- | --- |
| Images and PDF | System image readers/writers; every PDF page to JPG/PNG at 300 DPI; existing PDF text to TXT/MD |
| Audio and video | Inputs supported by macOS to WAV/AIFF/M4A or MP4/MOV |
| Documents and EPUB | Text and rich-text DOCX, PDF/HTML/image export, and simple text-based EPUB reflow |
| Spreadsheets | CSV/TSV/XLSX/ODS, all sheets, values as strings; text-based PDF output |
| Subtitles and archives | SRT/VTT/TXT and ZIP/TAR/TAR.GZ; RAR input where system libarchive supports it |

The [conversion matrix](docs/Conversion-matrix.md) describes the actual routes and remaining targets. The preview does not support PAGES, PPT/PPTX, legacy XLS, textClipping, OCR, editable Office reconstruction from PDF, or GIF conversion in the packaged app. Complex layouts, spreadsheet formulas/styles, and EPUB assets are not preserved. Image writers and media decoders depend on macOS.

The Sandbox app does not include or launch external FFmpeg/FFprobe/LibreOffice. Those tools are optional in unsandboxed developer runs. Cross-volume folder moves are refused; file moves use an original size/mtime check, without content hashing. Oversized PDF pages are rejected rather than rendered below 300 DPI.

## Install with npm

Node.js 20.11+ and a compatible npm version are required. For npm 12, allow this exact release URL and its installation script for this command:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.1/stpashik-yuzu-converter-0.1.1.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
```

Older npm versions can use `npm install -g "$YUZU_PACKAGE_URL"` without those npm 12 options. No global permission settings need to change. The installer checks a pinned SHA-256 and installs the app in `~/Applications`; the package is distributed through GitHub Releases, not the npm registry. The app itself runs without Node.

## Development

Use macOS, Xcode/Swift 5.9+, and Node/npm:

```sh
npm ci --ignore-scripts
npm test
swift test --scratch-path .build/verification
swift run --scratch-path .build/development YuzuApp
```

Build the two archives sequentially, then pin their final checksums and package the installer:

```sh
bash scripts/build-app.sh arm64
bash scripts/build-app.sh x64
node scripts/prepare-npm.mjs dist
npm pack --pack-destination dist
```

Rebuilding an app archive requires rerunning `prepare-npm` and `npm pack`. Developer tool overrides are `YUZU_FFMPEG`, `YUZU_FFPROBE`, and `YUZU_LIBREOFFICE`; they do not extend the packaged Sandbox app. Read the [developer guide](docs/Developer-guide.md) for entry points, file-access ownership, cancellation, localization, and the release checklist.

## Project and verification

The code was written from scratch after [static Tangerine research with REA](docs/TangerineResearch.md). Compress to ZIP is a separate owner-requested feature. The owner authorized reuse of the app/menu bar icons from Yuzu Mac App and an app-icon PNG for documentation only; no old source or Git history was carried over. See [component notices](THIRD_PARTY_NOTICES.md).

**v0.1.1 checks:** 29 Swift tests passed on native arm64 and x86_64 under Rosetta; 13 Node tests passed. Both signed Sandbox apps passed conversion/ZIP self-checks and loaded all five language tables. Localization tests check matching keys, format placeholders, user filenames, fallback, and compact wheel labels. Manual Finder drag, Powerbox/bookmark recovery, AirDrop, Terminal, VoiceOver, shelf drag-out, live language switching/restart, Intel hardware, and macOS 13 checks remain deferred. See [validation](docs/Validation.md), [app QA](docs/QA.md), and [installer QA](docs/NpmQA.md).
