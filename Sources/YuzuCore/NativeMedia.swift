import Foundation
import AVFoundation

/// Dependency-free media fallback: AVAudioFile streams PCM, while AVFoundation exports M4A/MOV/MP4.
/// These routes depend on system decoders and presets; they are not equivalent to the broader FFmpeg routes.
enum NativeMedia {
    /// Probes the actual input and compatible export types. Synchronous asset inspection belongs off the main thread.
    static func supports(_ source: SourceFile, to target: FileFormat) -> Bool {
        if source.format.category == "Audio", target == .wav || target == .aiff {
            guard let input = try? AVAudioFile(forReading: source.url) else { return false }
            return input.processingFormat.channelCount > 0 && input.processingFormat.sampleRate > 0
        }
        // Treating an animated GIF as one native image would silently discard its animation.
        guard source.format != .gif else { return false }
        let asset = AVURLAsset(url: source.url)
        if source.format.category == "Audio", target == .m4a {
            return !asset.tracks(withMediaType: .audio).isEmpty && session(asset, to: target)?.supportedFileTypes.contains(.m4a) == true
        }
        if source.format.category == "Video", target == .mov || target == .mp4 {
            return !asset.tracks(withMediaType: .video).isEmpty && session(asset, to: target)?.supportedFileTypes.contains(target == .mov ? .mov : .mp4) == true
        }
        return false
    }

    /// Writes a caller-owned staging path. PCM exports preserve rate/channels but use 16-bit samples;
    /// M4A/video use system presets. Cancellation stops between PCM chunks or cancels the export session.
    static func convert(_ source: SourceFile, to target: FileFormat, output: URL) async throws {
        try Task.checkCancellation()
        if target == .wav || target == .aiff {
            let input = try AVAudioFile(forReading: source.url)
            let format = input.processingFormat
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: target == .aiff,
                AVLinearPCMIsNonInterleaved: false
            ]
            let destination: AVAudioFile
            do { destination = try AVAudioFile(forWriting: output, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved) }
            catch { throw ConversionError.failed("Creating \(target.label) with AVAudioFile: \(error)") }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_768) else { throw ConversionError.failed("Could not create an audio buffer.") }
            // A fixed-size buffer keeps long recordings independent of available RAM.
            // Stop at the reported length: some decoders throw instead of returning an empty read at EOF.
            while input.framePosition < input.length {
                try Task.checkCancellation()
                let count = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), input.length - input.framePosition))
                do { try input.read(into: buffer, frameCount: count) }
                catch { throw ConversionError.failed("Reading audio for \(target.label) at frame \(input.framePosition): \(error)") }
                guard buffer.frameLength > 0 else { throw ConversionError.failed("The audio engine returned an empty buffer before the end of the file.") }
                do { try destination.write(from: buffer) }
                catch { throw ConversionError.failed("Writing \(target.label) with AVAudioFile: \(error)") }
            }
            return
        }
        let asset = AVURLAsset(url: source.url)
        guard let export = session(asset, to: target), export.supportedFileTypes.contains(target == .m4a ? .m4a : target == .mov ? .mov : .mp4) else {
            throw ConversionError.unsupported("The system media engine does not support this file and container.")
        }
        export.outputURL = output
        export.outputFileType = target == .m4a ? .m4a : target == .mov ? .mov : .mp4
        let operation = NativeExport(export)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.start(continuation)
            }
        } onCancel: { operation.cancel() }
        try Task.checkCancellation()
    }

    private static func session(_ asset: AVAsset, to target: FileFormat) -> AVAssetExportSession? {
        guard asset.isExportable else { return nil }
        return AVAssetExportSession(asset: asset, presetName: target == .m4a ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality)
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
