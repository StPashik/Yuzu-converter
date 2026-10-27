# Yuzu Converter 0.3.0 — Settings and Conversion Profiles

A new five-tab Settings window puts wheel behavior, conversion defaults, compatibility, and folder access in one place. The layout follows the Tangerine reference, with Yuzu's own code and five interface languages.

## Download

Requires **macOS 13 or later**.

| Your Mac | Direct download |
| --- | --- |
| Apple Silicon | [Yuzu Converter 0.3.0 — arm64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/Yuzu-Converter-0.3.0-arm64.zip) |
| Intel | [Yuzu Converter 0.3.0 — x64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/Yuzu-Converter-0.3.0-x64.zip) |
| npm installer | [Version-pinned package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/stpashik-yuzu-converter-0.3.0.tgz) |

Unzip the app, move it to Applications, and launch it. Existing users can choose **Check for Updates…** from the Yuzu menu.

## Quick start

1. Drag a file and hold **Shift** for conversion or **Control** for Actions.
2. Drop onto a format or action; **Escape** cancels.
3. Open **Settings…** to choose shortcuts or output defaults. Results are saved beside the originals under an available name.

For npm 12, allow the exact release URL and its install script for this command:

~~~sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/stpashik-yuzu-converter-0.3.0.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
~~~

Node.js 20.11+ is required for npm installation. Earlier npm versions can omit the two allowance flags. The native app runs without Node.

## New in Settings

- **General:** Glass/Solid wheel surfaces, launch at login with actual macOS approval status, system sound/haptics, independent modifier combinations, five languages, Float behavior, and Terminal/iTerm2.
- **Formats:** per-output defaults for supported image quality/metadata, audio bitrate/PCM depth, video quality/height, archive compression, and EPUB 2/3.
- **Compatibility:** Yuzu's current backend availability, including media routes that depend on the actual input.
- **Folders:** add or forget Yuzu's own folder grants, including safely contained descendants.
- **About:** version, documentation, releases, and the shared manual update check.

Queued jobs keep their original settings. Existing swapped Shift/Control preferences migrate; conflicting shortcut assignments swap so both wheels remain reachable. Compress to ZIP uses the ZIP compression profile and preserves originals.

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.3.0/docs/images/settings-formats-dark.png" width="620" alt="Yuzu output-format settings in dark appearance">

*Native development preview. Available routes depend on the app's backends; the packaged app does not use external encoders.*

## Encoding choices and support

Compact/Balanced/High image quality maps to 0.65/0.9/1.0. Automatic compressed-audio bitrate maps to 96/192/256 kbit/s; an explicit bitrate takes precedence. Archive compression uses levels 1/6/9. Native video uses system Low/Medium/Highest presets: **Balanced now uses Medium**, while High selects Highest.

The packaged app continues to offer system-supported image, document, spreadsheet, subtitle, archive, and native media routes. PDF image output still processes every page at 300 DPI. PCM match-source preserves supported sample depth or rejects it; unsupported 64-bit float is not silently truncated.

Original-page EPUB, editable PDF-to-Office reconstruction, PAGES, slides/legacy XLS, OCR, textClipping, and packaged GIF encoding remain unavailable. Disabled settings explain these limits. Complex document layout, spreadsheet formulas/styles, and EPUB assets are not preserved. File tools and purchase/account features remain outside scope.

## Verification

- 61 Swift tests passed on Apple Silicon and 61 under Rosetta, with no failures or skips.
- 16 installer tests passed, including upgrade from 0.2.1 and preservation of newer installations.
- Native previews cover all five tabs, five languages, both appearances, and relevant format editors.
- Output fixtures check metadata removal, orientation/color, exact Int32 PCM samples, media size/bitrate, disabled tracks and actual mute/reduced gain, ZIP/TAR.GZ compression, EPUB versions, and unchanged originals.
- Both signed Sandbox apps passed their self-checks, including a metadata-off image profile and maximum ZIP compression.

These are **ad hoc signed previews without Developer ID or notarization**; Gatekeeper may block first launch. Physical Finder/Powerbox recovery, ancestor-bookmark derivation, login-item approval, real terminal/AirDrop use, haptics/VoiceOver, Intel hardware, macOS 13, and a full interactive Sparkle installation remain unverified.

Read the [Settings guide](https://github.com/StPashik/Yuzu-converter/blob/v0.3.0/docs/Settings.md), [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.3.0/docs/Quick-start.md), [format matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.3.0/docs/Conversion-matrix.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.3.0/docs/Validation.md).

The release includes architecture-specific signed update feeds, SHA-256 checksums, the npm package, and applicable license notices. The update signing key remains in the owner's Keychain. No Tangerine artwork, sounds, code, binaries, settings, or grants are distributed.
