# Tangerine 2.0.2 — исследование конвертации и Actions

Дата исследования: 27 октября 2026. Объект: установленный `/Applications/Tangerine.app/Contents/MacOS/Tangerine`, версия 2.0.2 (9), arm64, macOS 13+, `LSUIElement=true`. SHA-256 executable: `7691b34cc2c728aaf280041c0a13adef3e5192c43cb3e886a19ae4c69ea92928`; Mach-O UUID: `15C64A52-799E-379D-BDF0-2F29BCBC2617`.

Это разбор поставленного приложения, а не отчёт о готовности Yuzu. Проприетарные код, ресурсы, binaries и pseudocode в репозиторий не переносятся. File tools не входят в предмет углубления Actions.

## Источники и границы достоверности

Новый REA overview, provider Ghidra 12.1.4: 38 931 procedures и 71 978 strings, Evidence `ev_93a92bdfd820363e8d465862d7d8163f5ebd943cd0d2bcb99e9653fa37461f5e`. Выполняется статический анализ; это не запуск Tangerine и не наблюдение реального drag, clipboard, AirDrop или Terminal.

Для конвертации переиспользованы собственные исследовательские данные от 22 октября 2026 для того же SHA-256: прежний `docs/TangerineResearch.md`, `candidate-matrix.json`, `enum-reflection.json` и индекс REA Evidence из `Yuzu Mac App/build/research/tangerine-2.0.2/`. Они используются только как reference data. Исходники и Git-история прежнего Yuzu не используются.

В отчёте различаются: **статический факт** — явный вызов/байты/ветка в Evidence; **вывод** — интерпретация связанных наблюдений; **не проверено** — для утверждения нужен runtime или дополнительный control-flow анализ. Ghidra восстанавливает pseudocode, а не исходный Swift. Swift closures, enum ABI, self/context и jump tables могут быть восстановлены неполно.

## Конвертация и устройство колеса

Из reference REA: колесо строится из упорядоченных targets. Для N целей угол центра `i` равен `(N == 3 ? π : π/2) − i × 2π/N`, inner radius 48.64 pt, outer radius 119.52 pt. Один path участвует и в rendering, и в hit-test. Промежутки между лепестками не являются целями. Центр показывает выбранную цель, а idle-подпись источников хранится отдельно. Позиция ограничивается `visibleFrame` выбранного экрана. Evidence геометрии: `ev_95f12784ddb5a5864c2ca374be7b173e003d21ea27052591600cfc87fb2f4d3e`; hit-test: `ev_835a2c74068822d184d7423a7faffa0c8784cf3cdd72888bb08a9110305ab388`.

Tangerine обнаруживает drag глобальным polling `NSPasteboardNameDrag`, modifiers, левой кнопки и Escape; таймер переключается между 0.1 с и 1/60 с. Сам drop принимает AppKit `NSDraggingDestination` и повторно проверяет URL. В Yuzu глобальный polling drag pasteboard не переносится: действуют собственные требования поддерживаемого AppKit drag. Reference Evidence повторной проверки drop: `ev_1097fb121cd6812c9119ec02c94498b9608dc6f6e74bf36c1022008d349d5ebb`.

Детектор Tangerine не универсально content-first: сначала учитывает имя/расширение, затем ImageIO/media/ZIP/OLE/package проверки; при EPERM возможен provisional format. Это не отменяет требования Yuzu определять формат по содержимому. Reference Evidence source/provisional: `ev_cce1507c8ec17acb62081fb72e56735155300f96fef3d599ec9c0e9b79e5b446`.

Матрица кандидатов дополнительно фильтруется availability движков. Для смешанных inputs reference-код требует одну внутреннюю категорию и пересекает допустимые пары каждого источника. ImageIO writer, FFmpeg и отдельные encoder predicates влияют на доступность. Поэтому таблица ниже не означает, что каждая пара работает на любом Mac.

## Движки и качество: что установлено ранее

| Область | Статические наблюдения и пределы |
| --- | --- |
| Images | ImageIO/CGImageSource/CGImageDestination; WebP-ветка использует FFmpeg/libwebp. Наличие bundled инструмента само по себе не доказывает использование каждого пути |
| Audio/Video | FFmpeg-ветка с проверкой инструмента/encoder. Качество всех codec/container сочетаний не проверено |
| Documents/PDF | Нативный dispatcher, PDFKit/CoreGraphics, Java bridge для Office, JS-ресурсы для Pages/DOCX; полный native → каждый JS entrypoint не прослежен |
| Slides/Spreadsheets | Java helper с POI/PDFBox. PPT/PPTX → изображения проходит через PDF. Сложные объекты могут отклоняться; это не полный renderer PowerPoint/Excel |
| Pages | Writer изменяет editable body и поддержанные объекты, повторно читает пакет; точность макета и открытие в Pages не проверены |
| Subtitles | Собственные parser/serializer SRT/VTT/TXT, UTF-8 atomic write. Полная семантика cues/tags не проверена |
| Archives | Извлечение во временный каталог и повторная упаковка; GZIP target получает `.tar.gz`. Защита всех extraction/packing helpers в reference не исследована |

