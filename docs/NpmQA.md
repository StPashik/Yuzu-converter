# Independent npm installer review — v0.1.0

Review date: October 27, 2026. This is the historical review of `npm/install.mjs`, `npm/validate-release.mjs`, `npm/cli.mjs`, `scripts/prepare-npm.mjs`, `Tests/npm/installer.test.mjs`, and their package scripts. The reviewer was independent of the installer’s author and changed no code. Expected use: one macOS user installing or updating the app. The installer logic is unchanged in v0.1.1; fresh 13/13 Node tests, final ZIP install checks, and npm prepack passed. See the version-specific [validation record](Validation.md) for subsequent published-download checks.

The installer selects a version-pinned GitHub Release asset, checks SHA-256 before extraction, and installs the app into `~/Applications`. During an update, it moves the old app into private staging only after validating the replacement. If publication fails, it restores the old app or preserves its backup and reports the location.

## Result

No concrete critical validation bypass or path that loses the previously installed app was found in the reviewed scope. This is a conclusion about that npm implementation, not approval of the entire product.

Reviewed boundaries:

- The manifest binds package version, exact arm64/x64 asset names, repository, and both SHA-256 values. `prepack` refuses an unprepared manifest. `prepare-npm` reads both archives and rechecks package version before writing the manifest.
- Downloads use HTTPS and an explicit GitHub host allowlist. Credentials, nonstandard ports, and redirects to other hosts are rejected. Redirect count, timeout, archive size, and streamed checksum computation are bounded.
- Archive paths are checked before `ditto`: one expected app root, no `..`, absolute/control-character paths, or backslashes. `zipinfo` permits regular files/directories only; symlinks and excessive expanded size are rejected.
- Home/Applications and essential app paths use `lstat` checks. Existing symlinks or a foreign bundle ID are not replaced. Validate the new executable, plist, bundle ID, and version before publishing it.
- Commands use `execFile`, argument arrays, and absolute system paths. Downloaded shell scripts are not run. SHA/ZIP/bundle-validation failures occur while the existing app is still in its original location.
- Replacement renames stay on the same volume. A failed rollback preserves its backup. Only the installer’s own staging is removed; user preferences and unrelated apps are untouched.

## Historical automated check

The reviewer independently ran:

```sh
node --test Tests/npm/installer.test.mjs
```

Result: **13 passed, 0 failed, 0 skipped**, using Node v24.19.0. Tests used private temporary homes/staging, did not install into the real `~/Applications`, and did not launch the app.

Coverage included asset selection/manifest, URL allowlist, checksum, unsafe paths, first install, repeated install, upgrade, preservation of the old app after a wrong SHA/corrupt ZIP/foreign bundle, archive symlinks, and destination/Applications symlinks.

## Limits of this conclusion

Tests substituted local ZIPs for HTTPS downloads. They did not prove the correctness of unpublished Release assets, Gatekeeper launch, or app signing. Check the final `.tgz` and both app ZIPs after building; the manifest must pin those exact archives. Later v0.1.0 release checks are recorded separately in [Validation.md](Validation.md).

Forced rename failure after moving the old app, disk failure during rollback, abrupt termination, and concurrent installers were not modeled separately. Recovery branches were inspected statically; missing fault-injection tests are not evidence of data loss. The installer trusts the npm package and its embedded SHA-256 values; this is not a substitute for Developer ID or notarization.

Verdict for the reviewed scope: no critical blocker to the v0.1.0 preview was found. The manager owned overall approval, final build/install smoke checks, and publication. This translated record does not assert a new v0.1.1 review or test run.
