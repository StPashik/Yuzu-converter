# Virtual image drops

Drag a raster image or screenshot, choose a conversion petal, then use **Save Converted Image** to choose the final path. Ordinary file URL drops retain the existing beside-original behavior. Conversion and seven Actions remain in the wheel; Actions for virtual images are not offered.

The accepted representations are a raster pasteboard item, one image file-promise receiver, or a credential-free HTTP(S) URL whose extension identifies a supported raster image. A promise-content marker lets an unsaved screenshot use Save As even when its item also exposes a temporary local path. No webpage/HTML scraping is performed. Authenticated, blob/data, generic webpage and SVG URLs are unsupported. Availability and representations depend on the source app; physical Chrome/Safari/screenshot workflows remain unverified.

Lazy raster data is snapshotted when the drop is accepted rather than while the pointer first enters the wheel. AppKit promises start reception at acceptance into a private directory and can finish while Save As is open. Cancel removes their temporary contents; late callbacks clean only that private directory. Remote URLs are fetched after Save is accepted, without browser cookies or credential storage. Keep the source app open until preparation completes.

Downloads are bounded to 32 MiB, five HTTP(S) redirects and a 30-second resource timeout. Declared image MIME (or octet stream followed by raster validation) is required. Decode metadata is limited to 64 million total pixels and 256 frames. Promised paths must be regular files inside the private staging directory, without symlinks. Invalid/cancelled imports publish no final file.

The Save panel grants the exact output file. Existing names are rejected, and Core stages through Foundation's item replacement directory before an exclusive rename to that exact path. It never overwrites a file that appears during conversion. Destination grants and temporary input ownership last through the queued request. Physical Save-panel access outside the app container remains an unverified Sandbox gate; own-container signed self-checks are separate evidence.

A single virtual raster can save its original format too. Native ImageIO writers determine the offered formats. PDF/TIFF retain the existing multi-frame export behavior; other raster formats use the first frame. Multi-image local-file PDF batches use one oriented first frame per selected input.

## Platform references and evidence

Apple's [NSFilePromiseReceiver documentation](https://developer.apple.com/documentation/appkit/nsfilepromisereceiver) and the shipped AppKit headers define receiving promises into a caller-selected directory. Chromium's [macOS pasteboard handling](https://raw.githubusercontent.com/chromium/chromium/main/content/browser/web_contents/web_drag_dest_mac.mm) records the dual file/promise representation of unsaved screenshots. These are format/contract references, not evidence of Yuzu interoperability with every browser. No Chromium application code was imported.

`ImageDropTests` uses a private lazy pasteboard, a screenshot-style dual representation, a controlled promise receiver and a loopback HTTP fixture. It checks deferred provider access, cancellation, size/MIME/redirect/stream limits, cleanup and path containment. Physical Finder/Powerbox/browser workflows, VoiceOver, macOS 13 and macOS 26 Intel appearance remain deferred.
