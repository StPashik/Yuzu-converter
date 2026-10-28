# Yuzu Converter 0.5.1 — Shelf Shortcuts and Reliable Reopening

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.5.1/docs/images/app-icon.png" width="80" alt="Yuzu Converter icon">

Add selected Finder files to your shelf with **⌃C**, or record your own shortcut directly in Yuzu. Closing a shelf now keeps its files available for **Show Shelf** throughout the current app session.

## Your shortcut, inside Yuzu

Open **Settings → General → Actions → Add Finder selection to shelf**, click the field, and press your preferred keys. **Escape** cancels recording; **Delete** disables the shortcut. Use a letter, number, Space, or F-key with Control, or Command plus another modifier. An unavailable combination leaves your previous choice intact.

The shortcut is active only while Finder is frontmost and follows **Float Behaviour**: add to the existing collection or create a new shelf. It preserves your clipboard. The default is **Control+C**. Outside Finder, other apps retain their normal shortcuts, including Control+C to interrupt a Terminal command.

First use can ask for permission to read Finder’s selection. The Sandbox build also asks for the selected files’ parent folder on first use, then restores remembered access. Each batch owns its grant independently, so clearing another shelf cannot revoke it. Cancelling leaves the shelf unchanged. Keyboard recording, hints, and permission explanations support English, Russian, German, French, and Spanish.

<img src="https://raw.githubusercontent.com/StPashik/Yuzu-converter/v0.5.1/docs/images/settings-shelf-shortcut-dark.png" width="660" alt="Yuzu General settings with the shelf shortcut recorder">

*Development render scrolled to Actions; physical Finder/Automation/Powerbox approval remains unverified.*

## Close and reopen without losing the list

- The close button and **Escape** hide a shelf while retaining its file references and grants.
- **Show Shelf** restores every retained collection, including independent closed shelves.
- **Float** can append to the latest hidden shelf when adding to the existing collection is enabled.
- Pending previews are cancelled on close and requested again when needed after reopening. Completed previews and original files are preserved.
- **Remove** and **Clear Shelf** explicitly remove references. Closing a window does not clear the list.

Shelf contents last **until you exit Yuzu**. They are not saved across app launches or an update’s restart. References already cleared by 0.5.0 must be added again; original files were never deleted.

## Update when you are ready

Choose **Check for Updates…** in the Yuzu menu or **Settings → About**. Both CPU-specific feeds use the existing Yuzu update-signing key. Downloading and installation require your confirmation; active file jobs and an in-progress shelf selection finish before restart. Publishing this release does not install or restart your app.

## Downloads and quick start

Requires **macOS 13 or later**.

| Your Mac | Direct download |
| --- | --- |
| Apple Silicon | [Yuzu Converter 0.5.1 — arm64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.1/Yuzu-Converter-0.5.1-arm64.zip) |
| Intel | [Yuzu Converter 0.5.1 — x64](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.1/Yuzu-Converter-0.5.1-x64.zip) |
| npm installer | [Version-pinned package](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.1/stpashik-yuzu-converter-0.5.1.tgz) |

Unzip the matching app, move it to Applications, and launch it. Select files in Finder and press **⌃C**, or choose **Show Shelf** and drop files onto the panel. Close the window and use **Show Shelf** to restore its contents. Hold **Shift** while dragging files for conversion or **Control** for Actions.

For npm 12 with Node.js 20.11+:

~~~sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.1/stpashik-yuzu-converter-0.5.1.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
~~~

Older npm versions can omit the allowance flags. The package selects the pinned archive for the running Node architecture and verifies its SHA-256 before replacement. The native app needs neither Node nor Homebrew.

This software uses FFmpeg under LGPL 2.1 or later. [Complete corresponding media source and both CPU build configurations](https://github.com/StPashik/Yuzu-converter/releases/download/v0.5.1/Yuzu-FFmpeg-Sources-0.5.1.tar.xz), license notices, and checksums accompany the release. Codec, stream, document, and metadata limits are unchanged; File tools remain outside scope.

## Verification and limits

The suite includes **78 Swift tests** and **22 installer/feed tests**, with native Apple Silicon and Intel CI plus both signed Sandbox media self-checks. The new retention regression failed eight assertions before the fix. Shortcut checks cover real native registration conflicts/release, replacement/disable/cancel, saved preferences, real aliases and Unicode paths, file-only validation, and visible settings controls in all five languages and both appearances. The release archives include the checked Finder-only Apple-event exception and localized permission explanations.

Builds remain **ad-hoc signed without Developer ID or Apple notarization**; Gatekeeper may block first launch. Physical Finder selection, Automation approval/denial, Powerbox recovery, VoiceOver, macOS 13, macOS 26 Intel appearance, external-file Sandbox Quick Look, and a full interactive updater installation remain unverified. Native CI runs on macOS 26 Apple Silicon and macOS 15 Intel; both release archives use Xcode 26 with a weak native-glass import and the macOS 13 fallback.

Read the [shelf guide](https://github.com/StPashik/Yuzu-converter/blob/v0.5.1/docs/Shelf-design.md), [shortcut settings](https://github.com/StPashik/Yuzu-converter/blob/v0.5.1/docs/Settings.md), [quick start](https://github.com/StPashik/Yuzu-converter/blob/v0.5.1/docs/Quick-start.md), [format matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.5.1/docs/Conversion-matrix.md), and [validation record](https://github.com/StPashik/Yuzu-converter/blob/v0.5.1/docs/Validation.md).
