# Conversion matrix: target inventory and implemented support

Updated October 29, 2026 for v0.7.0. Version 0.4.1 was Apple Silicon only; version 0.4.2 restores separate Intel builds after native CI and signed Sandbox validation. The format inventory remains unchanged; raster-to-TXT OCR adds routes within that inventory. The target remains Tangerine's 46-case format inventory. Missing capabilities remain requirements; they are not removed to match a backend. All candidate rows and research evidence are in [TangerineResearch.md](TangerineResearch.md#full-static-candidate-inventory). Version-specific build/test results and remaining physical gates are in [Validation.md](Validation.md).

## Packaged Sandbox app and developer runs

The macOS 13+ Sandbox app has separate arm64/x64 archives. Both include pinned FFmpeg/FFprobe 9.0.2 with libvpx, Opus, and LAME. No external installation is needed for the media routes below. System frameworks and system `textutil`/`zip`/`tar` remain in use. LibreOffice is not bundled. [Bundled-media.md](Bundled-media.md) explains codecs, Sandbox descriptors, complete corresponding source, licenses, and rebuild instructions.

Unsandboxed developer runs may discover separately installed FFmpeg/FFprobe/LibreOffice. They can expose additional encoders, but do not establish packaged support. Packaged apps use only their own signed helpers. Missing encoder targets are hidden; actual codec/profile decoding and damaged-input failures remain possible.

## Implemented routes and gaps

The current format is hidden. Mixed inputs receive only routes available to every file, including compatible categories. Container names do not guarantee every codec/profile or lossless preservation. The media matrix fixture exercises real streams and output decoding; it does not prove every possible file.

| Group and target inputs | Implemented routes | Limits and remaining targets |
| --- | --- | --- |
| Images: JPG, PNG, WebP, HEIC, TIFF, SVG, AVIF, BMP | System reader → JPG/PNG/HEIC/TIFF/BMP/PDF, plus WebP/AVIF where ImageIO provides a writer; raster images → local OCR TXT | Reader/writer support depends on macOS and the file. SVG export and SVG OCR are absent. PDF/TIFF process multiple frames; other raster outputs use the first frame. The bundled FFmpeg has no libwebp/libaom encoder; developer builds may supply them |
| Audio: MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA | Native compatible input → WAV/AIFF/M4A; bundled FFmpeg adds MP3/FLAC/Opus/WMA and decoding fallback | OGG/Vorbis output remains unavailable without a developer encoder. ASF/WMA identification uses bundled FFprobe. Input codec availability still matters |
| Video: MP4, MOV, MKV, WebM, AVI, WMV, GIF | Other video containers, animated GIF, and MP3 extraction; GIF input → MP4/MOV/MKV/WebM/AVI/WMV | For multitrack/chapter video, FFmpeg explicitly maps first video/all audio, compatible embedded subtitles, and supported chapters. Simple compatible MP4/MOV and hardware-dependent AV1 keep native export, with warnings for native inventory losses. Native playback fallback remains for independently disabled/non-unit-volume tracks. Omitted/simplified content produces retained warnings; attachments/extra video are omitted. See the fidelity guide for the codec table. MP3 is hidden for silent inputs. GIF is silent. AV1 software decoding is not bundled; native AV1 decoding depends on the Mac and actual asset. DRM and unsupported codecs/profiles may fail. Known disabled/non-unit-volume QuickTime tracks hide FFmpeg routes to avoid exposing hidden/muted content |
| PDF | Every page → JPG/PNG at 300 DPI; text layer/local scan OCR → TXT/MD | No editable PDF → DOCX/PAGES/PPTX/XLSX/EPUB reconstruction |
| Documents: DOCX, PAGES, MD, RTF, RTFD, textClipping, TXT, HTML | DOCX/MD/RTF/RTFD/TXT → DOCX/PDF/TXT/MD/HTML/EPUB/JPG/PNG | Office layout/objects are not guaranteed. MD output is plain text with `.md`. PAGES/textClipping are unavailable. HTML export exists; no HTML input wheel |
| EPUB | Text chapters → PDF/DOCX/TXT/MD/HTML; simple reflowable document EPUB output | One text chapter; styles/images/assets/original layout not preserved. EPUB → PAGES unavailable |
| Slides: PPT, PPTX | Unavailable in packaged app | Target PDF/JPG/PNG; developer runs need LibreOffice. PDF → slides absent |
| Spreadsheets: XLSX, XLS, ODS, CSV, TSV | XLSX/ODS/CSV/TSV → XLSX/ODS/CSV/TSV/PDF, all sheets | Editable exports use string values; formula/type/style round-tripping, charts, and assets are absent. PDF additionally retains common XLSX number/date/currency formats, solid fills, borders, fonts, and merged ranges. CSV/TSV gives one file per sheet; PDF uses a paginated grid with wrapped text and approximate XLSX dimensions. XLS needs developer LibreOffice |
| Subtitles: SRT, VTT | SRT ↔ VTT; SRT/VTT → TXT | Cue text/timing, without full WebVTT styling/positioning/metadata |
| Archives: ZIP, TAR, GZIP, RAR | ZIP/TAR/TAR.GZ conversion; RAR input where system libarchive supports it | GZIP means TAR.GZ. Links/unsafe paths/collisions/limit violations rejected. Original metadata/permissions not guaranteed |

