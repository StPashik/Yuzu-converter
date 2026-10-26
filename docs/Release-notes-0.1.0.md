# Yuzu Converter 0.1.0 — предварительный выпуск

Новая нативная Sandbox `.app` для macOS 13+, написанная с нуля после статического разбора Tangerine через REA. В выпуске — конвертация, шесть исследованных Actions и собственное седьмое действие «Сжать в ZIP» по отдельному запросу владельца. File tools отсутствуют. Это частичная реализация целевого поведения с собственными стилями, а не заявление о полной копии или production readiness.

## Установка

```sh
npm install -g https://github.com/StPashik/Yuzu-converter/releases/download/v0.1.0/stpashik-yuzu-converter-0.1.0.tgz
yuzu-converter
```

Нужны Node.js 20.11+ и npm. Установщик выбирает arm64/x64, проверяет встроенный SHA-256 и устанавливает приложение в `~/Applications`. npm registry не используется. Архивы `.zip` также можно установить вручную; каждый содержит `Yuzu Converter.app`.

## Что вошло

- Menu bar без Dock/главного окна; настройки и выход из меню.
- Иконка приложения и векторный значок menu bar из собственного Yuzu Mac App — исключение по прямому запросу владельца. Старый код, остальные ресурсы и ресурсы Tangerine не переносились.
- Shift — конвертация, Control — Actions; обратное назначение в настройках, переключение колеса и Escape.
- Actions: AirDrop, полка, file clipboard Copy, Move в выбранную папку, Copy Path, Terminal и «Сжать в ZIP».
- «Сжать в ZIP» объединяет выбранные файлы и папки в один архив рядом с первым input под свободным именем. Оригиналы сохраняются. Эта функция не является выводом REA о Tangerine.
- Системная конвертация изображений; PDF → все страницы JPG/PNG при 300 DPI или имеющийся текст TXT/MD.
- Нативные Audio → WAV/AIFF/M4A и Video → MP4/MOV для входов, которые декодирует/экспортирует macOS.
- Текстовые документы/DOCX, простой reflow EPUB, values-only XLSX/ODS/CSV/TSV со всеми листами, SRT/VTT/TXT и ZIP/TAR/TAR.GZ.
- Свободные имена результатов, сохранность исходников, scratch staging, отмена и scoped bookmarks для доступа к папке вывода.

## Ограничения

FFmpeg/FFprobe/LibreOffice не поставляются и не запускаются из Sandbox release. PAGES, PPT/PPTX, legacy XLS, textClipping, PDF → editable Office, большинство дополнительных audio/video encoders и GIF conversion в этой `.app` недоступны. Дополнительные внешние движки возможны только при developer `swift run`; это не возможности готового выпуска.

DOCX сохраняет редактируемый rich text в пределах системных readers/writers; точное Office layout и objects не обещаются. EPUB — простой текстовый reflow без сохранения исходных styles/assets. Таблицы переносят значения как строки; формулы, типы, стили и charts/assets не сохраняются. CSV/TSV экспортирует все листы отдельными файлами в папку, PDF таблицы — текстовое представление. MD output — plain text с расширением `.md`. OCR отсутствует.

PDF pages больше 32 768 px по стороне или 64 MP при 300 DPI отклоняются вместо уменьшения DPI. WebP/AVIF output и другие decoder-dependent цели появляются только при доступности системного writer/reader. GZIP поддержан как TAR.GZ; standalone gzip stream не конвертируется.

Сборки подписаны ad-hoc, без Developer ID и notarization. Gatekeeper может блокировать первый запуск; подпись не удостоверяет разработчика. Полка хранит ссылки до закрытия, без восстановления между запусками.

Move каталогов между томами отклоняется до копирования; оригиналы не удаляются. Для отдельных файлов межтомный перенос выполняет copy + проверку данных перед удалением исходника. Это явное ограничение предварительного выпуска.

## Проверки и открытые gates

Итоговый прогон: 26/26 Swift tests (22 Core + 4 App) на arm64 и x86_64 через Rosetta, 13/13 Node tests. Оба архива собраны и проверены codesign/lipo; подписанная Sandbox `.app` прошла self-check DOCX/textutil, XLSX, ZIP/TAR и ZIP Action. Fixtures покрывают content detection, пересечение целей, PDF/pages/DPI, текстовые outputs, values-only таблицы, субтитры, архивы, сохранность файлов/отмену и native media baseline. Это не проверка всех candidate pairs и профилей файлов.

Новые ручные Finder drag, Sandbox grants/bookmark recovery, AirDrop, Terminal и drag-out полки отложены. Сборка arm64/x64 не доказывает runtime на Intel и всех версиях macOS. Точный wheel order оригинала, pixel parity и полная fidelity конвертации не заявляются.

Полный целевой инвентарь из 46 cases, реальные ограничения и границы проверки: [Conversion matrix](https://github.com/StPashik/Yuzu-converter/blob/v0.1.0/docs/Conversion-matrix.md). Метод и Evidence: [Tangerine research](https://github.com/StPashik/Yuzu-converter/blob/v0.1.0/docs/TangerineResearch.md). Состав и лицензии: [Third-party notices](https://github.com/StPashik/Yuzu-converter/blob/v0.1.0/THIRD_PARTY_NOTICES.md).
