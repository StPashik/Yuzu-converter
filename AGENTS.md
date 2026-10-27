# Yuzu Converter

Communicate with the owner in Russian. Use English for documentation, code comments, technical diagnostics, and GitHub releases. The app defaults to English and offers English, Russian, German, French, and Spanish UI; localized resource values are intentionally in those languages. Build the native macOS 13+ app from scratch. Do not alter or import old checkouts, source code, Git history, or caches. The owner explicitly permits reusing the Yuzu Mac App application icon (including its PNG for documentation) and menu bar icon. Do not copy proprietary Tangerine resources or binaries. Research reports may be read as references; separate observations, inferences, and unknowns.

Keep docs/Requirements.md and the accepted docs/Architecture.md current. Scope includes conversion and seven Actions, including the owner-requested Compress to ZIP. Exclude File tools. Do not silently reduce requirements to match a backend; record limitations in docs/Conversion-matrix.md.

Follow GitFlow: feature/* from develop, independent QA, merge --no-ff; main and tags are for releases. The owner's request authorizes publishing to StPashik/Yuzu-converter. Never force push or rewrite published tags/assets.

Make releases useful to people: clear English copy, direct downloads, a short quick start, accurate format support, and accessible documentation. Explain why consequential code choices exist in concise comments; do not narrate obvious code.

Run automated checks in separate scratch paths. New manual checks remain deferred; label physical Finder/Sandbox gates as unverified. Never run concurrent Swift builds in the same scratch path. Verify actual test results, licenses, artifact checksums, version consistency, and known limitations before publishing.
