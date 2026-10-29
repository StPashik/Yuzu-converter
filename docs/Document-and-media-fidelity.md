# Document and media fidelity

Version 0.7.0 adds print styling, local text recognition, and explicit media-track preservation. Originals and existing results remain untouched. The wheel still shows the intersection of actual routes for a mixed selection. No File tools are added.

## XLSX to PDF

Drag a workbook, hold the conversion shortcut, and choose PDF. Every sheet is printed as a readable A4 table. The renderer reads cached values, common date/time, decimal, currency and percentage formats, cell/row/column style references, font family/size/bold/italic/color, horizontal alignment, solid fills, ordinary borders, and merged ranges. Both Excel date systems are supported. RGB, indexed, and theme colors are read; unavailable fonts use a system fallback. Column bands and vertical continuation retain wide/tall content; overlapping or excessive merged ranges fail before publication.

This is not an Excel layout or calculation engine. Formula caches are not recalculated; a missing cache displays the formula. Values-only XLSX/ODS/CSV/TSV exports retain their earlier raw-string behavior. Conditional formats, gradients/pattern fills, diagonal/double-border geometry, rich text within a cell, vertical alignment/rotation, print areas/page setup, hidden-row/column semantics, charts, images, and style inheritance from named base styles are not reconstructed. Font size is capped at 72 points. Unsupported number-format conditions, fractions, scientific/elapsed-time formats, and locale-specific built-in formats retain raw values. Common formats use stable English month names and `,`/`.` number separators; locale tags do not promise a localized Excel rendering. Excel's fictitious 1900-02-29 retains its serial 60. One million rectangular cells and 10,000 PDF pages remain safety limits.

## Local OCR to TXT

Choose TXT for a supported raster image (JPG/PNG/WebP/HEIC/TIFF/AVIF/BMP) or PDF. Browser/screenshot virtual-image drops also offer TXT and use the existing Save As flow. Vision processes pixels locally; there is no OCR server, account, or added network request. A remote browser image still needs the existing bounded download after Save As is accepted.

PDF pages with a nonempty text layer use it directly. Pages without text are rendered and recognized in document order; mixed text/scan PDFs work. Multi-frame raster images are recognized in frame order. EXIF orientation is applied. OCR uses accurate recognition, automatic language detection, and the installed OS's supported models for English, Russian, German, French, and Spanish. Other scripts and handwriting are not guaranteed. Scan working images are limited to a 4096-pixel longest edge; low resolution, complex columns, faint text, and mixed languages can reduce accuracy. A partially populated text layer is not supplemented with OCR of embedded images. PDF to MD uses the same plain text, without reconstructing Markdown or Office layout. Entirely blank/unreadable input fails with a useful message and publishes no empty result. Cancellation cancels the active Vision request and discards staging.

## Video tracks and warnings

For ordinary MP4/MOV/MKV/WebM/AVI/WMV input/output, bundled FFprobe inventories the actual streams. FFmpeg maps the first video and every audio stream explicitly. Audio tracks remain separate; supported language tags and default/forced dispositions are requested explicitly. Output disposition changes produce a warning (the bundled MOV muxer does not retain the forced-subtitle flag). MP4 alternate-language groups keep their selected/default track. An independent disabled track or modified QuickTime playback gain still prevents an unsafe FFmpeg route; compatible system export preserves playback semantics and warns if it combines audio or omits subtitles/chapters.

| Destination | Embedded subtitles | Chapters with Preserve Metadata on |
| --- | --- | --- |
| MP4, MOV | Supported text codecs converted to MOV Text | Retained |
| MKV | SRT/ASS/SSA/WebVTT/PGS/DVD/DVB copied; other supported text converted to SRT | Retained |
| WebM | Supported text converted to WebVTT | Retained by the bundled muxer; player support varies |
| AVI, WMV | Omitted with a warning | Omitted with a warning |

Text recognition is not used to convert bitmap subtitles into text. ASS/SSA conversion to plain timed text can lose styling, positions and effects, which produces a warning. Font attachments and extra video tracks are not retained and produce warnings. Unsupported subtitle codecs are omitted with a warning; MKV itself cannot store every codec. AVI may lose per-track language labels. Unsupported encoders/container combinations still fail safely. Output audio/subtitle/chapter counts are checked before publication; this is not a guarantee for every codec/profile, subtitle effect, player or language tag.

Warnings appear in Operations with **Details…** and **Copy Details**, and remain until **Clear Finished**. Ordinary successes still disappear after one second. Original files remain available to choose a more suitable container. Preserve Metadata off intentionally removes descriptive global/stream tags and chapters, while keeping compatible audio/subtitle content. MP3 extraction intentionally exports only the first audio stream; GIF output remains silent. Existing quality profiles and the LGPL-only bundled codec set remain in use; this feature does not add H.264/HEVC encoders or an AV1 software decoder.

## References and verification

- [Apple Vision text recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images) and the installed SDK's `VNRecognizeTextRequest`/`VNRequest` headers define language discovery and cancellation.
- [OpenXML numbering formats](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.numberingformat), [merged cells](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.mergecell), [Excel format guidelines](https://support.microsoft.com/en-us/excel/review-guidelines-for-customizing-a-number-format), and [date systems](https://support.microsoft.com/en-us/excel/date-systems-in-excel) inform the bounded print implementation.
- [FFmpeg documentation](https://ffmpeg.org/documentation.html) and the pinned 9.0.2 source/real fixtures define explicit mapping and muxer behavior.

See [Validation](Validation.md) for actual test/release evidence. Physical browser/Finder/Powerbox, VoiceOver, macOS 13 and other-Mac checks remain deferred/unverified; automated own-container Sandbox checks do not replace them.