Существенные ограничения Tangerine из reference: PDF → изображения ограничивает scale до 300 DPI, 8192 px по стороне и 16 MP; фактические 300 DPI не гарантируются для большой страницы. PDF → PPTX вставляет картинку страницы, а PDF → XLSX извлекает текстовые pieces в строковые ячейки. Это не восстановление редактируемых объектов/таблиц. Требования Yuzu к реальным 300 DPI и честной редактируемости сохраняются.

## Actions: dispatch и подтверждённая семантика

Найдены шесть enum-имён: `airDrop`, `float`, `copy`, `move`, `copyPath`, `openTerminal`. Общий dispatcher `FUN_100030dc4` отделяет conversions, File tools и Actions по старшим битам. В Actions-ветке подтверждены следующие теги и маршруты. Evidence: `ev_0aacc56cdbaabd563a64bc7c11d1fa26bdd717f6c5c7f1593a40eaffd55564ad`.

| Тег | Action | Маршрут |
| --- | --- | --- |
| `0x80` | AirDrop | `FUN_10003370c` |
| `0x81` | Float | `FUN_100033ae8` |
| `0x82` | Copy | `FUN_100145fc0` |
| `0x83` | Move | main-queue callback `FUN_100039c78` → общий helper `FUN_100033e94` → `FUN_100146ab0` |
| `0x84` | Copy Path | `FUN_100146450` |
| `0x85` | Open Terminal | main-queue callback `FUN_100039b98` → общий helper `FUN_100033e94` → `FUN_10030b3c8` |

Порядок тегов и reflection сам по себе ещё не доказывает порядок лепестков UI. Адреса строк `copyPath`/`openTerminal`: `0x1008a9a39`/`0x1008a9a42`. Считанный static object `0x1009dc230` содержит 22 значения и не является массивом шести Actions; использовать его как доказательство wheel order нельзя.

- AirDrop: `FUN_10003370c` создаёт sharing-controller через service factory, назначает completion, удерживает controller в UUID dictionary и ставит `FUN_10003af88` на main queue. Constructor `FUN_100002310` нормализует входы в `sourceURLs`, сохраняет service и инициализирует пустой `scopedURLs`, `hasStarted=false`, `hasFinished=false`. Evidence: `ev_22faed1c28879b1d66a3352cf224ba0410566c49964dbc43ae748fb55fa92f58` и `ev_edc4cd80e9015490c15a28233367726e15c7a4c7ededb78154827edd0ed7997b`. Это подтверждает отдельный lifecycle передачи; callback start восстановлен как пустое тело, поэтому фактический `performWithItems`, начало scopes, успешная отправка и UI получателя здесь не доказаны.
- Copy в контекстном меню полки: `FUN_10020749c` вызывает `NSPasteboard.general.clearContents` и `writeObjects(URLs)`. Новое Evidence: `ev_b81c7aa74b5cd1f02f35187f1d7d630e8c20ac8eaad8b7d049276a6971e543d7`. Это подтверждение конкретного пути полки, а не достаточное доказательство dispatch действия Copy на колесе.
- Reference strings: `FileClipboardController.swift` (`0x1008e7e40`), ошибки записи файлов/путей в clipboard (`0x1008e7e00`, `0x1008e7ea0`), требование local paths (`0x1008e7e70`). Пустые xrefs по строке и адресу минус 0x20 не доказывают отсутствие использования: Swift strings могут формироваться иначе.
- Terminal reference strings: `com.apple.Terminal` (`0x1008ed990`), настройка `fileActionsTerminalApplication` (`0x1008ed9b0`), `TerminalFileAction.swift` (`0x1008edb70`), сообщение о поддержке только local files/folders (`0x1008edba0`). Правило выбора directory подтверждено новым helper ниже; default opener остаётся отдельной границей.
- Float reference strings: добавление к существующей полке и создание новой (`0x1008ed9d0`, `0x1008ed9f0`), `FloatingFileWindowController`, `FloatingFileDragSourceView`, «Close Float without deleting files», «Remove from Float», прикрепление у края и открепление. Эти строки указывают на несколько режимов полки, но не доказывают механизм хранения и drag-out.

