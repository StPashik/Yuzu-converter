# Yuzu Converter 0.7.1

See available updates when Yuzu starts, and decide when to install.

## What changed

- **Automatic checking at launch.** Yuzu checks quietly when it starts and about once a day while running. A new version opens Sparkle's standard offer with English Release Notes. Current-version and background network failures stay quiet.
- **A saved Settings checkbox.** Settings → About now includes **Check for updates automatically**, translated into all five app languages. It defaults on; turning it off disables future startup/scheduled checks. Manual **Check for Updates…** remains available.
- **Your installation choice.** Choose **Install Update**, **Remind Me Later**, or **Skip This Version**. Closing the offer dismisses it without installing. Downloads and installation still require confirmation, and active file jobs finish before restart.

## Updating once

Use **Check for Updates…** in your current Yuzu to install 0.7.1 when ready. Startup checking becomes available after that update; older binaries do not gain this behavior from a feed change alone. Release publication does not install or restart your copy.

With automatic checking enabled, Remind Me Later or closing the offer can show it again on a later launch or scheduled check (normally daily). Skip This Version suppresses that specific version until a manual check or a newer release. An explicitly saved checking preference is honored during upgrades.

## Downloads and documentation

Requires macOS 13 or later. Choose your architecture:

- [Apple Silicon app](https://github.com/StPashik/Yuzu-converter/releases/download/v0.7.1/Yuzu-Converter-0.7.1-arm64.zip)
- [Intel app](https://github.com/StPashik/Yuzu-converter/releases/download/v0.7.1/Yuzu-Converter-0.7.1-x64.zip)
- [npm installer](https://github.com/StPashik/Yuzu-converter/releases/download/v0.7.1/stpashik-yuzu-converter-0.7.1.tgz) · [Checksums](https://github.com/StPashik/Yuzu-converter/releases/download/v0.7.1/SHA256SUMS)
- [Complete corresponding media source](https://github.com/StPashik/Yuzu-converter/releases/download/v0.7.1/Yuzu-FFmpeg-Sources-0.7.1.tar.xz) · [Component notices](https://github.com/StPashik/Yuzu-converter/releases/download/v0.7.1/THIRD_PARTY_NOTICES.md)

For a first installation, unzip and move the app to Applications. See the [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.7.1/docs/Quick-start.md), [update guide](https://github.com/StPashik/Yuzu-converter/blob/v0.7.1/docs/Updates.md), and [Settings guide](https://github.com/StPashik/Yuzu-converter/blob/v0.7.1/docs/Settings.md).

## Validation and limits

Automated checks cover signed-feed background/manual behavior, saved disable/re-enable preferences, dismiss/skip/manual recovery, quiet errors, and no download without consent. Both native CI jobs run these isolated HTTP fixtures alongside Swift/Node tests and signed Sandbox archives. [Validation](https://github.com/StPashik/Yuzu-converter/blob/v0.7.1/docs/Validation.md) records actual results and deferred gates.

Physical startup-dialog interaction, an actual interactive installation/relaunch, macOS 13, VoiceOver, and other-Mac checks remain unverified. App/helper signatures remain ad hoc, without Developer ID or notarization; Gatekeeper may block first launch. Existing conversion and media codec limits remain documented. No conversion engines, signing keys, or historical release assets change in this patch.
