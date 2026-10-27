# Components and notices

Yuzu Converter and its npm installer are distributed under the MIT license; see [LICENSE](LICENSE).

The app icon and vector menu bar icon were reused from the owner’s Yuzu Mac App under an explicit owner request. An app-icon PNG may also be reused only in documentation. No source code or Git history from that project was transferred.

The packaged app uses Apple system frameworks and macOS system libarchive; their copies are not redistributed. System `textutil`, `zip`, and `tar` are invoked from macOS. The operating system supplies the native Swift runtime libraries.

This release does not bundle FFmpeg, LibreOffice, Java, Node, third-party npm packages, or Tangerine resources. Users supply Node.js/npm separately for installation and the launch command. The app itself does not require Node, and the installer has no third-party npm dependencies.

Unsandboxed developer runs can use separately installed FFmpeg/FFprobe/LibreOffice. Their licenses and updates apply to those separate installations. The Sandbox app from Releases does not launch external engines. Bundling any engine later requires a separate license review, applicable notices/source obligations, and correctly signed helper executables.