### Copy и Copy Path

**Статический факт:** Copy колеса пишет файловые URL в clipboard, а не выбирает папку копирования. `FUN_100145fc0` сначала требует local file URLs, начинает security-scoped access, сбрасывает предыдущее clipboard-состояние и вызывает `clearContents` / `writeObjects`. Ошибка записи превращается в NSError. После успеха controller хранит исходные URLs, clipboard changeCount и повторяющийся таймер 1 с. Evidence: `ev_7cd73c69b99d1430cc4166e36d97b0592765601e6dc5d1df5a7ca8aa1b6fe948`.

Cleanup `FUN_100145f08` инвалидирует таймер, очищает сохранённые inputs и вызывает `stopAccessingSecurityScopedResource` для ранее открытых URLs. Evidence: `ev_77b30a281daff29d28889b288e642444114f53f9bcaff7fdc81504cbe9a93188`. Это показывает, что lifetime scopes не ограничен выходом из функции Copy. Условие срабатывания cleanup по таймеру требует отдельного анализа callback.

**Статический факт:** Copy Path `FUN_100146450` требует local URLs, берёт `standardizedFileURL.path`, объединяет пути символом newline и записывает обычный `NSPasteboardTypeString`. Shell quoting в этом пути не видно. При неуспешном `setString` возвращается ошибка. Evidence: `ev_5237a4296cd34b4776639d9ad16c2e2cafa2ab93b198bea431e47c1be1c9a792`.

### Move

`FUN_100146ab0` проверяет local URLs, нормализует и устраняет повторения paths. При одновременном выборе каталога и его дочерних элементов формирует верхний набор: дочерние элементы внутри уже выбранного каталога исключаются. Для проверки вложенности видны `resolvingSymlinksInPath` и prefix с разделителем `/`. Security-scoped URLs сохраняются для callback. Далее вызывается injected destination chooser; исходное расположение — родитель первого отфильтрованного input. Evidence: `ev_3fcb6a95df8d2cf479c60c6d51a70b1f13eab52c1fdc1f3417dd2ba829928690`.

**Вывод:** Move организован как выбор назначения с последующим callback, отдельно от Clipboard Copy. Само перемещение, правило коллизий, отмена picker и поведение частичного сбоя ещё требуют анализа worker/callback; по одной входной функции их нельзя считать доказанными.

### Open Terminal

`FUN_10030b3c8` отклоняет non-local URLs, получает URL выбранного приложения terminal через resolver и при отсутствии приложения формирует ошибку. Есть названия Terminal и iTerm2 и настройка выбора приложения. После начала scoped access входы передаются в `FUN_10030d1b0`, затем в injected opener с URL приложения и completion. Evidence: `ev_38fd3ed3657be8c34fa6420def603331b3089dd2587ad3de0798b4617a43ef47`.

`FUN_10030d1b0` проверяет `isDirectory` и `isPackage`. Для обычного каталога выбирается сам `standardizedFileURL`; для файла и package-directory выбирается `deletingLastPathComponent().standardizedFileURL`. Это существенно для `.app` и других package folders: Terminal должен открыться рядом с пакетом. Результаты устраняют повторения по `.path`, сохраняя порядок первых появлений. Evidence: `ev_d5feaa832d64acf8ad7ba67c264fe696a9bf8fbe828ea71f0f6aee9716328fbe`.

Preference helper `FUN_10030d060` читает сохранённый выбор, принимает предусмотренные Terminal/iTerm2 варианты и возвращает `com.apple.Terminal` по умолчанию. Evidence: `ev_18d16b86411f7860552c9a48b713b11c4f50b30db26bf16a6f20d82c9003ba47`.

**Не проверено:** реализация default opener и реальное открытие системного terminal. Наличие injected opener не доказывает использование shell, AppleScript или NSWorkspace. Для Yuzu вызов NSWorkspace с массивом folder URLs и Terminal application URL выбран самостоятельно; совпадение пути Tangerine этим исследованием не заявляется.

### Float

`FUN_100033ae8` различает добавление к существующей полке и создание новой. В первой ветке вызывается group-model add и `orderFrontRegardless`. Во второй создаётся `FloatingFileWindowController`, назначается onDismiss и controller сохраняется по UUID в `floatingFileControllers`; отдельный массив `floatingFileControllerOrder` сохраняет порядок. Evidence: `ev_bfdfd800bb7eb4fd66efdd956106887c0197810e16f95c1b044f591702cecb0e`.

