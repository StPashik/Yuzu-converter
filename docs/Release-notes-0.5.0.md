# Yuzu Converter 0.5.0 — A Glass Shelf for Your Menu Bar

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.5.0/docs/images/app-icon.png" width="80" alt="Yuzu Converter icon">

Keep files close at hand in a compact shelf below the Yuzu menu bar icon. Native Liquid Glass, file previews, and a layout that grows with your files replace the oversized floating table. Conversion and all seven Actions remain available on Apple Silicon and Intel.

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.5.0/docs/images/shelf-glass.png" width="460" alt="The Yuzu shelf with file previews and native Liquid Glass over a synthetic test backdrop">

## Try the new shelf

1. Choose **Show Shelf** from the Yuzu menu, then drop files onto the panel. You can also hold **Control** while dragging and choose **Float**.
2. Drag a row into another app when you need the file. Previews fall back to familiar system icons when unavailable.
3. Remove a row, clear the shelf, or close it when finished. These controls remove references; your original files stay where they are.

One file uses a 368 × 180-point panel. The shelf grows through five rows, then scrolls. It stays available while Finder or another app is active, and the existing add-to-current/new-shelf preference still applies. All shelf text supports English, Russian, German, French, and Spanish.

Liquid Glass is used on **macOS 26 or later**. macOS 13–15 use the native translucent popover material. **Reduce Transparency** switches to an opaque surface while preserving the current files and selection. The screenshot above is a real native capture with synthetic sample files and a synthetic backdrop; it contains no private user content.

## Update when you are ready

Choose **Check for Updates…** in the Yuzu menu or **Settings → About**. Both architecture-specific feeds use the existing Yuzu signing key. Downloading and installation require your action; active file jobs finish before restart. Publishing this release does not install or restart your app.

## Downloads and quick start

Requires **macOS 13 or later**.

| Your Mac | Direct download |
| --- | --- |
| Apple Silicon | [Yuzu Converter 0.5.0 — arm64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.0/Yuzu-Converter-0.5.0-arm64.zip) |
| Intel | [Yuzu Converter 0.5.0 — x64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.0/Yuzu-Converter-0.5.0-x64.zip) |
| npm installer | [Version-pinned package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.0/stpashik-yuzu-converter-0.5.0.tgz) |

Unzip the matching app, move it to Applications, and launch it. Use **Show Shelf**, or drag a file while holding **Shift** for Conversion and **Control** for Actions.

For npm 12 with Node.js 20.11+:

~~~sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.0/stpashik-yuzu-converter-0.5.0.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
~~~

Older npm versions can omit the allowance flags. The package checks a pinned SHA-256 and selects the archive for the running Node architecture. The native app requires neither Node nor Homebrew.

FFmpeg and FFprobe remain bundled for both CPUs. This software uses FFmpeg under LGPL 2.1 or later; [complete corresponding source and both CPU configurations](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.0/Yuzu-FFmpeg-Sources-0.5.0.tar.xz), license notices, and SHA-256 checksums accompany the release. Conversion support and its existing stream, codec, document, and metadata limits are unchanged. File tools remain outside scope.

## Verification and limits

The automated suite includes 70 Swift tests, 22 installer/feed tests, both signed Sandbox apps, and four shelf regressions covering geometry, drag callbacks, source preservation, material/selection changes, and 18 layout snapshots. The native glass appearance was additionally captured in an isolated macOS 26 Apple Silicon fixture. See the validation record for per-CPU CI and final archive results.

Builds remain **ad-hoc signed without Developer ID or Apple notarization**; Gatekeeper may block first launch. Physical Finder/Powerbox, VoiceOver, macOS 13, macOS 26 Intel appearance, external-file Sandbox Quick Look, and a full interactive updater installation remain unverified. Intel CI uses macOS 15 with its older SDK/material fallback; both release archives are built with Xcode 26 to include the native glass implementation.

Read the [shelf design and ownership guide](https://github.com/StPashik/Yuzu-converter/blob/v0.5.0/docs/Shelf-design.md), [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.5.0/docs/Quick-start.md), [format matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.5.0/docs/Conversion-matrix.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.5.0/docs/Validation.md).
