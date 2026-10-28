# Bundled video conversion

Current releases include FFmpeg and FFprobe for both Apple Silicon and Intel. Version 0.4.1 was Apple Silicon only; 0.4.2 restored Intel after native Intel CI and signed Sandbox checks passed. Version 0.5.0 retains the same media engines and codec policy. No Homebrew installation, terminal setup, or separate codec download is required. The app remains a native macOS 13+ Sandbox app.

## What appears in the wheel

Drop a supported MP4, MOV, MKV, WebM, AVI, or WMV file to convert to another of those formats, animated GIF, or MP3 audio. The current format is hidden. MP3 appears only when the input has an audio stream. Animated GIF input can become MP4, MOV, MKV, WebM, AVI, or WMV; it has no audio to extract. For multiple files, the wheel offers the intersection of their available outputs.

AV1 software decoding is not included in this build. A native AVFoundation route, when available for the actual asset, depends on the Mac.

Format names identify containers. The actual codec, damaged data, encryption/DRM, and unusual stream layouts can still prevent conversion. Preserve originals. FFmpeg exports select the first video stream and optional first audio stream; subtitles, attachments, and additional streams are not carried into these outputs. GIF is animated and silent. Its settings control frame rate and maximum width.

Compatible MP4/MOV and PCM/M4A conversions retain the existing native engine. Yuzu can retry MP4/MOV through FFmpeg if VideoToolbox rejects the native export parameters; the same first-video/first-audio stream limits apply. The retry requires safe playback flags and an available encoder, removes only private partial output, and preserves cancellation and original files. Other media routes use the bundled FFmpeg. Native export retains its documented playback-volume and disabled-track policy. When macOS exposes disabled or non-unit-volume source tracks, FFmpeg routes are hidden rather than exposing muted or hidden content; native MP4/MOV routes may remain available. Playback flags in containers macOS cannot read are not independently reconstructed.

FFmpeg encoding uses MPEG-4 Part 2/AAC for fallback MP4/MOV/MKV, MPEG-4 Part 2/MP3 for AVI, VP9/Opus for WebM, WMV2/WMAv2 for WMV, and LAME for MP3. Native MP4/MOV presets remain unchanged. Video outputs use opaque YUV pixels, so source transparency is not preserved. Encodes can be lossy. A filename extension is not a lossless-remux promise. Quality, metadata removal, maximum height, and GIF controls use the existing output-format profiles in [Settings](Settings.md).

## Process and file safety

The app resolves only its own `Contents/Helpers/ffmpeg` and `ffprobe` in a packaged build. An environment variable or Homebrew executable cannot replace them. Both helpers are signed before the app, with exactly the Sandbox and inheritance entitlements described by [Apple's helper-tool documentation](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app).

The parent opens source and private output files while retaining their grants. Helpers receive seekable descriptors on stdin/stdout through FFmpeg's `fd:` protocol. They do not reopen user-selected paths. This avoids depending on inheritance of grants obtained after launch. Runtime conversion/probing accepts only the `fd` protocol; the build has no network protocols or physical capture/output devices. The internal filter input is enabled for automated fixture generation.

Outputs are written exclusively into private staging, validated, and published under an available name. Existing files and originals are preserved. Cancellation terminates the child and discards partial staging. Media encodes can exceed five minutes and run until completion or cancellation; interactive stream probes stop after 15 seconds. Physical Finder/Powerbox integration is still a separate, unverified gate.

## Versions, licenses, and source

| Component | Version | License |
| --- | --- | --- |
| FFmpeg and FFprobe | 9.0.2 | LGPL 2.1 or later; GPL, version-3-only, and nonfree components disabled |
| libvpx | 1.17.0 | BSD license and upstream patent grant |
| Opus | 1.6.1 | BSD license and upstream patent notices |
| LAME | 3.100 | LGPL 2 or later |

This software uses code from [FFmpeg](https://ffmpeg.org/) under LGPL 2.1 or later. [Download the complete corresponding media source package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.0/Yuzu-FFmpeg-Sources-0.5.0.tar.xz). The same GitHub Release hosts the application binaries and source. The package includes the exact upstream archives, checksums, build script, manifest, build configurations, and this guide. No upstream source patches are applied. License/notice copies are in [docs/licenses](licenses) and inside the app's `Contents/Resources/Media-Licenses` folder. Yuzu's own code and npm installer remain MIT; they invoke separate executables rather than link FFmpeg libraries into the application.

The helper executables statically link these codec libraries and have only macOS system runtime dependencies. Source and build instructions are provided so the helpers can be rebuilt, modified, and relinked. There is no restriction on reverse engineering needed to debug modifications to LGPL components. Replacing signed app contents requires signing the modified bundle again; the application build script supports an ad-hoc development signature. A rebuilt helper is not a production update and cannot use the owner's private update-signing key.

## Build from source

Install Xcode command-line tools, Python 3.12+, `make`, `pkg-config`, and `xz`. The build uses the macOS SDK and targets macOS 13.0. The script downloads only the pinned upstream archives and refuses a SHA-256 mismatch. It disables automatic third-party library discovery, preventing accidental Homebrew linkage. Build directories use a temporary path without spaces because upstream makefiles cannot reliably handle spaces. Apple Silicon libvpx uses its ARM target. Intel uses portable C code without a NASM dependency; its WebM encoding may be slower than an assembly-optimized build.

From the Yuzu repository, or the source package's root:

```sh
python3 scripts/build-media.py arm64
python3 scripts/build-media.py x64
```

The source package includes `.build/media-sources` with the four exact archives for an offline rebuild. Release helpers are placed in `.build/media-arm64/Tools` and `.build/media-x64/Tools`. Re-run the media build after changing its source manifest or recipe; remove stale generated tools before packaging. In the full Yuzu repository, `bash scripts/build-app.sh arm64` or `x64` copies and signs the matching helpers. The native app has no Python, pkg-config, or Node runtime dependency.

For release verification, point `YUZU_FFMPEG`/`YUZU_FFPROBE` at the matching newly built tools and set `YUZU_MEDIA_REQUIRED=1` while running Swift tests in an isolated scratch path. The video matrix fixture must run, not skip. Then run each signed app's `--self-check`: this resolves only bundled helpers inside the real Sandbox. [Validation](Validation.md) records actual results and the remaining physical/hardware limits.