Constructor `FUN_100219fd8` создаёт group model из inputs и прозрачную панель с level 3, `hidesOnDeactivate=false`, `releasedWhenClosed=false`, SwiftUI hosting view и явными callbacks. `onFilesDropped` направлен в group-model helper `FUN_1001fd2f0`. Evidence: `ev_4387a8009997fd6ce364c9e1107ead8d973e3ea187ec203929521070f9bac285`.

Group-model wrapper `FUN_1001fe134` вызывает тот же `FUN_1001fd2f0` и при изменении запускает paper-clip retraction feedback с generation token и задержкой 0.36 с. Evidence: `ev_3a5c72bd435d1e7832e8de721d0a3887c6a4d8834ada3618727c30a2f1e1548d`. Это не доказательство фактического копирования файлов на диск: способ хранения элементов, dedup, lifetime security scopes, persistence между запусками и поведение drag-out остаются отдельными вопросами.

Найдены настоящие AppKit drag-source entrypoints: `mouseDragged:` передаёт управление в `FUN_100203834`, а `draggingSession:endedAtPoint:operation:` — в `FUN_100233830`. Evidence: `ev_d1daef634695eaefff077ba34ec03c6ca34044130f0b9600684b2bbf091663c9` и `ev_0c31ee9736caa2985a9aed718e4e57e082209f6dd2837f7c97e29b685a3da87e`. Тела этих следующих helpers не анализировались, поэтому source operation mask, удаление после drop и работа file promises остаются неизвестными.

Контекстное `removeFromFloat` вызывает `onFilesRemoved(items)`, если callback назначен. В самом entrypoint нет вызова удаления файлов с диска. Evidence: `ev_991546377d0bfdb85cadd6dd0cec285f42c871425983eb9375146f922e5e27ba47`. Без анализа callback это не доказательство полного поведения Remove; отдельно есть строка «Close Float without deleting files».

## Что переносится в собственную реализацию

В Yuzu используются собственные код и ресурсы. Разделение clipboard Copy и destination Move, parent-directory правило Terminal, фильтр рабочих пар и пересечение mixed inputs опираются на приведённые наблюдения. Выбор публичных AppKit/NSWorkspace механизмов, enum-порядок собственного Actions wheel и оформление — решения Yuzu.

Точный UI-порядок Tangerine не установлен. Собственные стили, промежутки лепестков, control points, анимации и визуальные эффекты являются приближением; совпадение внешнего вида до пикселя не проверялось. Требования Yuzu к supported file drag, содержимому формата и 300 DPI не заменяются ограничениями оригинала.

## Покрытие вопросов

| Вопрос | Статус и граница |
| --- | --- |
| Шесть Actions и общий dispatch | Статически подтверждены tags и маршруты; UI-порядок не установлен |
| AirDrop | Подтверждены source normalization, service factory, controller retention/completion; start/perform boundary и runtime не прослежены |
| Copy clipboard или destination | Подтверждён clipboard файловых URLs; scopes удерживаются controller, callback таймера не углублён |
| Copy Path | Подтверждены standardized paths, newline, string pasteboard и ошибка записи |
| Move | Подтверждены local validation, dedup/ancestor filtering и destination-picker boundary; worker/коллизии/частичный сбой не прослежены |
| Terminal | Подтверждены local validation, выбор Terminal/iTerm2, папка либо parent package/file, dedup; default opener и runtime не проверены |
| Float | Подтверждены existing/new branches, controller UUID/order, model callbacks, drag-source entrypoints и Remove callback; storage/persistence/drag-out helpers не прослежены |
| Конвертация | Сохранены 46 статических candidate rows и reference engine/UI evidence; runtime fidelity не проверена |

Новые Evidence сохранены в локальном `build/research/rea-evidence.json`; на момент завершения отчёта 39 записей. Они получены REA в основной сессии менеджера и прочитаны исследователем из экспорта. Изолированная сессия исследователя не имела открытого target; повторный импорт и смена target не выполнялись. Сырые pseudocode и ресурсы в Git не добавляются.

Основная сессия затем закрыта менеджером с сохранением локальных артефактов для воспроизводимости: `rea-evidence.json` SHA-256 `1ecc6de967cf1be4b4a25c49069aa8d0b491faf13ab48e7a9682d93a89997bca`, `rea-snapshot.json` SHA-256 `fb3835b98369b65b4fefa8b9a63ef0e7bc4f2a2b254b8a05ea35650aa0beb69c`. Эти raw-файлы не включаются в Git.

