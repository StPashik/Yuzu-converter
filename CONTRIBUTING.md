# Contributing

Use `feature/<description>` from `develop` and open a pull request back to `develop`. Wait for CI and merge with a merge commit. Prepare releases on `release/<version>` and submit a release PR to `main`; tag that exact merge commit. Merge the release branch back through a PR to `develop`. Published-release fixes use `hotfix/<description>` from `main` and return through PRs to both branches.

Do not commit or push directly to `main` or `develop`, force-push shared branches, or move published tags. Read [AGENTS.md](AGENTS.md), the [developer guide](docs/Developer-guide.md), and [release instructions](docs/Releasing.md).

Keep documentation, comments, diagnostics, commit messages, and release notes in English. The app's five localization tables intentionally contain translated values. Explain consequential code choices and add a focused regression check for behavior changes. Preserve original files, cancellation, staging, signature checks, and the owner's preferences.

[CI](.github/workflows/ci.yml) checks GitFlow routes and signed appcasts. Native changes also run Swift/installer tests and build a signed Sandbox app on separate Apple Silicon and Intel runners. Documentation/feed-only PRs use the metadata checks; changes to bundled license copies still require native builds. CI is read-only, has no release signing key, and does not publish or install releases for the owner.

Use generated fixtures and isolated scratch/installation directories. Do not include personal media, grants, private research output, signing credentials, or build products. The owner controls installed updates through **Check for Updates…**. Publishing a release does not authorize installing it, quitting, or relaunching the owner's app.
