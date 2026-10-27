# Yuzu Converter 0.4.1 — Stable Updates for Apple Silicon

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.4.1/docs/images/app-icon.png" width="96" alt="Yuzu Converter icon">

Yuzu now publishes normal GitHub Latest releases through pull requests and independent CI. Updates remain your choice: publication does not replace your installed app or restart it.

## Update from an installed version

Choose **Check for Updates…** in the Yuzu menu or **Settings → About**. Accept the download and installation when you are ready. Active file jobs finish before restart. The existing update-signing key is preserved, including the Apple Silicon compatibility feed used by versions through 0.4.0.

New builds read the signed arm64 appcast from the Latest release. Its feed and versioned archives are public together. The older arm64 main/updates bridge advances only after those assets are available. Intel remains on its exact 0.4.0 feed, and the new npm installer rejects Intel before downloading or replacing an app. Automatic checks, background installation, and system profiling remain disabled.

## First installation

Requires **Apple Silicon (M1 or later) and macOS 13 or later**. New releases target arm64 only; [0.4.0](https://github.com/StPashik/Yuzu-converter/releases/tag/v0.4.0) remains the final Intel release and its update feed stays unchanged.

| Your Mac | Direct download |
| --- | --- |
| Apple Silicon | [Yuzu Converter 0.4.1 — arm64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.1/Yuzu-Converter-0.4.1-arm64.zip) |
| npm installer | [Version-pinned package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.1/stpashik-yuzu-converter-0.4.1.tgz) |

This software uses FFmpeg under LGPL 2.1 or later. [Complete corresponding media source and build instructions](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.1/Yuzu-FFmpeg-Sources-0.4.1.tar.xz) accompany the binaries. License notices are included inside the app.

Unzip the selected app, move it to Applications, and launch it. For npm 12, Node.js 20.11+ is required:

~~~sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.1/stpashik-yuzu-converter-0.4.1.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
~~~

Earlier npm versions can omit the allowance flags. Existing users can use the in-app update button instead of reinstalling. The native app requires neither Node nor Homebrew.

## Release process

Feature PRs target develop; release PRs target main, and their exact merge commits receive immutable version tags. Release changes return to develop through another PR. CI validates GitFlow routes, signed-feed metadata, the native Apple Silicon build, and isolated installer/Sandbox checks. CI has no production signing key and cannot publish or install for the owner.

Prerelease status is reserved for an explicitly requested beta/RC. Normal releases are Latest releases; ad-hoc signing and missing Apple notarization are documented separately. Historical tags and assets are preserved.

## Verification

- 64 Swift tests, including all 48 media routes, and 21 Node tests passed on Apple Silicon without skips.
- The final ZIP passed strict signatures, exact arm64 executable/helper checks, license/resource comparisons, and real Sandbox media conversions.
- Temporary-home installation, production-key archive/feed signatures, and four information-only Sparkle HTTP fixtures passed. No owner app was installed or restarted.
- The release includes SHA-256 checksums and the exact media source/configuration package. The retired Intel feed is pinned to its original signed 0.4.0 bytes.

## Conversion support and limits

Conversion and the seven Actions retain the 0.4.0 behavior, including bundled FFmpeg/FFprobe and ZIP compression. File tools remain outside scope. MP4/MOV/MKV/WebM/AVI/WMV/GIF and MP3 extraction retain their documented stream/codec limits. AV1 software decoding is not included; native availability depends on the Mac and actual file. Additional tracks, subtitles, attachments, and video transparency are not preserved in FFmpeg outputs.

The build remains **ad-hoc signed without Developer ID or Apple notarization**. Gatekeeper may block first launch. Physical Finder/Powerbox, VoiceOver, macOS 13, and a full owner-driven Sparkle installation remain unverified until performed. This release does not claim new conversion features or complete codec coverage.

Read the [release workflow](https://github.com/StPashik/Yuzu-converter/blob/v0.4.1/docs/Releasing.md), [update guide](https://github.com/StPashik/Yuzu-converter/blob/v0.4.1/docs/Updates.md), [format matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.4.1/docs/Conversion-matrix.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.4.1/docs/Validation.md).
