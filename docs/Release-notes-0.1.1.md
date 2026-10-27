<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.1.1/docs/images/app-icon.png" width="112" alt="Yuzu Converter icon">

# Yuzu Converter 0.1.1

**Convert files and use everyday file actions from your Mac's menu bar.**

Preview · macOS 13+ · Apple Silicon & Intel

## Download

| Apple Silicon | Intel |
| --- | --- |
| [Download for M-series Macs](https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.1/Yuzu-Converter-0.1.1-arm64.zip) | [Download for Intel Macs](https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.1/Yuzu-Converter-0.1.1-x64.zip) |

Open the ZIP, move **Yuzu Converter.app** to Applications, and launch it. Look for the Yuzu icon in the menu bar.

<details>
<summary>Install with npm</summary>

For npm 12:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.1/stpashik-yuzu-converter-0.1.1.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
```

For npm 10/11, use `npm install -g` with the same URL. Requires Node.js 20.11+. The installer verifies a pinned SHA-256 and installs the app in `~/Applications`.

</details>

## One drag, two wheels

1. **Drag + Shift** to choose a conversion format.
2. **Drag + Control** for AirDrop, Float, Copy, Move, Copy Path, Terminal, or ZIP.
3. Drop on a sector to run it. **Escape** cancels selection.

Shortcuts can be swapped in Settings. Results use an available filename beside the original. **ZIP** combines selected files and folders into one archive while preserving the originals. File tools remain outside this release.

## What's improved

- Five interface languages: **English** (default), **Russian**, **German**, **French**, and **Spanish**. Choose **Settings… → Language**; app-owned text updates immediately.
- English documentation, developer comments, and release content, with translated accessibility hints and operation messages.
- The Yuzu Mac App application and menu bar icons, reused at the owner's request.
- A concise [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/Quick-start.md), format support guide, and clear npm 12 instructions.
- Code comments explaining file-safety, Sandbox, staging, and cancellation decisions.

Common image, native audio/video, PDF-page, text/DOCX/EPUB, values-only spreadsheet, subtitle, and archive routes are available. See the [format support matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/Conversion-matrix.md) for exact limits.

## Preview notes

**Ad-hoc signed; Apple notarization is not included.** macOS may block the first launch. The [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/Quick-start.md) links to Apple's guidance.

PAGES, PowerPoint, legacy XLS, OCR, PDF-to-editable-Office, GIF conversion, and additional media encoders are unavailable. Tables export values without formulas or styling; complex document layout and embedded objects are not fully preserved. Cross-volume folder moves are refused. The Sandbox app includes no external FFmpeg or LibreOffice.

Physical Finder drag, Powerbox/bookmark recovery, VoiceOver during drag, AirDrop, Terminal, and shelf drag-out checks remain deferred. Intel hardware and macOS 13 were not tested directly.

Technical converter diagnostics remain English. Some system dialogs use a new language after restarting the app.

## Documentation and verification

[Quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/Quick-start.md) · [Format support](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/Conversion-matrix.md) · [Validation](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/Validation.md) · [REA investigation](https://github.com/StPashik/Yuzu-converter/blob/v0.1.1/docs/TangerineResearch.md)

**Verified:** 29 Swift tests on Apple Silicon and x86_64 through Rosetta, 13 installer tests, five complete translation tables, and self-checks of both signed Sandbox apps. Downloads include app ZIPs, the npm package, SHA256SUMS, and license notices.
