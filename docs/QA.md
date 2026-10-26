# Независимый QA: preview 0.1.0

Дата: 27 октября 2026. Проверена текущая рабочая копия до release commit. Область независимого review: `Sources/YuzuCore`, `Sources/YuzuApp`, вызываемые контракты, относящиеся к исправлениям fixtures, `scripts/build-app.sh`, `Package.swift`, `Resources/Info.plist` и entitlements. Исполнитель этого review писал npm-установщик, поэтому его собственные npm-тесты не считаются независимой проверкой установщика; отдельный результат находится в [NpmQA.md](NpmQA.md).

## Вердикт

В повторно проверенном статическом scope существенных незакрытых замечаний не осталось. Реализация подходит для предварительного выпуска с ограничениями, перечисленными в [Conversion-matrix.md](Conversion-matrix.md). Это не подтверждение полной parity с Tangerine или готовности всех candidate pairs.

Итоговый автоматический прогон после последней правки CR/LF/CRLF выполняет менеджер. Этот reviewer не запускал параллельную Swift-сборку, тесты, приложение или ручные Finder/Sandbox проверки. Итоговые pass counts, готовность архивов и результат запуска подписанной `.app --self-check` на момент записи документа не подтверждены этим review и не приписываются ему. Менеджер должен зафиксировать фактические результаты перед публикацией.

## Повторно проверенные исправления

| Сценарий из первоначального review | Что проверено в текущем коде | Автоматическое свидетельство в исходниках |
| --- | --- | --- |
| Выход во время работы движка мог оставить процесс и scratch | `applicationShouldTerminate` отменяет задания, ждёт текущую обработку и определение форматов, затем отвечает AppKit; при завершении очередь больше не запускается | Process cancellation fixture существует; реальный выход приложения этим reviewer не выполнялся |
| Powerbox мог сохранить другую папку как родителя исходника | Свежий и восстановленный URL проверяются `AccessStore.isParent`; ошибочные grants освобождаются, набор уже полученных папок закрывается через `defer` при ошибке/отмене | `testOutputGrantMustBelongToTheActualSourceParent` |
| Sandbox release предлагал внешние FFmpeg/LibreOffice | `YuzuSandboxed=true` в Info.plist ограничивает `Tools.find` папкой `Bundle.Resources/Tools`; нативный audio/video fallback проверяет доступность системного reader/exporter | Native audio/video fixtures; запуск готовой подписанной `.app` отдельно |
| Изменение вложенного файла могло остаться незамеченным при межтомном Move каталога | При `EXDEV` каталог отклоняется до copy/delete, оригинал сохраняется; поведение явно ограничено в требованиях | Ветка проверена статически; фактическое межтомное перемещение не запускалось |
| ODS repeated count мог переполнить `Int` | Верхняя граница проверяется через остаток доступного количества до сложения и умножения | `testODSRepeatedCountsCannotOverflow` |
| XML prefixes и ODS row containers приводили к пустому/неполному результату | Элементы и атрибуты сопоставляются по namespace URI; ODS header/group/rows containers обходятся; отсутствие листов даёт ошибку | `testPrefixedXLSXAndWrappedODSKeepRowsAndNamespaces` |
| XML-текст копировался во все узлы stack | Упорядоченные text/child fragments хранятся в собственном узле, смешанный текст и CDATA сохраняют порядок; прежнее размножение текста по всем предкам удалено | Mixed XML/CDATА assertion в table fixture |
| Архивные имена могли перезаписывать другой распакованный файл | Проверяются повторения, регистр, нормализованные имена и implicit parents; файл создаётся с `O_EXCL`/`O_NOFOLLOW`; ссылки и выход за scratch отклоняются | `testArchiveRejectsDuplicateCaseAndDirectoryAliasesWithoutTruncation` и прежние symlink/traversal fixtures |
| RIFF/FORM offset считался в Unicode-символах | Container marker читается из байтов `8..<12`; двоичный размер больше не сдвигает WAVE/AIFF/AVI/WebP marker | `testRIFFByteOffsetsAndLargeQuotedCSVContentDetection` |
| Большой CSV распознавался по оборванному quoted prefix | При табличных признаках CSV разбирается полный bounded текст, а не неполный 64 KiB prefix | Большой quoted CSV в том же fixture |
| Windows rows пропускались, а CRLF внутри поля менялся | Детектор использует `.newlines`; CSV/TSV parser различает CR/LF/CRLF вне quotes и сохраняет исходный newline внутри quoted field; writer заключает такие поля в кавычки | `windowsRows` round-trip assertion в том же fixture |
| Portrait JPEG превращался в sideways PDF | ImageIO transform применяет EXIF orientation при исходном максимальном размере, размеры PDF берутся из преобразованного изображения | `testJPEGOrientationIsAppliedToPDFWithoutDownsampling` |

