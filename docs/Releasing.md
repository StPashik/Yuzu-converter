# Releasing Yuzu Converter

Normal versions are stable GitHub **Latest** releases. Use prerelease status only for an explicitly requested beta/RC. Signing/notarization limitations belong in the release notes and do not select GitHub's release status. Historical preview releases and their assets remain unchanged.

Version 0.4.1 was Apple Silicon only. Version 0.4.2 restores separate arm64/x64 releases after native Intel CI and signed Sandbox verification passed. Both native architectures are required release gates. Advance each legacy feed only after the compatible new archive is public; published tags/assets remain immutable and Intel clients must never receive an arm64 archive.

The owner updates the installed app personally through **Check for Updates…**. Release work must leave `/Applications`, `~/Applications`, the global npm installation, and the running app alone. Test downloads, installs, and restarts only in isolated fixtures. Do not run a global installer or quit/relaunch the owner's app as a release step.

## PR and release sequence

1. Start `feature/<description>` from current `develop`. Implement and verify the change, open a PR into `develop`, wait for CI, and merge using **Create a merge commit**.
2. Create `release/<version>` from updated `develop`. Bump package/lockfile/app short versions and increment the integer app build. Update direct-download links, source-package links, release notes, and validation records. Write the English `docs/Release-notes-<version>.md` with its version heading and What changed section before preparing feeds: this exact Markdown is displayed inside the update offer and used on GitHub.
3. Build pinned media tools for both architectures when their recipe/manifest changed, then build both architecture-specific app archives with Xcode 26 or later. Verify the main executable's SDK is 26+, minimum OS is 13, and native-glass class imports are weak so older systems can load the fallback. Run the Swift/Node suites, both signed Sandbox self-checks, and isolated installation checks. Verify exact resource/license bytes, architecture, versions, source provenance, and known limits. Keep physical checks marked unverified until performed.
4. Run `node scripts/prepare-npm.mjs dist` and `node scripts/prepare-updates.mjs dist`. The latter signs/verifies both final archives and writes signed `dist/appcast-arm64.xml` and `appcast-x64.xml`. It must leave the live legacy `updates/` files unchanged. The private Yuzu key stays in its existing Keychain account.
5. Run `node scripts/verify-update-feeds.mjs dist`, pack the npm installer, package corresponding media source, and calculate final SHA-256 checksums. A rebuild requires regenerating all dependent signatures, manifests, packages, and checksums.
6. Commit release preparation on the release branch. Open its PR into `main`, wait for CI, and merge with a merge commit. Fetch the merged `main` and tag **that exact release-PR merge SHA** as `v<version>`. Push only the tag; do not push `main` directly.
7. Create a **draft** GitHub Release for the existing tag with both app ZIPs, npm tarball, corresponding-source archive, both appcasts, checksums, MIT license, and component notices. Compare every uploaded digest/size and the English body against the reviewed files.
8. Publish the draft with `--draft=false --prerelease=false --latest`. The Latest release and its signed feeds/archives become public together. Download and verify the public files and perform information-only Sparkle checks with isolated app identities. Do not install on the owner's Mac.
9. For older clients, copy both exact public signed appcasts into `updates/` on the release branch and open a separate PR into `main`. Verify both referenced downloads are already public, wait for CI, and merge. Do not regenerate or edit signed XML during this copy. The original application-release tag remains unchanged.
10. Open a release-branch PR back into `develop`, wait for CI, and merge with a merge commit. Report the release/PR links and tell the owner that the update is ready for their button click.

All merges into shared branches happen through PRs. Hotfix branches follow the same checks and return to both `main` and `develop`. Do not force-push, move published tags, replace published assets, or copy another project's signing keys.

## Commands

After the release PR has merged, substitute its reviewed merge SHA and version:

```sh
git fetch origin
git tag -a v<version> <release-pr-merge-sha> -m "Yuzu Converter <version>"
git push origin v<version>
gh release create v<version> dist/<version>/* --verify-tag --draft \
  --title "Yuzu Converter <version>" --notes-file docs/Release-notes-<version>.md
gh release edit v<version> --draft=false --prerelease=false --latest
```

The placeholders require real values; commands are documentation, not an unattended publishing script. Verify uploaded files before the final `release edit` command. GitHub Actions does not publish and receives no production signing credentials.

## Update channels and migration

New builds read `https://github.com/StPashik/Yuzu-converter/releases/latest/download/appcast-<arch>.xml`, where `<arch>` is `arm64` or `x64`. Each signed feed points to its compatible immutable versioned ZIP. **Latest** is a GitHub release status, independent of an app's ad-hoc signature or Apple notarization.

Versions through 0.4.0 read `main/updates/appcast-<arch>.xml`. Keep those bridge files for already installed clients. Both bridges advance through a publication PR only after their referenced compatible release assets are public. After a legacy user accepts the first new update, their app uses its architecture-specific Latest-release endpoint. Checking, downloading, installing, and restarting stay under the owner's control. To verify both legacy feeds, run `node scripts/verify-update-feeds.mjs updates arm64 x64`; artifact-directory verification defaults to the CPU list in `package.json`.

The app and nested helpers currently have ad-hoc signatures; Developer ID and notarization remain absent. Sparkle's Ed25519 signatures authenticate the feed/archive and must use the public key trusted by installed Yuzu apps. They do not provide Apple notarization. See [Updates.md](Updates.md) and [Bundled-media.md](Bundled-media.md) for the actual contracts and codec limits.

## Beamly reference

The owner requested Beamly's workflow as the model. Its merged [feature PR](https://github.com/StPashik/Beamly/pull/7), [release PR](https://github.com/StPashik/Beamly/pull/8), and [merge-back PR](https://github.com/StPashik/Beamly/pull/9) demonstrate the route. Its release guide publishes a normal Latest release and its updater reads the signed feed attached to that release. Yuzu applies that process with its own code, keys, architecture-specific archives, and legacy-client bridges; no Beamly application code or credentials are imported.
