# CI and media reuse

Every code PR into develop/main runs native Apple Silicon and Intel jobs. Each job verifies its actual CPU, builds/runs XCTest with the bundled media tools required, runs installer tests, builds an architecture-specific signed Sandbox archive, and verifies it. Metadata-only documentation/feed PRs retain route/feed checks and may omit native work. Releases still require both native jobs for application changes.

The expensive pinned FFmpeg/FFprobe build is reusable. `media_cache.py` derives an exact key from architecture, the source manifest, build/cache scripts, SDK version/build, clang version, and the macOS 13 deployment contract. It validates all nine required helper/configuration hashes, executable permissions, CPU, system runtime dependencies, and four pinned source archive hashes. Missing/stale tools or configurations trigger a rebuild. A pinned source-archive SHA-256 mismatch stops the build; remove the bad local archive or cache entry before retrying. No broad restore key is used.

The cache contains `.build/media-<arch>` and `.build/media-sources` only. Portable configuration copies and a receipt travel beside the tools; source packaging does not read an old runner's temporary directory. Signing identities, update keys, application containers, Swift checkouts, and old project caches are excluded.

## Trusted warming

The **Warm media cache** workflow runs on reviewed main/develop pushes and can be dispatched on either branch. Only this workflow saves reusable entries. PR CI restores entries and verifies their contents; it never saves a PR build into a shared cache. GitHub scopes PR-generated caches to their merge ref, so saving only inside PRs would not accelerate the next unrelated feature/release PR. The native runners and toolchain keys match between warming and PR jobs. See GitHub's [cache scope and matching rules](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching).

A cold branch/toolchain still performs the complete build. A warm run skips compilation of the media executables; all Swift, Node, Sandbox, and archive checks remain. Cache loss/eviction is a performance issue and cannot bypass validation. Cache entries are immutable: if an exact entry is repeatedly rejected, delete that entry through GitHub's cache UI or change the cache schema after investigating; do not weaken validation.

## Local commands

```sh
python3 -m unittest discover -s Tests/scripts -v
python3 scripts/media_cache.py key arm64
python3 scripts/media_cache.py verify arm64
python3 scripts/build-media.py arm64 --reuse
python3 scripts/build-media.py x64 --reuse
```

Omit `--reuse` to force a cold build. Both `build-app.sh` and corresponding-source packaging require a valid build receipt. Release media tests must use the correct architecture's tools and `YUZU_MEDIA_REQUIRED=1`, so an unavailable helper fails instead of silently skipping the video matrix. [Bundled media](Bundled-media.md) lists codec/license limits; [Releasing](Releasing.md) defines the independent publication gates.
