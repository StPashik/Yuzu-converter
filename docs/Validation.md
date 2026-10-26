# Проверка выпуска 0.1.0

27 октября 2026, macOS 26.6.2 на Apple Silicon. Исходники после ZIP/QA/CRLF исправлений заморожены. Независимые заключения находятся в QA.md и NpmQA.md.

| Проверка | Результат |
| --- | --- |
| `swift test --scratch-path .build/verification` | 26 passed, 0 failed, 0 skipped |
| Intel bundle: `swift test --arch x86_64 --scratch-path .build/verification-x64` + `arch -x86_64 .../xctest <bundle>` | Компиляция успешна; штатный arm64 SwiftPM helper не загрузил Intel bundle, затем Intel XCTest под Rosetta выполнил 26/26 без ошибок |
| `npm ci --ignore-scripts --offline`, `npm test` | 13 passed, 0 failed, 0 skipped; runtime-only dependencies отсутствуют |
| `bash scripts/build-app.sh arm64` и `x64` | Архивы собраны, Info.plist, codesign strict и lipo проверены |
| `.app/Contents/MacOS/YuzuApp --self-check` | Sandbox arm64 и x64 (Rosetta): DOCX/textutil roundtrip, CSV/XLSX, ZIP/TAR и ZIP Action прошли в собственном temp |
| `npm pack --pack-destination dist` | Пакет собран с обоими SHA-256 в manifest, prepack прошёл; 7 файлов, без бинарников и зависимостей |
| Иконки приложения/menu bar | SHA-256 обеих копий совпадает с разрешёнными оригиналами Yuzu Mac App |

Swift fixtures включают реальную обработку PDF всех страниц при 300 DPI, EXIF orientation, native audio/video, DOCX/EPUB structure, quoted/CRLF CSV, XLSX/ODS namespaces/row groups/overflow, ZIP creation, archive collisions/traversal/symlinks, отмену subprocess и сохранность существующих файлов. FFmpeg fixture прошёл с отдельно установленным FFmpeg в developer-контексте; готовая Sandbox `.app` внешний FFmpeg не запускает.

Build script запускался вне sandbox агента: вложенный sandbox SwiftPM в ограниченной среде не запускает manifest. Это ограничение инструментальной среды; entitlements готовой `.app` сохранены и проверены.

Физические Finder drag, Powerbox/bookmark recovery с внешними файлами, AirDrop, Terminal, VoiceOver и перенос с полки вручную не проверялись по установленному ограничению. Sandbox self-check внутри контейнера не подменяет эти проверки. Intel hardware, macOS 13 и другие версии macOS отдельно не запускались. Реальный EXDEV для папки не моделировался; отказ до копирования проверен статически. Перенос файла между томами сравнивает только size/mtime исходника, без хеширования.

Подпись ad-hoc, Developer ID/notarization отсутствуют. Поэтому выпуск отмечен preview; полная совместимость с Tangerine не заявляется.
