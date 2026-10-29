# Quick start

Yuzu Converter lives in your Mac's menu bar. Drag a file, hold a shortcut key, and drop it on the format or action you need.

## Install

| Your Mac | Download |
| --- | --- |
| Apple Silicon: M1, M2, M3, M4, or newer | [Apple Silicon app](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.3/Yuzu-Converter-0.6.3-arm64.zip) |
| Intel | [Intel app](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.3/Yuzu-Converter-0.6.3-x64.zip) |

Requires macOS 13+. Version 0.6.3 supports both architectures; existing Intel 0.4.0 and later clients can use **Check for Updates…** directly.

Open the ZIP and move **Yuzu Converter.app** into your Applications folder. Open the app; its icon appears in the menu bar. There is no Dock icon or main window.

This build is signed ad hoc and has no Apple notarization. If macOS blocks the first launch, see [Apple's explanation of opening downloaded apps](https://support.apple.com/en-gb/102445). Yuzu's installer does not change Gatekeeper settings.

### Install with npm

Node.js 20.11+ and npm are needed for installation and the launcher. The app itself runs without Node.

For npm 12:

```sh
YUZU_PACKAGE_URL="https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.3/stpashik-yuzu-converter-0.6.3.tgz"
npm install -g --allow-remote=all --allow-scripts="$YUZU_PACKAGE_URL" "$YUZU_PACKAGE_URL"
yuzu-converter
```

For npm 10/11:

```sh
npm install -g https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.3/stpashik-yuzu-converter-0.6.3.tgz
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

Removing an item from the shelf never deletes the file. Closing the shelf keeps its references until you reopen it or exit Yuzu. ZIP creation rejects symbolic links and matching top-level filenames; rename those inputs first. Moving a folder between volumes is currently unavailable.

## Keep files on the shelf

Choose **Show Shelf** from the Yuzu menu. Drop files onto the panel or use Float in the wheel. Each row shows a preview, filename, parent folder, a **folder** button to reveal the original in Finder, and **×** to remove its reference. Select rows and drag them out; hold Shift for conversion or Control for Actions in the wheel. The shelf has no conversion/Actions menus. Delete removes selected references; originals remain in place.

You can also select files in Finder and press **⌃C**. Change this in **Settings… → General → Actions → Add Finder selection to shelf**: click the field and press your preferred combination. Escape cancels recording; Delete disables the shortcut. It works only in Finder and follows Float Behaviour. Approve Finder access when macOS asks; the Sandbox build also requests initial access to the files' parent folder and remembers it. Your clipboard is preserved.

The panel opens below Yuzu's menu bar icon, grows through five rows, and scrolls longer lists. The close button or Escape hides a shelf while keeping its contents. **Show Shelf** restores closed shelves; **Clear Shelf** explicitly removes their references. Original files stay in place. The General settings retain the choice between adding to the current shelf and creating a new one. Shelf contents last until you exit Yuzu; they are not saved across app launches.

macOS 26+ uses Liquid Glass; macOS 13–15 use a native translucent material. The system's **Reduce Transparency** preference switches the shelf to an opaque surface. All shelf controls follow the app's selected language. See the [shelf guide](Shelf-design.md) for previews and verification limits.

## Choose your language

Open **Settings… → General → Language** and choose English, Russian, German, French, or Spanish. The app defaults to English and remembers your choice. App-owned labels, menus, hints, and progress messages update immediately. Some system dialogs use the new language after restarting the app; detailed converter diagnostics remain English for support reports. Documentation and code comments stay English.

## Check for updates

Choose **Check for Updates…** in the menu bar menu or in Settings. If a newer version is available, choose to download it, then confirm installation and restart. No background checks or automatic installations are enabled. If file operations are still running, Yuzu waits for them to finish. Network failures and cancelled installs leave the app available for normal use.

The updater was introduced in 0.2.0. Install this version once using a direct download or npm if you have 0.1.2 or earlier. Updates apply to the running copy of the app; if you keep copies in both `/Applications` and `~/Applications`, each copy has its own version. An older npm launcher preserves a newer app in its installation folder. Some Sparkle dialogs follow a newly selected language after restart.

## Settings and cancellation

Click the menu bar icon and choose **Settings…** to enable/disable wheels, swap shortcuts, or choose whether Float adds to an existing shelf. The tooltip always lists the shortcuts. Choose **Quit** to exit; active work is cancelled and cleaned up before the app closes.

During conversion or ZIP creation, use **Cancel** in the progress panel. Files already completed by an earlier item in a batch remain available.

## Known boundaries

Common image, native audio/video, PDF-page, text-document, values-only spreadsheet, subtitle, and archive routes are implemented. Check the [format support matrix](Conversion-matrix.md) before relying on complex documents. PAGES, PowerPoint, legacy XLS, OCR, PDF-to-editable-Office, and several media export formats are unavailable. Spreadsheet formulas and styling are not preserved.

Automated checks cover file handling and conversion fixtures. Physical Finder drag, Powerbox recovery, VoiceOver during drag, AirDrop, Terminal, and shelf drag-out still need manual validation. These checks remain unverified. Details are in [Validation.md](Validation.md).

For a useful bug report, include your macOS version, chip, input/output formats, and the error text. Use a small non-private sample if possible: [GitHub Issues](https://github.com/StPashik/Yuzu-converter/issues).

## Video conversion without extra setup

Both current architecture-specific releases include FFmpeg and FFprobe. Drag a supported video, hold Shift, and choose MP4, MOV, MKV, WebM, AVI, WMV, animated GIF, or MP3 audio. The current format and targets unavailable for the actual selection are hidden. MP3 requires sound; GIF exports are silent. See [codec limits, licenses, and complete corresponding source](Bundled-media.md). This software uses FFmpeg under LGPL 2.1 or later.

## Follow operations

Conversion, Move, and Compress to ZIP open **Operations**. You can also reopen it from **Show Operations** in the menu bar. Jobs run in order; each row shows its state, filenames, and completed input count. Operations shows state and completed-file counts; no percentage bar or spinner is shown. **Cancel** affects one request, **Cancel All** includes waiting requests, and **Clear Finished** removes only history rows.

Operations uses a compact ordinary window, without an always-on-top mode or Show Results button. Successful rows disappear after one second. Errors and cancellations remain until Clear Finished; an empty list after work closes the window. Closing manually leaves work running. Cancellation preserves completed results and does not roll back earlier moves. See the [workflow guide](Shelf-workflow.md).

Converted files keep their source stem and change extension. Collisions use `_yuzu`, then `_yuzu_2` and later numbers without overwriting earlier files. Update offers show English Release Notes before installation.

## Multiple images, browser images, and tables

Drop several supported images on PDF to create one multi-page document in the supplied order, beside the first input. Other formats export separate results. A conversion wheel with no supported targets stays hidden; Actions still handles folders.

Raster data, an image file promise, or a plain HTTP(S) image URL from a browser/screenshot can offer Save As after a conversion petal is chosen. See [virtual image limits and permissions](Virtual-image-drops.md). Existing local file URLs keep the normal beside-original behavior unless the drag explicitly marks promised screenshot image content.

XLSX/ODS/CSV/TSV to PDF prints a paginated table with grid lines and wrapped values. XLSX column widths and row heights are approximated. Formulas use cached values; a missing cache prints the formula instead of inventing a result. Full Excel formatting/merged cells/charts are not reconstructed; keep the workbook when those matter.


## Recover a failed operation

Open Operations and read the recovery suggestion. Fix the reported issue, then choose **Retry** to append remaining inputs to the queue; files already published are preserved. **Details…** shows the original diagnostic and **Copy Details** copies it in full. Clearing a failure releases its retained inputs. For a missing shelf item, choose the search icon and locate the original; this updates only the reference. See [Retry and reference recovery](Retry-and-references.md).
