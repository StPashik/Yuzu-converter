# Components and notices

Yuzu Converter and its npm installer are distributed under the MIT license; see [LICENSE](LICENSE).

The app icon and vector menu bar icon were reused from the owner’s Yuzu Mac App under an explicit owner request. An app-icon PNG may also be reused only in documentation. No source code or Git history from that project was transferred.

The owner also authorized using Yuzu Mac App's wheel appearance as a read-only visual reference. The current AppKit renderer applies its geometry, colors, typography, and SF Symbol choices; no old engines, settings, caches, or additional assets are bundled. The wheel preview PNGs in documentation are renders of this application's control.

The packaged app uses Apple system frameworks and macOS system libarchive; their copies are not redistributed. System `textutil`, `zip`, and `tar` are invoked from macOS. The operating system supplies the native Swift runtime libraries.

The app bundles [Sparkle 2.10.1](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1) for user-initiated, signed software updates. Its framework, installer services, and bundled third-party components retain their notices in [Sparkle-LICENSE.txt](docs/licenses/Sparkle-LICENSE.txt); this license is also copied into the app's Resources folder. Sparkle's license does not change the license of Yuzu's own code.

This release does not bundle FFmpeg, LibreOffice, Java, Node, third-party npm packages, or Tangerine resources. Users supply Node.js/npm separately for installation and the launch command. The app itself does not require Node, and the installer has no third-party npm dependencies.

Unsandboxed developer runs can use separately installed FFmpeg/FFprobe/LibreOffice. Their licenses and updates apply to those separate installations. The Sandbox app from Releases does not launch external engines. Bundling any engine later requires a separate license review, applicable notices/source obligations, and correctly signed helper executables.
