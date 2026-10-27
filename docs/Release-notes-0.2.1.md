<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.2.1/docs/images/app-icon.png" width="112" alt="Yuzu Converter icon">

# Yuzu Converter 0.2.1

**Convert files and use everyday file actions from your Mac's menu bar.**

Preview · macOS 13+ · Apple Silicon & Intel

## Download

| Apple Silicon | Intel |
| --- | --- |
| [Download for M-series Macs](https://github.com/StPashik/Yuzu-converter/releases/download/v0.2.1/Yuzu-Converter-0.2.1-arm64.zip) | [Download for Intel Macs](https://github.com/StPashik/Yuzu-converter/releases/download/v0.2.1/Yuzu-Converter-0.2.1-x64.zip) |

Open the ZIP, move **Yuzu Converter.app** to Applications, and launch it. Look for the Yuzu icon in the menu bar.

<details>
<summary>Install with npm</summary>

For npm 12:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.2.1/stpashik-yuzu-converter-0.2.1.tgz"
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

## The Yuzu wheel design

The conversion and Actions wheels now follow the owner's Yuzu Mac App design:

- Rounded, translucent petals with a constant gap and soft shadows.
- Orange selection with white text, larger text-only format labels, and SF Symbols for Actions.
- A three-line center keeps the source name/format, current instruction, and shortcut hint visible.
- The first option starts at the top. Light/dark appearance follows macOS, and the content fade respects Reduce Motion.

The same rounded paths are used for drawing and drag selection. Conversion routes, seven Actions including ZIP, access grants, five languages, and signed in-app updates remain available.

| Actions · Light | Conversion · Dark |
| --- | --- |
| <img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.2.1/docs/images/wheel-actions-light.png" width="280" alt="Rounded Actions wheel in light appearance"> | <img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.2.1/docs/images/wheel-conversion-dark.png" width="280" alt="Rounded conversion wheel in dark appearance"> |

AppKit-rendered previews. See the [design notes](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/Wheel-design.md) for dimensions and verification limits.

**Already on 0.2.0?** Choose **Check for Updates…** from the menu bar or Settings, then confirm download and installation. If you have 0.1.2 or earlier, install this release once using a direct download or npm. Updates apply to the running copy of the app.

Common image, native audio/video, PDF-page, text/DOCX/EPUB, values-only spreadsheet, subtitle, and archive routes are available. See the [format support matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/Conversion-matrix.md) for exact limits.

## Preview notes

**Ad-hoc signed; Apple notarization is not included.** macOS may block the first launch. The [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/Quick-start.md) links to Apple's guidance.

PAGES, PowerPoint, legacy XLS, OCR, PDF-to-editable-Office, GIF conversion, and additional media encoders are unavailable. Tables export values without formulas or styling; complex document layout and embedded objects are not fully preserved. Cross-volume folder moves are refused. The Sandbox app includes no external FFmpeg or LibreOffice.

A full interactive update installation/relaunch and physical Finder drag, Powerbox/bookmark recovery, VoiceOver during drag, AirDrop, Terminal, and shelf drag-out checks remain deferred. Intel hardware and macOS 13 were not tested directly.

Technical converter diagnostics remain English. Some system dialogs use a new language after restarting the app.

## Documentation and verification

[Quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/Quick-start.md) · [Format support](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/Conversion-matrix.md) · [Validation](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/Validation.md) · [REA investigation](https://github.com/StPashik/Yuzu-converter/blob/v0.2.1/docs/TangerineResearch.md)

**Verified:** 36 Swift tests on Apple Silicon and x86_64 through Rosetta, 16 installer tests, rounded hit regions, option-switching, queue/cancellation and wheel regressions, five complete translation tables, and self-checks of both signed Sandbox apps. Downloads include app ZIPs, the npm package, signed update feeds, SHA256SUMS, and license notices. Sparkle 2.10.1 and its component license notices are bundled.
