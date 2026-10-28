# Intel video export recovery

## Observed failure

The signed Intel app failed in the private-container Sandbox check while converting a 192×144 MPEG-4 MOV to MP4 with High quality, metadata removal, and a 72-pixel height cap. AVFoundation reported `AVFoundationErrorDomain / -11800`, with underlying `NSOSStatusErrorDomain / -12902`. The SDK names that underlying status [`kVTParameterErr`](https://developer.apple.com/documentation/videotoolbox/kvtparametererr).

[The original diagnostic run](https://github.com/StPashik/Yuzu-converter/actions/runs/40560456130) identified the exact stage and error. Earlier native Intel unit tests passed, and Rosetta tests on Apple Silicon did not reproduce this signed-app failure. A supported container in AVFoundation's preflight was therefore insufficient evidence that the requested profile would finish exporting.

## Recovery policy

`ConversionEngine` still tries the native route first. It retries MP4/MOV through the bundled FFmpeg only for that precise AVFoundation/VideoToolbox error combination, when the required software encoders are available and the existing playback-state check permits the source.

Cancellation and unrelated errors propagate normally. Disabled tracks and non-unit audio gain prevent retry, so software conversion cannot expose hidden video or muted/reduced-gain audio. Only a private partial output is removed; the source and existing destination files are preserved. FFmpeg uses the existing quality/metadata/height settings and documented first-video/first-audio stream limits. This is a software encode rather than a promise of lossless remuxing or identical native codec selection.

## Verified evidence

[Feature PR #5](https://github.com/StPashik/Yuzu-converter/pull/5) passed [native CI](https://github.com/StPashik/Yuzu-converter/actions/runs/40674356437) on macOS 15 Intel and macOS 26 Apple Silicon: 66 Swift tests per CPU, no test failures, and both signed Sandbox archives passed. The formerly failing MOV → MP4 profile, decoded frames, dimensions, original bytes, and return conversion were checked. The Sandbox checks also reached image metadata, documents, spreadsheets, archives, and ZIP creation.

The two added regressions check the exact error classification and actual small MPEG-4 → MP4 → MOV profile output. Existing disabled-track, audio-gain, cancellation, damaged-input, and preservation tests remain in the suite. Release validation additionally checks the restored CPU-specific npm package and signed feeds before publication.

## Inferences and unknowns

The native export path rejected its runtime parameters on that Intel environment; the internal Apple implementation reason was not established. No claim is made that every Intel encoder or every macOS version behaves identically. The fix uses the already bundled software engine without loosening Sandbox entitlements.

macOS 26 Intel UI-test preparation previously stalled in hosted CI. Current native Intel CI uses macOS 15; physical Finder/Powerbox, VoiceOver, macOS 13, and a full interactive Intel updater installation remain separate unverified gates. Builds remain ad-hoc signed without Apple notarization.