## Output quality and safety

Output-format profiles now configure actual quality/metadata, native media size/bitrate/PCM depth, ZIP/TAR.GZ compression, and EPUB 2/3 reflow. [Settings.md](Settings.md) lists exact encoder mappings and supported fields. Plain TAR has no compression level; native PCM metadata removal, original-page EPUB, and PDF-to-Office reconstruction remain unavailable. Exposing their limitations does not remove those capability requirements. Settings' compatibility tables distinguish format-level support from media pairs requiring a compatible actual file; they are not a full candidate inventory or proof of every file/profile.

The metadata-off image path applies orientation to pixels, retains color, and drops descriptive source tags. Native media and bundled FFmpeg have separate metadata policies; the latter removes global/stream tags and chapters. Generated raster pages retain 300-DPI metadata. Match-source PCM rejects unsupported depths rather than silently convert them. Native playback fallback uses the system Medium/Highest presets; video requiring explicit track mapping uses the documented FFmpeg quality mappings. See version-specific validation rather than assuming older fixture passes verify these new options.

- PDF → JPG/PNG puts all pages in a separate folder at an actual 300 DPI. Pages exceeding 32,768 pixels per side or 64 megapixels are rejected rather than silently downscaled. Fixtures check page count, pixel dimensions, and DPI.
- DOCX contains editable text rather than a faithful copy of complex Office layout. PDF → TXT/MD uses existing text per page and local OCR on scan-only pages; raster inputs offer TXT. Raster images are not labeled editable Office output.
- XLSX/ODS transfer all sheets and values as string cells. Formula calculation and style/asset round-tripping are not implemented. Table PDF preserves common XLSX print styling/merged ranges; unstyled tables use a fallback grid. Complex numeric formats, conditional styling, charts, print areas, page setup, and hidden-row/column semantics remain limited. [Document and media fidelity](Document-and-media-fidelity.md) lists the exact subset and OCR/media limits.
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
| `testFFmpegWAVToFLACWhenAvailable` | WAV → FLAC with an available engine; v0.4.2 release checks use the bundled build and do not skip |
| `MediaTests.testEveryVideoInputAndOutputWithRealStreams` | 48 real directed video/MP3 routes, frame/stream checks, full decoding, and unchanged source bytes |
| `MediaTests` descriptor/silent/damaged fixtures | Seekable inherited files, exclusive output creation, silent MP3 filtering, and no partial publication |
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

Yuzu chooses its own enum order. Tangerine’s exact wheel order and visual parity are not established. The owner deferred new manual Finder/Sandbox/AirDrop/Terminal checks; those checks remain unverified.

## Shelf entry points (current behavior)

The shelf holds file references; drag them into the wheel for conversion or all seven Actions. It has no conversion/Actions menus. Float remains in the wheel. Conversion, Move, and ZIP use the shared serial queue; earlier published results remain available after failure/cancellation. Completed Yuzu moves now update shelf references and waiting/failed jobs, including real-directory descendants. External moves/deletions require availability refresh or Locate Original. Retry preserves completed results and queues only remaining inputs. See [Shelf workflow](Shelf-workflow.md).

PDF raster output explicitly scales points to pixels at 300 DPI before applying page placement: the system drawing transform alone only scales down. Geometry uses the visible CropBox intersected with MediaBox, including nonzero origins and rotations. A four-page fixture checks JPG/PNG dimensions and colored content coverage; the original PDF from the owner's screenshot is unavailable, so that specific file remains unverified.

## Batch and virtual image limits (0.6.2)

Several supported images dropped on PDF create one document in supplied pasteboard order. Each contributes its oriented first frame; image animation is not merged. The system's Finder selection order is not independently sorted or promised. Normal file destinations stay beside originals; virtual image drops use Save As and exclusive exact-path publication. [Virtual image drops](Virtual-image-drops.md) describes accepted representations, bounded downloads, and unresolved physical/browser gates.

Spreadsheet printing preserves values, readable wrapping, sheets, approximate XLSX column widths and row heights. It uses cached formula results and displays an uncomputed formula only when its cached value is absent. More than one million rectangular layout cells or 10,000 pages fails with a useful error. These bounds and unimplemented Excel layout features remain capability limits rather than silent omissions.
