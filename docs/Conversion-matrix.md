# Conversion matrix: target inventory and implemented support

Updated October 27, 2026 for v0.4.1. Starting with 0.4.1, new releases target Apple Silicon only; 0.4.0 remains the final Intel release. This owner-approved architecture change does not reduce the conversion inventory. The target remains Tangerine's 46-case format inventory. Missing capabilities remain requirements; they are not removed to match a backend. All candidate rows and research evidence are in [TangerineResearch.md](TangerineResearch.md#full-static-candidate-inventory). Version-specific build/test results and remaining physical gates are in [Validation.md](Validation.md).

## Packaged Sandbox app and developer runs

The macOS 13+ Sandbox app has separate arm64/x64 archives. Both include pinned FFmpeg/FFprobe 9.0.2 with libvpx, Opus, and LAME. No external installation is needed for the media routes below. System frameworks and system `textutil`/`zip`/`tar` remain in use. LibreOffice is not bundled. [Bundled-media.md](Bundled-media.md) explains codecs, Sandbox descriptors, complete corresponding source, licenses, and rebuild instructions.

Unsandboxed developer runs may discover separately installed FFmpeg/FFprobe/LibreOffice. They can expose additional encoders, but do not establish packaged support. Packaged apps use only their own signed helpers. Missing encoder targets are hidden; actual codec/profile decoding and damaged-input failures remain possible.

## Implemented routes and gaps

The current format is hidden. Mixed inputs in one category receive only routes available to every file. Container names do not guarantee every codec/profile or lossless preservation. The media matrix fixture exercises real streams and output decoding; it does not prove every possible file.

| Group and target inputs | Implemented routes | Limits and remaining targets |
| --- | --- | --- |
| Images: JPG, PNG, WebP, HEIC, TIFF, SVG, AVIF, BMP | System reader → JPG/PNG/HEIC/TIFF/BMP/PDF, plus WebP/AVIF where ImageIO provides a writer | Reader/writer support depends on macOS and the file. SVG export is absent. PDF/TIFF process multiple frames; other raster outputs use the first frame. The bundled FFmpeg has no libwebp/libaom encoder; developer builds may supply them |
| Audio: MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA | Native compatible input → WAV/AIFF/M4A; bundled FFmpeg adds MP3/FLAC/Opus/WMA and decoding fallback | OGG/Vorbis output remains unavailable without a developer encoder. ASF/WMA identification uses bundled FFprobe. Input codec availability still matters |
| Video: MP4, MOV, MKV, WebM, AVI, WMV, GIF | Other video containers, animated GIF, and MP3 extraction; GIF input → MP4/MOV/MKV/WebM/AVI/WMV | Native MP4/MOV stays preferred when compatible. FFmpeg selects first video/optional first audio, discards subtitles/attachments/extra streams. MP3 is hidden for silent inputs. GIF is silent. AV1 software decoding is not bundled; native AV1 decoding depends on the Mac and actual asset. DRM and unsupported codecs/profiles may fail. Known disabled/non-unit-volume QuickTime tracks hide FFmpeg routes to avoid exposing hidden/muted content |
| PDF | Every page → JPG/PNG at 300 DPI; existing text layer → TXT/MD | No OCR or editable PDF → DOCX/PAGES/PPTX/XLSX/EPUB reconstruction |
| Documents: DOCX, PAGES, MD, RTF, RTFD, textClipping, TXT, HTML | DOCX/MD/RTF/RTFD/TXT → DOCX/PDF/TXT/MD/HTML/EPUB/JPG/PNG | Office layout/objects are not guaranteed. MD output is plain text with `.md`. PAGES/textClipping are unavailable. HTML export exists; no HTML input wheel |
| EPUB | Text chapters → PDF/DOCX/TXT/MD/HTML; simple reflowable document EPUB output | One text chapter; styles/images/assets/original layout not preserved. EPUB → PAGES unavailable |
| Slides: PPT, PPTX | Unavailable in packaged app | Target PDF/JPG/PNG; developer runs need LibreOffice. PDF → slides absent |
| Spreadsheets: XLSX, XLS, ODS, CSV, TSV | XLSX/ODS/CSV/TSV → XLSX/ODS/CSV/TSV/PDF, all sheets | String values; formulas/types/styles/charts/assets not preserved. CSV/TSV gives one file per sheet; PDF is text. XLS needs developer LibreOffice |
| Subtitles: SRT, VTT | SRT ↔ VTT; SRT/VTT → TXT | Cue text/timing, without full WebVTT styling/positioning/metadata |
| Archives: ZIP, TAR, GZIP, RAR | ZIP/TAR/TAR.GZ conversion; RAR input where system libarchive supports it | GZIP means TAR.GZ. Links/unsafe paths/collisions/limit violations rejected. Original metadata/permissions not guaranteed |

## Output quality and safety

Output-format profiles now configure actual quality/metadata, native media size/bitrate/PCM depth, ZIP/TAR.GZ compression, and EPUB 2/3 reflow. [Settings.md](Settings.md) lists exact encoder mappings and supported fields. Plain TAR has no compression level; native PCM metadata removal, original-page EPUB, and PDF-to-Office reconstruction remain unavailable. Exposing their limitations does not remove those capability requirements. Settings' compatibility tables distinguish format-level support from media pairs requiring a compatible actual file; they are not a full candidate inventory or proof of every file/profile.

The metadata-off image path applies orientation to pixels, retains color, and drops descriptive source tags. Native media and bundled FFmpeg have separate metadata policies; the latter removes global/stream tags and chapters. Generated raster pages retain 300-DPI metadata. Match-source PCM rejects unsupported depths rather than silently convert them. Native video Balanced uses the system Medium preset; High selects Highest. See version-specific validation rather than assuming older fixture passes verify these new options.

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
| `testFFmpegWAVToFLACWhenAvailable` | WAV → FLAC with an available engine; v0.4.1 release checks use the bundled build and do not skip |
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
