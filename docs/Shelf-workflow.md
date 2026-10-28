# Shelf workflow and operations

Version 0.6.0 lets you convert files and run all seven Actions from the shelf.

1. Choose **Show Shelf**, drag files onto it, or add selected Finder files with your configured shortcut (Control+C by default).
2. Select one or more rows. Newly added rows are selected together. Command-click or Shift-click adjusts the selection.
3. Use **Convert** or **Actions**, or right-click a row. Convert offers only outputs supported by every selected input; the current input formats are hidden. A mixed or unsupported selection may have no common output.
4. Conversion saves beside each original after any required folder approval. **Move to Folder…** asks for its destination. **Compress to ZIP** creates one archive beside the first selected item. Existing results get an available name.

Actions also include AirDrop, Copy Files, Copy Path, Open Terminal, and New Shelf with Selection. The last creates an independent shelf even when drag/hotkey Float is set to reuse a shelf. These system Actions retain their usual system UI and permission requirements. File tools are not included. See [format support and limitations](Conversion-matrix.md).

## Read the queue

Conversion, Move, and ZIP requests enter a serial queue and open **Operations**. Reopen it any time with **Show Operations**. Other Actions use the clipboard, sharing UI, Terminal, or another shelf directly; they are not presented as file-processing jobs.

| State/control | Meaning |
| --- | --- |
| Waiting | Another request runs first |
| Running | This request is processing files |
| Cancelling… | Cancellation was requested; the worker is cleaning up |
| Completed | All requested work returned successfully |
| Cancelled | The request was cancelled; previously published results remain |
| Failed | Read the error; previously published results remain accessible |
| Cancel / Cancel All | Cancel one request, or all running/waiting requests |
| Show Results | Explicitly reveal the published output files in Finder |
| Clear Finished | Remove finished history rows; never delete output files |

The count measures completed input files, not elapsed time or encoding percentage. Conversion updates between files. A spinner is used while an individual export, Move batch, or ZIP is running. Move keeps the whole selection together when normalizing folders and their children. If a later move fails, earlier destinations stay published and are shown in the failed row. No automatic rollback deletes completed copies.

An error does not block later requests. Cancellation stops active subprocesses cooperatively and discards unfinished private staging. A large filesystem copy may need time to return before cancellation is observed. Completed results and moved originals are not rolled back. Check the error and remaining inputs before submitting another request; this version does not automatically retry.

## Window and file lifetime

Close or Escape hides either panel. Reopening the shelf keeps references; reopening Operations keeps the queue and history. Removing a shelf row or clearing its contents does not revoke access already retained by a submitted job or system Action. A shelf stores references to originals, so moving an original through Move can leave a stale row in the source shelf; remove it and add the desired result if needed.

Shelves and queue history last only for the running app session. Exiting cancels outstanding jobs and waits for cleanup. Files and saved output profiles remain; queue recovery after restart is not included.

The shelf, operations panel, and wheel share native Liquid Glass on macOS 26+, an earlier-system material fallback, and an opaque Reduce Transparency appearance. Solid remains available for the wheel. All app-owned labels support English, Russian, German, French, and Spanish. Converter errors remain English.

![Shelf commands, opaque light appearance](images/shelf-workflow.png)

![Operations, opaque dark appearance](images/operations.png)

These are automated offscreen fixture renders. Native glass structure and drag hit testing have automated checks; physical Finder/Powerbox, external-file Sandbox, VoiceOver, macOS 13, and macOS 26 Intel appearance remain unverified.
