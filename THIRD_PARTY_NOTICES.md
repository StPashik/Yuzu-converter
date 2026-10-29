# Components and notices

Yuzu Converter and its npm installer are distributed under the MIT license; see [LICENSE](LICENSE).

The app icon and vector menu bar icon were reused from the owner’s Yuzu Mac App under an explicit owner request. An app-icon PNG may also be reused only in documentation. No source code or Git history from that project was transferred.

The owner also authorized using Yuzu Mac App's wheel appearance as a read-only visual reference. The current AppKit renderer applies its geometry, colors, typography, and SF Symbol choices; no old engines, settings, caches, or additional assets are bundled. The wheel preview PNGs in documentation are renders of this application's control.

The packaged app uses Apple system frameworks and macOS system libarchive; their copies are not redistributed. System `textutil`, `zip`, and `tar` are invoked from macOS. The operating system supplies the native Swift runtime libraries.

Tangerine's Settings window was observed through REA as a design and feature reference. Yuzu recreates the relevant layout and parameters with its own code. No Tangerine artwork, sounds, resources, source, pseudocode, binaries, grants, account data, or preferences are included. Feedback uses macOS's system Tink sound and alignment haptics.

The app bundles [Sparkle 2.10.1](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1) for user-initiated, signed software updates. Its framework, installer services, and bundled third-party components retain their notices in [Sparkle-LICENSE.txt](docs/licenses/Sparkle-LICENSE.txt); this license is also copied into the app's Resources folder. Sparkle's license does not change the license of Yuzu's own code.

The app bundles FFmpeg and FFprobe 9.0.2, built from unmodified upstream source with GPL, version-3-only, and nonfree components disabled. This software uses code from [FFmpeg](https://ffmpeg.org/) under LGPL 2.1 or later. The separate helper executables statically include libvpx 1.17.0 (BSD and patent grant), Opus 1.6.1 (BSD and patent notices), and LAME 3.100 (LGPL 2 or later). Yuzu does not link FFmpeg libraries into its own executable. Their licenses do not replace the MIT license of Yuzu's own code or installer.

[Complete corresponding source and build instructions](https://github.com/StPashik/Yuzu-converter/releases/download/v0.6.2/Yuzu-FFmpeg-Sources-0.6.2.tar.xz) are hosted with this release, including exact archives, checksums, configuration records, and the build recipe. No upstream source patches are applied. See [Bundled-media.md](docs/Bundled-media.md), the seven media license/notice files in [docs/licenses](docs/licenses), and the same copies inside the app's `Contents/Resources/Media-Licenses`. LGPL component modification, rebuilding, relinking, and reverse engineering for debugging those modifications are permitted under their licenses. Modified signed app contents must be signed again for macOS to load them.

This release does not bundle LibreOffice, Java, Node, third-party npm packages, or Tangerine resources. Users supply Node.js/npm separately for installation and the launch command. The native app does not require Node, and the installer has no third-party npm dependencies. Unsandboxed developer runs may use separately installed engines; their licenses and updates apply to those separate installations. Packaged apps accept only their own signed media helpers and do not launch an external LibreOffice.