Наличие fixture в таблице означает, что его содержание просмотрено; результат его исполнения должен подтверждаться логом финального прогона.

## ZIP Action и очередь UI

`FileOperations.compress(_:in:) throws -> URL` — публичная синхронная операция Core. Она нормализует выбранные источники, убирает повторения и уже включённых потомков, отклоняет одинаковые верхние имена, ссылки и размещение ZIP внутри сжимаемого каталога. Данные сначала копируются в собственный scratch; готовый ZIP проверяется через `ArchiveReader` и публикуется с `RENAME_EXCL` под свободным именем. Исходники не перемещаются и не удаляются. Отмена проверяется до работы, при обходе/копировании, в процессе и перед публикацией.

В Actions присутствует «В ZIP». UI получает доступ к родительской папке первого input и передаёт операцию в общую очередь как `JobKind.compress`; сам Core вызывается внутри `Task.detached`. Scoped source URLs и destination grant удерживаются заданием, отмена передаётся worker, destination grant освобождается после завершения. Fixtures `testCompressFilesAndFolderWithoutOverwritingOrFollowingLinks` и `testCompressCancellationCreatesNoArchive` проверяют содержимое, свободное имя, сохранность оригиналов, отказ на links/одинаковых именах и отмену.

Обработка drop отложена до следующего main tick после создания `ScopedFiles`, чтобы закончить AppKit drop до Powerbox/sharing. Clipboard copy удерживает source lease до изменения `NSPasteboard.changeCount`. Это подтверждено чтением кода; физическая передача grants между Finder, clipboard и приложением остаётся отдельным отложенным gate.

## Упаковка и разрешённые иконки

Статически совпадают release/npm contracts: `Yuzu Converter.app`, executable `YuzuApp`, bundle ID `com.stpashik.yuzu-converter`, version `0.1.0`, minimum macOS `13.0`, asset names `Yuzu-Converter-0.1.0-arm64.zip` и `Yuzu-Converter-0.1.0-x64.zip`. Скрипт ограничивает архитектуру, сверяет версии package/plist, подписывает entitlements, проверяет архитектуру через `lipo` и создаёт ZIP с одним app root через `ditto --norsrc --keepParent`. Пользовательская установленная `.app` скриптом сборки не затрагивается.

По отдельному разрешению владельца перенесены только две собственные иконки. Read-only SHA-256 сравнение с указанными оригиналами подтвердило совпадение:

- `Resources/YuzuAppIcon.icns`: `6a250b9e4853a92ad09a82b6b1e3e9bceb0b4063a2e6a3a37d001286737a5b86`.
- `Sources/YuzuApp/Resources/YuzuMenuBar.pdf`: `41876c86fa4ea93f5e9efcd27213aa210d67f338ad54694ddef341462713b518`.

App icon копируется как `Contents/Resources/Yuzu.icns`, на него указывает Info.plist. Menu bar PDF копируется в app resources; приложение сначала читает его через `Bundle.main`, а developer launch имеет fallback через `Bundle.module`. Другие старые исходники/история и ресурсы Tangerine этим review не переносились.

## Точные границы preview

- Для обычного файла между томами Move сравнивает размер и `modificationDate` исходника до и после копирования. Это проверка метаданных, без hash comparison, блокировки или файлового snapshot; полная защита от конкурентного изменения с теми же метаданными не заявляется. При обнаруженном изменении обе копии сохраняются. Каталоги между томами отклоняются до копирования; фактическая ветка `EXDEV` не прогонялась этим reviewer.
- Полная матрица Tangerine не реализована; форматные, codec/layout и values-only ограничения остаются в Conversion-matrix. Архивные лимиты и отказ на links/collisions относятся также к проверке создаваемого ZIP.
- Физический Finder drag, VoiceOver во время drag, Powerbox/bookmark recovery, clipboard paste, AirDrop, Terminal и shelf drag-out отложены владельцем. Новые ручные проверки не запрашивались и не выполнялись.
- Сборка x64 не доказывает запуск на Intel; min macOS 13 в metadata не доказывает runtime-проверку на macOS 13. Подпись, notarization, Gatekeeper и установка из опубликованного Release должны описываться только по фактическому результату поставки.

Review меняет только этот документ; code/commits и фоновые процессы не создавались.

## Результаты менеджера после review

Финальные 26 Swift tests прошли на arm64 и x86_64 через Rosetta; 13 Node tests прошли. Оба signed Sandbox архива прошли self-check, установку в временные home, codesign strict и проверку версии. Команды и точные границы свидетельства записаны в [Validation.md](Validation.md). Это дополнение менеджера к независимому статическому review; отложенные физические gates остаются в силе.
