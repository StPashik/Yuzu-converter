# Quick start

Yuzu Converter lives in your Mac's menu bar. Drag a file, hold a shortcut key, and drop it on the format or action you need.

## Install

| Your Mac | Download |
| --- | --- |
| Apple Silicon: M1, M2, M3, M4, or newer | [Apple Silicon app](https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/Yuzu-Converter-0.3.0-arm64.zip) |
| Intel | [Intel app](https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/Yuzu-Converter-0.3.0-x64.zip) |

Open the ZIP and move **Yuzu Converter.app** into your Applications folder. Open the app; its icon appears in the menu bar. There is no Dock icon or main window.

This preview is signed ad hoc and has no Apple notarization. If macOS blocks the first launch, see [Apple's explanation of opening downloaded apps](https://support.apple.com/en-gb/102445). Yuzu's installer does not change Gatekeeper settings.

### Install with npm

Node.js 20.11+ and npm are needed for installation and the launcher. The app itself runs without Node.

For npm 12:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/stpashik-yuzu-converter-0.3.0.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
```

For npm 10/11:

```sh
npm install -g https://github.com/StPashik/Yuzu-converter/releases/download/v0.3.0/stpashik-yuzu-converter-0.3.0.tgz
yuzu-converter
```

The installer downloads the matching app, checks its SHA-256, and places it in `~/Applications`. Updates preserve the previous app until the new one is ready. npm 12 requires explicit [URL and install-script permission](https://docs.npmjs.com/cli/using-npm/config/#allow-remote); the command changes no global npm settings.

## Convert a file

1. Start dragging a file from Finder.
2. Hold **Shift** to show the conversion wheel.
3. Drop the file on a format.

Yuzu creates a new file beside the original. Existing files are not overwritten and Finder does not open automatically. A first conversion in a folder may ask for access; select the original file's parent folder. That choice is remembered.

Drag several files together to convert them as a batch. The wheel shows formats they can all share. **Escape** cancels selection; holding **Control** switches to Actions. You can swap Shift and Control in Settings.

## Use Actions

Hold **Control** while dragging files or folders:

| Action | Result |
| --- | --- |
| AirDrop | Share through the system AirDrop service. |
| Float | Keep references on a floating shelf and drag them into another app later. |
| Copy | Put the files on the clipboard for pasting. |
| Move | Choose a destination folder. |
| Copy Path | Copy full paths, one per line. |
| Terminal | Open Terminal in the selected folder or the file's parent folder. |
| ZIP | Create one ZIP beside the first selected item, preserving every original. |

Removing an item from the shelf never deletes the file. Closing the shelf clears its references. ZIP creation rejects symbolic links and matching top-level filenames; rename those inputs first. Moving a folder between volumes is unavailable in this preview.

## Choose your language

Open **Settings… → Language** and choose English, Russian, German, French, or Spanish. The app defaults to English and remembers your choice. App-owned labels, menus, hints, and progress messages update immediately. Some system dialogs use the new language after restarting the app; detailed converter diagnostics remain English for support reports. Documentation and code comments stay English.

## Check for updates

Choose **Check for Updates…** in the menu bar menu or in Settings. If a newer version is available, choose to download it, then confirm installation and restart. No background checks or automatic installations are enabled. If file operations are still running, Yuzu waits for them to finish. Network failures and cancelled installs leave the app available for normal use.

The updater was introduced in 0.2.0. Install this version once using a direct download or npm if you have 0.1.2 or earlier. Updates apply to the running copy of the app; if you keep copies in both `/Applications` and `~/Applications`, each copy has its own version. An older npm launcher preserves a newer app in its installation folder. Some Sparkle dialogs follow a newly selected language after restart.

## Settings and cancellation

Click the menu bar icon and choose **Settings…** to enable/disable wheels, swap shortcuts, or choose whether Float adds to an existing shelf. The tooltip always lists the shortcuts. Choose **Quit** to exit; active work is cancelled and cleaned up before the app closes.

During conversion or ZIP creation, use **Cancel** in the progress panel. Files already completed by an earlier item in a batch remain available.

## Preview boundaries

Common image, native audio/video, PDF-page, text-document, values-only spreadsheet, subtitle, and archive routes are implemented. Check the [format support matrix](Conversion-matrix.md) before relying on complex documents. PAGES, PowerPoint, legacy XLS, OCR, PDF-to-editable-Office, and several media export formats are unavailable. Spreadsheet formulas and styling are not preserved.

Automated checks cover file handling and conversion fixtures. Physical Finder drag, Powerbox recovery, VoiceOver during drag, AirDrop, Terminal, and shelf drag-out still need manual validation. These are preview limitations, not completed checks. Details are in [Validation.md](Validation.md).

For a useful bug report, include your macOS version, chip, input/output formats, and the error text. Use a small non-private sample if possible: [GitHub Issues](https://github.com/StPashik/Yuzu-converter/issues).
