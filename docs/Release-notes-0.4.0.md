# Yuzu Converter 0.4.0 — Video Conversion Built In

Video conversion now works without a separate FFmpeg installation. Both Mac builds include FFmpeg and FFprobe, so MKV, WebM, AVI, WMV, animated GIF, and MP3 extraction can appear alongside MP4/MOV in the conversion wheel.

## Download

Requires **macOS 13 or later**.

| Your Mac | Direct download |
| --- | --- |
| Apple Silicon | [Yuzu Converter 0.4.0 — arm64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.0/Yuzu-Converter-0.4.0-arm64.zip) |
| Intel | [Yuzu Converter 0.4.0 — x64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.0/Yuzu-Converter-0.4.0-x64.zip) |
| npm installer | [Version-pinned package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.0/stpashik-yuzu-converter-0.4.0.tgz) |

This software uses FFmpeg under LGPL 2.1 or later. [Complete corresponding media source, configuration records, and build instructions](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.0/Yuzu-FFmpeg-Sources-0.4.0.tar.xz) accompany the binaries. Upstream license/notice copies are included inside each app.

Unzip the app, move it to Applications, and launch it. Existing users can choose **Check for Updates…** from the Yuzu menu or **Settings → About**.

## Quick start

1. Drag a video and hold **Shift**.
2. Drop onto a format. The current format is hidden; MP3 appears only when the video has audio.
3. Use **Settings → Formats** to choose quality, maximum video height, metadata policy, or GIF frame rate/width. Results use an available name beside the originals.

Hold **Control** for the seven Actions, including **Compress to ZIP**. **Escape** cancels wheel selection. Five interface languages and existing preferences remain supported.

For npm 12:

~~~sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.0/stpashik-yuzu-converter-0.4.0.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
~~~

Node.js 20.11+ is required for npm installation; earlier npm versions can omit the two allowance flags. The app itself needs neither Node nor Homebrew.

## Supported video routes

- **MP4, MOV, MKV, WebM, AVI, WMV:** convert to another listed video container, animated GIF, or MP3 audio.
- **Animated GIF:** convert to MP4, MOV, MKV, WebM, AVI, or WMV. GIF exports are animated and silent.
- **Multiple inputs:** the wheel offers only common available outputs.

Compatible native MP4/MOV and PCM/M4A routes keep their existing system engine. Other routes use the bundled FFmpeg 9.0.2 with libvpx 1.17.0, Opus 1.6.1, and LAME 3.100. This also enables applicable MP3, FLAC, Opus, and WMA audio output. OGG encoding still needs an additional developer encoder.

The helpers are signed to inherit the app Sandbox and receive already-open, seekable files. Runtime conversion cannot follow external paths or network protocols. Cancellation stops the encoder and discards partial staging; longer videos are no longer limited by the diagnostic-probe timeout. Originals and existing outputs are preserved.

## Verification

- **64 Swift tests on Apple Silicon and 64 under Rosetta**, with no failures or skips.
- **48 directed media routes** checked with real stream/frame counts and complete output decoding.
- **16 installer tests**, including upgrades and preservation of newer installations.
- Both final ZIPs independently unpacked and inspected for CPU, macOS target, deep code signatures, helper entitlements, source/license bytes, and five-language resources.
- Both signed apps passed real Sandbox conversion/probe/decode checks with external media overrides deliberately invalid, followed by installation checks in temporary homes.
- Signed update archives and feeds use build **7** and version **0.4.0**; the release includes SHA-256 checksums and corresponding source.

## Known limits

FFmpeg outputs use the first video and optional first audio stream. Additional streams, subtitles, attachments, and video transparency are not preserved. These are encoded conversions, not a promise of lossless remuxing. Known disabled/non-unit-volume QuickTime tracks hide FFmpeg routes so muted or hidden content is not exposed; compatible native routes remain available. Playback flags in containers macOS cannot read are not reconstructed. AV1 software decoding is not included; native decoding, when available for the actual file, depends on the Mac. DRM, damaged files, and other unsupported codec profiles may fail. Intel WebM encoding uses portable C and may be slower than an assembly-optimized build.

The existing document/Office limitations remain in the [format matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.4.0/docs/Conversion-matrix.md). File tools remain outside scope.

These are **ad hoc signed previews without Developer ID or Apple notarization**; Gatekeeper may block first launch. Physical Finder/Powerbox, VoiceOver, real Intel hardware, macOS 13, external services, and a full interactive Sparkle install/relaunch remain unverified.

Read the [video and source guide](https://github.com/StPashik/Yuzu-converter/blob/v0.4.0/docs/Bundled-media.md), [Settings guide](https://github.com/StPashik/Yuzu-converter/blob/v0.4.0/docs/Settings.md), [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.4.0/docs/Quick-start.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.4.0/docs/Validation.md).
