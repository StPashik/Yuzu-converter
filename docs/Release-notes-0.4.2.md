# Yuzu Converter 0.4.2 — Intel Support Restored

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.4.2/docs/images/app-icon.png" width="96" alt="Yuzu Converter icon">

Intel builds are back. Yuzu now recovers MP4/MOV conversions when the native macOS video engine rejects a supported export profile, using its bundled software encoder for compatible sources. Apple Silicon remains supported with the same conversion and seven Actions, including Compress to ZIP.

## Update when you are ready

Choose **Check for Updates…** in the Yuzu menu or **Settings → About**. Apple Silicon users can update from 0.4.1; Intel users can update directly from 0.4.0. Version 0.4.1 had no Intel build. Downloads and installation require your action, and active file jobs finish before restart. Publishing this release does not install or restart your app.

Both architecture-specific feeds and archives use the existing Yuzu update-signing key. New apps use the signed feed attached to GitHub Latest. Legacy bridge feeds advance only after compatible downloads are public.

## Downloads and quick start

Requires **macOS 13 or later**.

| Your Mac | Direct download |
| --- | --- |
| Apple Silicon | [Yuzu Converter 0.4.2 — arm64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.2/Yuzu-Converter-0.4.2-arm64.zip) |
| Intel | [Yuzu Converter 0.4.2 — x64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.2/Yuzu-Converter-0.4.2-x64.zip) |
| npm installer | [Version-pinned package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.2/stpashik-yuzu-converter-0.4.2.tgz) |

Unzip the matching app, move it to Applications, and launch it. Drag a file, hold **Shift** for Conversion or **Control** for Actions, then drop onto the wheel.

For npm 12 with Node.js 20.11+:

~~~sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.2/stpashik-yuzu-converter-0.4.2.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
~~~

Older npm versions can omit the allowance flags. The package selects the pinned app for the running Node architecture; unsupported CPUs are rejected before a download or replacement. The native app requires neither Node nor Homebrew.

This software uses FFmpeg under LGPL 2.1 or later. [Complete corresponding media source, build instructions, and both CPU configuration records](https://github.com/StPashik/Yuzu-converter/releases/download/v0.4.2/Yuzu-FFmpeg-Sources-0.4.2.tar.xz) accompany the binaries. License notices are included in both apps; SHA-256 checksums are supplied with the release.

## What changed

- Native Intel and Apple Silicon builds are independently checked in CI, including the actual signed Sandbox app.
- The native video export can pass preflight and still reject its requested parameters. Yuzu retries the observed failure through FFmpeg after removing only private partial output.
- Retry requires a capable encoder and safe playback flags. Cancellation, unrelated errors, disabled tracks, and non-unit audio gain retain their existing safeguards. Originals and existing files remain protected.

The software route follows the existing FFmpeg codec and stream policy: first video and optional first audio, without extra tracks, subtitles, attachments, or transparency. AV1 software decoding is not included. Native availability still depends on the Mac and actual file. File tools remain outside scope; document/Office limitations are unchanged.

## Verification and limits

The fix passed 66 Swift tests on native Intel and Apple Silicon, plus both signed Sandbox checks, including the former MPEG-4 MOV → MP4 failure, frame dimensions, actual decoding, and return conversion. Separate installer, final archive, source/license, and signing checks are recorded in the validation guide.

The apps remain **ad-hoc signed without Developer ID or Apple notarization**; Gatekeeper may block first launch. Native Intel CI runs on macOS 15 and Apple Silicon CI on macOS 26. Physical Finder/Powerbox, VoiceOver, macOS 13, macOS 26 Intel UI behavior, and a full interactive Intel updater installation remain unverified.

Read the [Intel diagnosis and safeguards](https://github.com/StPashik/Yuzu-converter/blob/v0.4.2/docs/Intel-compatibility.md), [format matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.4.2/docs/Conversion-matrix.md), [update guide](https://github.com/StPashik/Yuzu-converter/blob/v0.4.2/docs/Updates.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.4.2/docs/Validation.md).
