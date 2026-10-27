# Conversion matrix: target inventory and preview support

Updated October 27, 2026. The target remains Tangerine’s 46-case format inventory. Version 0.1.0 implemented part of that scope; v0.1.1 carries the behavior forward with five selectable UI languages and English project documentation. Limits do not remove the remaining requirements. All 46 candidate rows and their evidence are in [TangerineResearch.md](TangerineResearch.md#full-static-candidate-inventory).

Implementation references: `Sources/YuzuCore/ConversionEngine.swift`, `NativeMedia.swift`, `NativeDocuments.swift`, `EPUB.swift`, `Spreadsheet.swift`, `SourceFile.swift`, and `Archive.swift`. Fresh v0.1.1 checks passed 29/29 Swift tests on native arm64 and x86_64 under Rosetta, 13/13 Node tests, both signed Sandbox self-checks, and installation of both final ZIPs. An `implemented` route is not a claim that every file, codec, or macOS version was verified. See [Validation.md](Validation.md).

## Packaged Sandbox app and developer runs

The macOS 13+ Sandbox app has separate arm64/x64 archives. It neither bundles nor launches external FFmpeg/FFprobe/LibreOffice. It uses macOS frameworks, system libarchive, and system `textutil`/`zip`/`tar`.

An unsandboxed `swift run` can find separately installed FFmpeg/FFprobe/LibreOffice and enable extra routes where the required encoder exists. Those are developer-only capabilities, not packaged-release support. Missing tools hide their targets. Decoder/writer availability is separate from the candidate catalog; damaged inputs or unsupported profiles can still fail during conversion.

## Implemented routes and gaps

The current format is hidden. Mixed inputs in one internal category receive only the intersection of available routes for every file. The following describes the v0.1.0 behavior retained for v0.1.1; it does not claim a new verification run.

| Group and target inputs | Implemented preview routes | Limits and remaining targets |
| --- | --- | --- |
| Images: JPG, PNG, WebP, HEIC, TIFF, SVG, AVIF, BMP | System reader → JPG/PNG/HEIC/TIFF/BMP/PDF, plus WebP/AVIF where ImageIO provides a writer | Reader/writer support depends on macOS and the file. SVG input requires system decoding; SVG export is absent. For multiple frames, PDF/TIFF process the frames while other raster outputs use the first frame. Developer-only WebP/AVIF encoding may use FFmpeg |
| Audio: MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA | macOS-decodable input → WAV/AIFF/M4A, gated by AVAudioFile/AVFoundation | MP3/FLAC/OGG/Opus/WMA export is unavailable in the packaged app. ASF/WMA identification requires FFprobe. An enum case does not imply an available system decoder |
| Video: MP4, MOV, MKV, WebM, AVI, WMV, GIF | AVFoundation-exportable video → MP4/MOV | Baseline fixtures cover MOV ↔ MP4. Other inputs depend on decoder/export support. GIF input has no native route; MKV/WebM/AVI/WMV/GIF output and MP3 extraction require developer-only FFmpeg. ASF/WMV identification requires FFprobe |
| PDF | Every page → JPG/PNG at 300 DPI; existing text layer → TXT/MD | No OCR. PDF → DOCX/PAGES/PPTX/XLSX/EPUB is unavailable. Images and text extraction are not presented as editable reconstruction |
| Documents: DOCX, PAGES, MD, RTF, RTFD, textClipping, TXT, HTML | DOCX/MD/RTF/RTFD/TXT → DOCX/PDF/TXT/MD/HTML/EPUB/JPG/PNG | DOCX uses system rich-text readers/writers without guaranteeing Office layout or objects. MD output is plain text with a `.md` extension. PAGES input/output and textClipping are unavailable. HTML export exists, but there is no HTML input wheel |
| EPUB | Text chapters → PDF/DOCX/TXT/MD/HTML; simple EPUB output from documents | Simple reflow; the writer creates one chapter. Styles, images, assets, and original layout are not preserved. EPUB → PAGES is unavailable |
| Slides: PPT, PPTX | Unavailable in the Sandbox app | Target: PDF/JPG/PNG. Developer runs need separately installed LibreOffice. PDF → slides is absent |
| Spreadsheets: XLSX, XLS, ODS, CSV, TSV | XLSX/ODS/CSV/TSV → XLSX/ODS/CSV/TSV/PDF, all sheets | Values become strings. Formulas, types, styles, charts, and assets are not preserved. CSV/TSV produces one file per sheet in a folder; PDF is a text representation. Legacy XLS needs developer-only LibreOffice |
| Subtitles: SRT, VTT | SRT ↔ VTT; SRT/VTT → TXT | Cue text and timing; metadata, positioning, and full WebVTT styling are not preserved |
| Archives: ZIP, TAR, GZIP, RAR | ZIP/TAR/TAR.GZ → another of those formats; RAR input where system libarchive supports it | GZIP means TAR.GZ, not a standalone gzip stream. Links, unsafe/colliding paths, and limit violations are rejected. Original archive metadata/permissions are not guaranteed. Archive tools are not added |

## Output quality and safety

Output-format profiles now configure actual quality/metadata, native media size/bitrate/PCM depth, ZIP/TAR.GZ compression, and EPUB 2/3 reflow. [Settings.md](Settings.md) lists exact encoder mappings and supported fields. Plain TAR has no compression level; native PCM metadata removal, original-page EPUB, and PDF-to-Office reconstruction remain unavailable. Exposing their limitations does not remove those capability requirements. Settings' compatibility tables distinguish format-level support from media pairs requiring a compatible actual file; they are not a full candidate inventory or proof of every file/profile.

The metadata-off image path applies orientation to pixels, retains color, and drops descriptive source tags. Native media and developer FFmpeg have separate metadata policies; the latter removes global/stream tags and chapters. Generated raster pages retain 300-DPI metadata. Match-source PCM rejects unsupported depths rather than silently convert them. Native video Balanced uses the system Medium preset; High selects Highest. See version-specific validation rather than assuming older fixture passes verify these new options.

- PDF → JPG/PNG puts all pages in a separate folder at an actual 300 DPI. Pages exceeding 32,768 pixels per side or 64 megapixels are rejected rather than silently downscaled. Fixtures check page count, pixel dimensions, and DPI.
- DOCX contains editable text rather than a faithful copy of complex Office layout. PDF → TXT/MD extracts existing text. Raster images are not labeled editable Office output.
- XLSX/ODS transfer all sheets and values as string cells. Formula calculation, style/asset round-tripping, and native spreadsheet printing are not implemented.
- Write and validate results in scratch, then publish under available names. Preserve sources and existing results. Failure or cancellation must not publish incomplete conversion output.
- Content detection uses signatures and package contents. Text formats without unique signatures still need heuristics; Markdown can also use the `.md` extension. Unknown, empty, or unsupported input produces an error.

## Fixtures and verification scope

The named fixtures in [ConversionTests.swift](../Tests/YuzuCoreTests/ConversionTests.swift) were part of the historical 22 Core tests, alongside 4 App tests and 13 Node tests. Regression coverage includes Compress to ZIP, XML namespaces/overflow, archive collisions, CRLF, and EXIF orientation. Those v0.1.0 passes are not new v0.1.1 runs, and a fixture does not verify every pair in its group.

| Fixture | What it checks |
| --- | --- |
| `testContentWinsOverMisleadingExtensionAndMixedTargetsIntersect` | PNG with a misleading extension, hiding current formats, intersection, and incompatible categories |
| `testImageConversionDoesNotOverwriteExistingResult` | PNG → JPG, an available name, and preservation of source/existing output |
| `testPDFExportsEveryPageAt300DPI` | Two-page PDF → PNG, both pages, actual dimensions, and DPI |
| `testUTF16ContentDetectionAndConversion` | UTF-16 → readable editable DOCX text |
| `testEditableDOCXAndEPUBContainText` | TXT → DOCX/EPUB and inspection of textual content |
| `testQuotedDelimitedTableRoundTripThroughXLSXAndODS` | CSV quotes/newlines → XLSX/ODS and values after reading |
| `testSubtitlesRetainTimesAndTextAndRejectInvalidInput` | SRT → VTT, text/timing retention, and invalid-input rejection |
| `testArchiveRoundTripAndRejectsSymlink` | ZIP → TAR.GZ, contents, link/traversal rejection, and standalone-GZIP rejection |
| `testNativeAudioBaselineWithoutExternalTools` | WAV → AIFF/M4A and AIFF → WAV, readability/frame count without external engines |
| `testNativeVideoBaselineWithoutExternalTools` | MOV → MP4 → MOV and a readable video stream without external engines |
| `testFFmpegWAVToFLACWhenAvailable` | Developer-only WAV → FLAC; skipped if the tool/encoder is absent |
| Cancellation/FileOperations fixtures | No published result after cancellation, subprocess termination, available names, move deduplication/ancestor filtering, and recursive-destination rejection |

Even a passing suite does not establish every candidate pair, codec/profile, or physical Sandbox interaction. An x64 cross-build does not prove execution on Intel hardware.

## Actions

The researched behavior and Yuzu’s implementation have separate evidence. [TangerineResearch.md](TangerineResearch.md#actions-dispatch-and-confirmed-semantics) records the six-action dispatch and unknowns. Compress to ZIP is a separate seventh owner-requested Yuzu Action, not a Tangerine/REA finding or an addition to File tools.

| Action | Implemented behavior | Verification boundary |
| --- | --- | --- |
| `airDrop` | System NSSharingService; retain scoped URLs until completion | Physical AirDrop check deferred |
| `float` | File-reference shelf; add to an existing shelf or create a new one; drag-out copy; Remove/Close preserve originals; no persistence between launches | Physical drag-out and Sandbox integration remain unverified |
| `copy` | File URLs in NSPasteboard.general | Real Clipboard/Finder paste and scope lifetime checks deferred |
| `move` | Destination picker, queued operation, available names, deduplication/ancestor filtering. Cross-volume files compare source size/mtime before/after copying; folders are refused before copying | Core fixtures exist; physical picker/Sandbox checks deferred; no content-hash guarantee |
| `copyPath` | Paths as newline-separated text | Real system paste targets not manually tested |
| `openTerminal` | NSWorkspace + selected Terminal/iTerm2; the directory itself or a file/package’s parent; deduplicate folders | Folder-mapping and bundle-ID fixtures exist; real terminal/Sandbox checks deferred |
| Compress to ZIP | One archive beside the first input, ZIP compression profile, available name, originals preserved | Owner-requested feature; version-specific creation/cancellation/compression fixtures and Sandbox results are recorded in Validation |

Yuzu chooses its own enum order. Tangerine’s exact wheel order and visual parity are not established. The owner deferred new manual Finder/Sandbox/AirDrop/Terminal checks; those checks remain open in the preview.