## Проверка и неизвестное

Реальные конвертации Tangerine, drag/Escape, clipboard, AirDrop, Terminal, полка, Sandbox dialogs и fidelity на файлах не запускались. Новые ручные проверки владельцем отложены. Сохранённые candidate rows относятся к тому же executable, но не являются новыми runtime tests. Изменение функциональных требований по результатам ограничений Tangerine не выполняется.

## Полный статический candidate inventory

Ниже все 46 входных enum cases из reference `candidate-matrix.json`. Текущий формат и глобальные input-only цели уже удалены в каждой строке. Input-only цели: RAR, PPT, XLS, RTF, RTFD, textClipping; SVG отсутствует в изображениях как выход. HTML имеет пустой входной список, хотя встречается как цель экспорта.

Основание: assembly `ev_1bb1103bb8603c78d2e6023a61c0a2ddccdf9f907e59c243c316077a3f6dc403`, jump table bytes `ev_bbdfeda58ef6e4e484d39096289033716985a08d8cf636698b8748946e04dcce`, target array bytes `ev_851021840dc352177b2b80cf6635866ba0ca740f5bf1e4f9d242d66ce932948a`, single-format filtering `ev_b50f9b7323dd6e8ab35ee0bad484d7c977203be02ecc627442db0e295199d95d`, group intersection `ev_ed9142b85c43b0158675029b7105b60ed04366a0df9cbcfeb9fa599d6e8c3e09`.

| Вход | Статические кандидаты до runtime availability |
| --- | --- |
| jpg | png, webp, heic, tiff, avif, bmp, pdf |
| png | jpg, webp, heic, tiff, avif, bmp, pdf |
| webp | jpg, png, heic, tiff, avif, bmp, pdf |
| heic | jpg, png, webp, tiff, avif, bmp, pdf |
| tiff | jpg, png, webp, heic, avif, bmp, pdf |
| svg | jpg, png, webp, heic, tiff, avif, bmp, pdf |
| avif | jpg, png, webp, heic, tiff, bmp, pdf |
| bmp | jpg, png, webp, heic, tiff, avif, pdf |
| pdf | docx, pages, pptx, xlsx, jpg, png, epub, txt, md |
| mp3 | m4a, wav, flac, ogg, opus, aiff, wma |
| m4a | mp3, wav, flac, ogg, opus, aiff, wma |
| wav | mp3, m4a, flac, ogg, opus, aiff, wma |
| flac | mp3, m4a, wav, ogg, opus, aiff, wma |
| ogg | mp3, m4a, wav, flac, opus, aiff, wma |
| opus | mp3, m4a, wav, flac, ogg, aiff, wma |
| aiff | mp3, m4a, wav, flac, ogg, opus, wma |
| wma | mp3, m4a, wav, flac, ogg, opus, aiff |
| mp4 | mov, mkv, webm, avi, wmv, gif, mp3 |
| mov | mp4, mkv, webm, avi, wmv, gif, mp3 |
| mkv | mp4, mov, webm, avi, wmv, gif, mp3 |
| webm | mp4, mov, mkv, avi, wmv, gif, mp3 |
| avi | mp4, mov, mkv, webm, wmv, gif, mp3 |
| wmv | mp4, mov, mkv, webm, avi, gif, mp3 |
| gif | mp4, mov, mkv, webm, avi, wmv |
| docx | pages, pdf, txt, md, html, epub, png, jpg |
| pages | docx, pdf, txt, md, html, epub, png, jpg |
| ppt | pdf, jpg, png |
| pptx | pdf, jpg, png |
| txt | docx, pages, pdf, md, html, epub, jpg, png |
| md | docx, pages, pdf, txt, html, epub, png, jpg |
| rtf | docx, pages, pdf, txt, md, html, epub, png, jpg |
| rtfd | docx, pages, pdf, txt, md, html, epub, png, jpg |
| textClipping | docx, pages, pdf, txt, md, html, epub, png, jpg |
| html | — |
| epub | pdf, docx, pages, txt, md, html |
| xlsx | ods, csv, tsv, pdf |
| xls | xlsx, ods, csv, tsv, pdf |
| ods | xlsx, csv, tsv, pdf |
| csv | xlsx, ods, tsv, pdf |
| tsv | xlsx, ods, csv, pdf |
| srt | vtt, txt |
| vtt | srt, txt |
| zip | tar, gzip |
| tar | zip, gzip |
| gzip | zip, tar |
| rar | zip, tar, gzip |
