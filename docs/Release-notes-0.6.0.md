# Yuzu Converter 0.6.0

Convert files and run Actions directly from your shelf. Follow work in a new Operations panel, with the same rounded glass appearance as the shelf and native Liquid Glass in the wheel on macOS 26.

## Download

| Mac | Application |
| --- | --- |
| Apple Silicon (M-series) | [Download arm64 ZIP](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.0/Yuzu-Converter-0.6.0-arm64.zip) |
| Intel | [Download x64 ZIP](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.0/Yuzu-Converter-0.6.0-x64.zip) |

Requires **macOS 13 or later**. Existing users can choose **Check for Updates…** from Yuzu's menu or Settings → About and install when ready. Release publication does not install or restart your app.

## What changed

- **Shelf commands:** select rows and use Convert or Actions, also available by right-clicking. Formats come from the same real-file checks as the wheel. All seven Actions are available, including Compress to ZIP and New Shelf with Selection.
- **A clear queue:** conversion, Move, and ZIP run in order. See filenames, completed input counts, waiting/running/finished/error states, Cancel, Cancel All, and Show Results. Closing the panel leaves work running; Show Operations reopens it.
- **Consistent appearance:** Operations replaces the old completion counter and shares the shelf's glass surface. The wheel now uses native Liquid Glass on macOS 26. Earlier macOS versions retain a translucent material; Reduce Transparency and wheel Solid mode remain available.
- **Faster repeat CI builds:** verified architecture/toolchain-specific FFmpeg caches avoid recompiling unchanged media tools. Native Apple Silicon/Intel tests and signed Sandbox archive checks still run.

English is the default. English, Russian, German, French, and Spanish remain available throughout the app-owned interface.

![Operations panel](https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.6.0/docs/images/operations.png)

The preview is an automated render of the opaque accessibility appearance. Native glass is composed by macOS.

## Quick start

1. Unzip the matching download, move **Yuzu Converter.app** to Applications, and launch it. Yuzu appears in the menu bar.
2. Drag files and hold **Shift** for conversion or **Control** for Actions. Drop onto a sector; Escape cancels the wheel.
3. Choose **Show Shelf**, drop files onto it, select rows, and use Convert or Actions. The Finder shortcut is **Control+C** by default and can be changed inside Settings.
4. Follow conversion, Move, or ZIP in **Operations**. Show Results reveals files only when you ask.

Closing a shelf keeps its references for the current session. Clearing shelf rows does not revoke work already submitted. Queue history and shelf contents end when Yuzu exits. Cancellation preserves completed results and does not undo files already moved. A moved original can leave a stale shelf reference; remove that row and add the desired result if needed.

## npm option

The app runs without Node. For a CLI installer, use the [release npm package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.0/stpashik-yuzu-converter-0.6.0.tgz), Node 20.11+, and a compatible npm version. With npm 12:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.0/stpashik-yuzu-converter-0.6.0.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
```

The package is distributed through GitHub Releases, not the npm registry. It verifies pinned archive checksums and installs into `~/Applications`. Older npm versions can omit the two npm 12 allowance options.

## Support, source, and verification

Bundled FFmpeg/FFprobe retain the existing video/container and codec policy: MP4, MOV, MKV, WebM, AVI, WMV, animated GIF, and MP3 extraction where supported by the actual streams. AV1 software decoding is not included. See the [conversion matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.6.0/docs/Conversion-matrix.md) for image, document, spreadsheet, subtitle, archive, and media limits. File tools are outside the scope. Cross-volume folder moves remain unavailable; file moves compare source size/mtime rather than content hashes.

See the [workflow guide](https://github.com/StPashik/Yuzu-converter/blob/v0.6.0/docs/Shelf-workflow.md), [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.6.0/docs/Quick-start.md), [settings](https://github.com/StPashik/Yuzu-converter/blob/v0.6.0/docs/Settings.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.6.0/docs/Validation.md). [Complete corresponding media source](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.0/Yuzu-FFmpeg-Sources-0.6.0.tar.xz), licenses/notices, signed per-architecture appcasts, and SHA256SUMS accompany this release. FFmpeg is provided under LGPL 2.1 or later.

Both archives use ad hoc signatures and have no Developer ID or Apple notarization; Gatekeeper may block a first launch. Physical Finder/Powerbox, external-file Sandbox integrations, system Actions, VoiceOver, macOS 13, and macOS 26 Intel appearance remain unverified. Automated fixture and native CI results are recorded separately in validation.
