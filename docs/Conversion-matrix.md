# Матрица конвертации: цель и выпуск 0.1.0

Дата: 27 октября 2026. Цель проекта — инвентарь Tangerine из 46 enum cases; выпуск 0.1.0 покрывает часть этой цели и публикуется как prerelease. Ограничения реализации не удаляют оставшиеся требования. Полные 46 строк candidate targets и Evidence приведены в [TangerineResearch.md](TangerineResearch.md#полный-статический-candidate-inventory).

Источник состояния реализации: `Sources/YuzuCore/ConversionEngine.swift`, `NativeMedia.swift`, `NativeDocuments.swift`, `EPUB.swift`, `Spreadsheet.swift`, `SourceFile.swift`, `Archive.swift`. Итоговый прогон: 26/26 Swift tests на arm64 и x86_64 через Rosetta, 13/13 Node tests. Таблица описывает существующие маршруты. Статус `implemented` не означает `verified` для всех файлов/кодеков/версий macOS; условия проверки перечислены в [Validation.md](Validation.md).

## Sandbox release и developer launch

Готовая `.app` Sandbox macOS 13+ выпускается отдельно для arm64/x64. Сторонние FFmpeg/FFprobe/LibreOffice в архивы не входят и из Sandbox `.app` не запускаются. Системные frameworks, libarchive и `textutil`/`zip`/`tar` используются из macOS.

Несандбоксированный `swift run` может обнаруживать отдельно установленные FFmpeg/FFprobe/LibreOffice и открывать дополнительные маршруты, если есть нужный encoder. Это developer-only возможности, а не поддержка готового релиза. Если инструмент отсутствует, его цели скрыты. Наличие decoder/writer проверяется отдельно от статического списка кандидатов; конвертация также может отклонить повреждённый или неподдерживаемый профиль входа.

## Реализованные маршруты и пробелы

Во всех строках текущий формат скрывается. Для смешанного набора одной внутренней категории показывается пересечение доступных пар каждого input.

| Группа и целевые входы | Sandbox release 0.1.0 | Ограничения и остающаяся цель |
| --- | --- | --- |
| Images: JPG, PNG, WebP, HEIC, TIFF, SVG, AVIF, BMP | `implemented`: системный reader → JPG/PNG/HEIC/TIFF/BMP/PDF и доступный ImageIO writer WebP/AVIF | Reader/writer зависит от macOS и файла. SVG input требует системного декодирования, SVG output отсутствует. Для multi-frame input PDF/TIFF обрабатывает кадры; другие raster outputs берут первый кадр. Developer-only WebP/AVIF encoding может использовать FFmpeg |
| Audio: MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA | `implemented`: декодируемый macOS input → WAV/AIFF/M4A; targets зависят от AVAudioFile/AVFoundation | FFmpeg export MP3/FLAC/OGG/Opus/WMA отсутствует в релизе. ASF/WMA identification требует FFprobe и без него unavailable. Факт наличия enum case не означает доступного системного decoder |
| Video: MP4, MOV, MKV, WebM, AVI, WMV, GIF | `implemented`: AVFoundation-exportable video → MP4/MOV | Baseline fixtures — MOV ↔ MP4. Другие inputs зависят от decoder/export support. GIF input не проходит native route; MKV/WebM/AVI/WMV/GIF output и MP3 extraction — developer-only FFmpeg. ASF/WMV identification требует FFprobe |
| PDF | `implemented`: JPG/PNG всех страниц при 300 DPI; текстовый слой → TXT/MD | OCR отсутствует. PDF → DOCX/PAGES/PPTX/XLSX/EPUB — `unavailable` в релизе, editable reconstruction не подменяется картинками или text extraction |
| Documents: DOCX, PAGES, MD, RTF, RTFD, textClipping, TXT, HTML | `implemented`: DOCX/MD/RTF/RTFD/TXT → DOCX/PDF/TXT/MD/HTML/EPUB/JPG/PNG | DOCX — rich text через системные readers/writers, без гарантии Office layout/objects. MD writer сохраняет plain text с `.md`. PAGES input/output и textClipping — `unavailable`. HTML input wheel пуст, HTML export присутствует |
| EPUB | `implemented`: текстовые главы → PDF/DOCX/TXT/MD/HTML; простой EPUB output из документов | Простой reflow, writer создаёт одну главу. Стили, изображения, assets и исходная вёрстка не сохраняются. EPUB → PAGES — `unavailable` |
| Slides: PPT, PPTX | `unavailable` в Sandbox release | Цель: PDF/JPG/PNG. В developer launch нужен отдельно установленный LibreOffice; PDF→slides отсутствует |
| Spreadsheets: XLSX, XLS, ODS, CSV, TSV | `implemented`: XLSX/ODS/CSV/TSV → XLSX/ODS/CSV/TSV/PDF, все листы | Только значения как строки. Формулы, типы, стили, charts/assets не сохраняются. CSV/TSV — файл на каждый лист в папке; PDF — текстовое представление. Legacy XLS — `unavailable` в Sandbox release, developer-only LibreOffice |
| Subtitles: SRT, VTT | `implemented`: SRT ↔ VTT; SRT/VTT → TXT | Текст и тайминги cues; metadata, позиционирование и полное WebVTT оформление не сохраняются |
| Archives: ZIP, TAR, GZIP, RAR | `implemented`: ZIP/TAR/TAR.GZ → другой из ZIP/TAR/TAR.GZ; RAR reader при поддержке системной libarchive | GZIP case означает TAR.GZ. Одиночный gzip stream не поддерживается. Symlinks/hardlinks, unsafe paths и превышение лимитов отклоняются; метаданные/permissions исходного архива не обещаются. Archive tools не добавлены |

## Качество и безопасность результата

- PDF → JPG/PNG создаёт отдельную папку со всеми страницами. Масштаб — действительные 300 DPI. Страница больше 32 768 px по стороне либо 64 MP отклоняется; silent downscale отсутствует. Валидация fixtures проверяет число страниц, pixel dimensions и DPI.
- DOCX остаётся редактируемым текстовым документом, но не точной копией сложного Office макета. PDF → TXT/MD обозначает извлечение имеющегося текста. Растр не объявляется editable Office.
- XLSX/ODS переносят все листы и значения, записанные строковыми ячейками. Функции расчёта формул, style/assets round-trip и нативная табличная печать не реализованы.
- Результаты сначала создаются в scratch, валидируются и публикуются под свободным именем. Исходники и прежние результаты не перезаписываются. Отмена и ошибка не публикуют незавершённую конвертацию.
- Определение типа использует signatures/package contents; у текстовых форматов без уникальной сигнатуры остаются heuristics. Например Markdown может учитывать расширение `.md`. Неизвестный, пустой или неподдерживаемый input получает ошибку.

## Fixtures и подтверждение проверок

Все названные ниже проверки существуют в [ConversionTests.swift](../Tests/YuzuCoreTests/ConversionTests.swift) и входят в прошедшие 22 Core tests; также прошли 4 App tests и 13 Node tests. Регрессии покрывают ZIP Action, XML namespaces/overflow, архивные коллизии, CRLF и EXIF orientation. Проверка fixture не означает проверку каждой пары группы.

| Fixture | Что проверяет |
| --- | --- |
| `testContentWinsOverMisleadingExtensionAndMixedTargetsIntersect` | PNG с чужим расширением, скрытие текущих форматов и пересечение/разные категории |
| `testImageConversionDoesNotOverwriteExistingResult` | PNG → JPG, свободное имя и сохранность исходника/существующего результата |
| `testPDFExportsEveryPageAt300DPI` | Двухстраничный PDF → PNG, обе страницы и фактические pixel dimensions/DPI |
| `testUTF16ContentDetectionAndConversion` | UTF-16 → редактируемый DOCX с читаемым текстом |
| `testEditableDOCXAndEPUBContainText` | TXT → DOCX/EPUB и проверка текстового содержимого |
| `testQuotedDelimitedTableRoundTripThroughXLSXAndODS` | CSV с кавычками/newline → XLSX/ODS и значения после чтения |
| `testSubtitlesRetainTimesAndTextAndRejectInvalidInput` | SRT → VTT, тайминги/текст и отказ на неправильном input |
| `testArchiveRoundTripAndRejectsSymlink` | ZIP → TAR.GZ, содержимое, symlink/traversal и single-GZIP rejection |
| `testNativeAudioBaselineWithoutExternalTools` | WAV → AIFF/M4A, AIFF → WAV, читаемость/число frames без внешних движков |
| `testNativeVideoBaselineWithoutExternalTools` | MOV → MP4 → MOV, читаемый video stream без внешних движков |
| `testFFmpegWAVToFLACWhenAvailable` | Developer-only WAV → FLAC; skip при отсутствии инструмента/encoder |
| Cancellation/FileOperations fixtures | Отмена без published result, остановка процесса, свободные имена, move dedup/ancestor filtering и отказ на recursive destination |

Даже успешный run этих fixtures не доказывает все candidate pairs, все codecs/профили или физическую Sandbox работу. Кросс-компиляция x64 не доказывает запуск на Intel.

## Actions

Семантика REA и состояние собственной реализации различаются. Общий статический dispatch шести Actions и дополнительные границы описаны в [TangerineResearch.md](TangerineResearch.md#actions-dispatch-и-подтверждённая-семантика). «Сжать в ZIP» — отдельное седьмое Action Yuzu по запросу владельца; эта функция не приписывается Tangerine/REA и не добавляет File tools.

| Action | Реализация 0.1.0 | Состояние проверки |
| --- | --- | --- |
| `airDrop` | Системный NSSharingService, удержание scoped URLs до completion | Физический AirDrop gate отложен |
| `float` | Полка ссылок, add к существующей или новая, drag-out copy, Remove/Close не удаляет оригиналы; без persistence между запусками | Модель/реальный drag-out и Sandbox взаимодействие требуют отдельного подтверждения |
| `copy` | File URLs в NSPasteboard.general | Clipboard/Finder paste и scope lifetime в реальных приложениях — отложенный gate |
| `move` | Выбор destination, очередь файловой операции, свободные имена, dedup/ancestor filtering. Файлы между томами: copy + verify перед удалением; каталоги между томами отклоняются до копирования | Есть Core fixtures; физический picker/Sandbox gate отложен; межтомное перемещение каталогов unavailable в prerelease |
| `copyPath` | Текст путей через newline | Конкретные системные paste targets вручную не проверены |
| `openTerminal` | NSWorkspace + Terminal, каталог либо parent файла/package, dedup | Folder-mapping fixture есть; фактический Terminal/Sandbox gate отложен |
| «Сжать в ZIP» | Один архив из выбранных файлов/папок, рядом с первым input, свободное имя; оригиналы не изменяются | Собственная запрошенная функция; fixtures создания/отмены и Sandbox self-check прошли |

Собственный порядок Actions выбран по enum; точный порядок лепестков оригинала и визуальная parity не установлены. Новые ручные Finder/Sandbox/AirDrop/Terminal проверки владельцем отложены. Эти gates остаются открытыми в prerelease.
