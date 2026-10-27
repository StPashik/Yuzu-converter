import Foundation
import AVFoundation

/// Dependency-free media fallback: AVAudioFile encodes audio, while AVFoundation remuxes M4A and exports video.
/// These routes depend on system decoders and presets; they are not equivalent to the broader FFmpeg routes.
enum NativeMedia {
    /// Probes the actual input and compatible export types. Synchronous asset inspection belongs off the main thread.
    static func supports(_ source: SourceFile, to target: FileFormat) -> Bool {
        if source.format.category == "Audio", target == .wav || target == .aiff || target == .m4a {
            guard let input = try? AVAudioFile(forReading: source.url) else { return false }
            return input.processingFormat.channelCount > 0 && input.processingFormat.sampleRate > 0
        }
        // Treating an animated GIF as one native image would silently discard its animation.
        guard source.format != .gif else { return false }
        let asset = AVURLAsset(url: source.url)
        if source.format.category == "Video", target == .mov || target == .mp4 {
            return !asset.tracks(withMediaType: .video).isEmpty && session(asset, to: target)?.supportedFileTypes.contains(target == .mov ? .mov : .mp4) == true
        }
        return false
    }

    /// Writes only caller-owned staging. PCM keeps rate/channels; AAC uses the requested bitrate/quality.
    /// Cancellation stops between bounded audio chunks or cancels the export session.
    static func convert(_ source: SourceFile, to target: FileFormat, output: URL,
                        options: ConversionOptions = .init()) async throws {
        try Task.checkCancellation()
        try options.validate(for: target)
        if target == .wav || target == .aiff {
            try writeAudio(source.url, to: target, output: output, options: options)
            return
        }
        let encoded = output.deletingLastPathComponent().appendingPathComponent(".yuzu-audio-\(UUID().uuidString).m4a")
        defer { if target == .m4a { try? FileManager.default.removeItem(at: encoded) } }
        if target == .m4a { try writeAudio(source.url, to: target, output: encoded, options: options) }
        let original = AVURLAsset(url: source.url)
        let asset: AVAsset
        if target == .m4a { asset = AVURLAsset(url: encoded) }
        else { asset = options.preserveMetadata ? original : try mediaWithoutMetadata(original) }
        guard let export = session(asset, to: target, quality: options.quality), export.supportedFileTypes.contains(target == .m4a ? .m4a : target == .mov ? .mov : .mp4) else {
            throw ConversionError.unsupported("The system media engine does not support this file and container.")
        }
        export.outputURL = output
        export.outputFileType = target == .m4a ? .m4a : target == .mov ? .mov : .mp4
        // Video also uses a fresh composition: some exporters retain source tags despite metadata = [].
        export.metadata = options.preserveMetadata ? original.metadata : []
        if target != .m4a {
            export.audioMix = try audioMix(asset)
            if let height = options.videoMaxHeight { export.videoComposition = try composition(asset, maxHeight: height) }
        }
        let operation = NativeExport(export)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.start(continuation)
            }
        } onCancel: { operation.cancel() }
        try Task.checkCancellation()
    }

    private static func session(_ asset: AVAsset, to target: FileFormat,
                                quality: ConversionQuality = .balanced) -> AVAssetExportSession? {
        guard asset.isExportable else { return nil }
        let preset = quality == .compact ? AVAssetExportPresetLowQuality
            : quality == .balanced ? AVAssetExportPresetMediumQuality : AVAssetExportPresetHighestQuality
        return AVAssetExportSession(asset: asset, presetName: target == .m4a ? AVAssetExportPresetPassthrough : preset)
    }

    static func resolvedDepth(_ depth: AudioSampleDepth, source: URL) throws -> AudioSampleDepth {
        guard depth == .matchSource else { return depth }
        let file = try AVAudioFile(forReading: source)
        let settings = file.fileFormat.settings
        let bits = settings[AVLinearPCMBitDepthKey] as? Int ?? 0
        if settings[AVLinearPCMIsFloatKey] as? Bool == true {
            guard bits == 32 else {
                throw ConversionError.unsupported("Matching \(bits)-bit floating-point audio is not available. Choose an explicit output depth.")
            }
            return .float32
        }
        switch bits {
        case 24: return .bit24
        case 32: return .bit32
        case 0, 16: return .bit16 // Lossy input has no original PCM depth; use the documented 16-bit fallback.
        default: throw ConversionError.unsupported("The source PCM depth cannot be matched. Choose 16, 24, or 32 bits explicitly.")
        }
    }

    private static func writeAudio(_ source: URL, to target: FileFormat, output: URL,
                                   options: ConversionOptions) throws {
        let depth = target == .m4a ? AudioSampleDepth.bit16 : try resolvedDepth(options.audioSampleDepth, source: source)
        // Float32 cannot represent every Int32 sample; keep integer processing for a 32-bit integer output.
        let input = try AVAudioFile(forReading: source, commonFormat: depth == .bit32 ? .pcmFormatInt32 : .pcmFormatFloat32,
                                    interleaved: false)
        let format = input.processingFormat
        var settings: [String: Any] = [AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount]
        if target == .m4a {
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            settings[AVEncoderBitRateKey] = (options.audioBitrate ?? options.quality.audioBitrate) * 1000
            settings[AVEncoderAudioQualityKey] = options.quality == .compact ? AVAudioQuality.low.rawValue
                : options.quality == .balanced ? AVAudioQuality.medium.rawValue : AVAudioQuality.max.rawValue
        } else {
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = depth == .bit16 ? 16 : depth == .bit24 ? 24 : 32
            settings[AVLinearPCMIsFloatKey] = depth == .float32
            settings[AVLinearPCMIsBigEndianKey] = target == .aiff
            settings[AVLinearPCMIsNonInterleaved] = false
        }
        let destination: AVAudioFile
        do { destination = try AVAudioFile(forWriting: output, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved) }
        catch { throw ConversionError.failed("Creating \(target.label) with AVAudioFile: \(error)") }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_768) else { throw ConversionError.failed("Could not create an audio buffer.") }
        // Fixed-size chunks bound memory; stop at reported length because some decoders throw at EOF.
        while input.framePosition < input.length {
            try Task.checkCancellation()
            let count = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), input.length - input.framePosition))
            do { try input.read(into: buffer, frameCount: count) }
            catch { throw ConversionError.failed("Reading audio for \(target.label) at frame \(input.framePosition): \(error)") }
            guard buffer.frameLength > 0 else { throw ConversionError.failed("The audio engine returned an empty buffer before the end of the file.") }
            do { try destination.write(from: buffer) }
            catch { throw ConversionError.failed("Writing \(target.label) with AVAudioFile: \(error)") }
        }
    }

    static func mediaWithoutMetadata(_ asset: AVAsset) throws -> AVComposition {
        let result = AVMutableComposition()
        let tracks = asset.tracks
        let chapterTracks = Set(tracks.flatMap { $0.associatedTracks(ofType: .chapterList) }.map(\.trackID))
        for source in tracks where source.mediaType != .metadata && source.mediaType != .timecode && !chapterTracks.contains(source.trackID) {
            try Task.checkCancellation()
            guard let track = result.addMutableTrack(withMediaType: source.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw ConversionError.unsupported("The system cannot rebuild this media track without its metadata.")
            }
            // Inserting media ranges preserves samples and timing without copying source container tags or chapters.
            try track.insertTimeRange(source.timeRange, of: source, at: source.timeRange.start)
            // New composition tracks default to enabled; preserve intentionally hidden or disabled content.
            track.isEnabled = source.isEnabled
            track.preferredTransform = source.preferredTransform
            track.preferredVolume = source.preferredVolume
        }
        guard !result.tracks.isEmpty else { throw ConversionError.invalid("The asset has no exportable media tracks.") }
        return result
    }

    private static func audioMix(_ asset: AVAsset) throws -> AVAudioMix? {
        let tracks = asset.tracks(withMediaType: .audio)
        guard !tracks.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = try tracks.map { track in
            let volume = track.preferredVolume
            guard volume.isFinite, (0...1).contains(volume) else {
                throw ConversionError.unsupported("The source audio playback volume cannot be preserved safely; it must be between 0 and 1.")
            }
            // Exporters can ignore preferredVolume; apply the actual gain using this export asset's track IDs.
            let parameters = AVMutableAudioMixInputParameters(track: track)
            parameters.setVolume(track.isEnabled ? volume : 0, at: .zero)
            return parameters
        }
        return mix
    }

    private static func composition(_ asset: AVAsset, maxHeight: Int) throws -> AVVideoComposition {
        let tracks = asset.tracks(withMediaType: .video)
        guard tracks.count == 1, let track = tracks.first else { throw ConversionError.unsupported("Resizing requires one video track; the original is unchanged.") }
        let bounds = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform).standardized
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
            throw ConversionError.invalid("The video dimensions are invalid.")
        }
        let scale = min(CGFloat(1), CGFloat(maxHeight) / bounds.height)
        let size = CGSize(width: max(2, floor(bounds.width * scale / 2) * 2),
                          height: max(2, floor(bounds.height * scale / 2) * 2))
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        // Normalize portrait rotation before scaling; do not enlarge a source smaller than the requested cap.
        let transform = track.preferredTransform.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .concatenating(CGAffineTransform(scaleX: size.width / bounds.width, y: size.height / bounds.height))
        layer.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        let duration = asset.duration
        guard duration.isNumeric, duration.seconds > 0 else { throw ConversionError.invalid("The video duration is invalid.") }
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layer]
        let composition = AVMutableVideoComposition()
        composition.instructions = [instruction]
        composition.renderSize = size
        let frameRate = track.nominalFrameRate
        let minimum = track.minFrameDuration
        composition.frameDuration = minimum.isNumeric && minimum.seconds > 0 ? minimum
            : CMTime(seconds: frameRate.isFinite && frameRate > 0 ? 1 / Double(frameRate) : 1 / 30,
                     preferredTimescale: 60_000)
        return composition
    }
}

/// Serializes start/cancel so cancellation arriving before continuation registration is not lost.
/// AVFoundation's completion handler resumes the continuation; the lock protects only lifecycle coordination.
private final class NativeExport: @unchecked Sendable {
    private let lock = NSLock()
    private let session: AVAssetExportSession
    private var cancelled = false
    init(_ session: AVAssetExportSession) { self.session = session }
    func start(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { continuation.resume(throwing: CancellationError()); return }
        session.exportAsynchronously { [self] in
            if session.status == .completed { continuation.resume() }
            else if session.status == .cancelled { continuation.resume(throwing: CancellationError()) }
            else { continuation.resume(throwing: session.error ?? ConversionError.failed("The system media engine did not complete the export.")) }
        }
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        session.cancelExport()
    }
}
