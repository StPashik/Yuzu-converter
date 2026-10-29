import Foundation

/// Explicit stream mapping prevents FFmpeg's default selection from silently keeping only one audio track.
struct MediaTracks {
    struct Stream: Decodable {
        let index: Int
        let codec_type: String
        let codec_name: String?
        var disposition: [String: Int]?
    }
    private struct Probe: Decodable {
        let streams: [Stream]
        let chapters: [Chapter]?
    }
    private struct Chapter: Decodable {}
    let streams: [Stream]
    let chapterCount: Int
    var needsExplicitMapping: Bool {
        streams.filter { $0.codec_type == "audio" }.count > 1 || chapterCount > 0
            || streams.contains { $0.codec_type == "subtitle" || $0.codec_type == "attachment" }
            || streams.filter { $0.codec_type == "video" }.count > 1
    }

    init(url: URL, probe: URL) throws {
        let json = try ProcessRunner.checked(probe, ["-v", "error", "-protocol_whitelist", "fd",
            "-show_entries", "stream=index,codec_type,codec_name:stream_disposition:chapter=id", "-of", "json", "fd:"], input: url, timeout: 30)
        let result = try JSONDecoder().decode(Probe.self, from: Data(json.utf8))
        guard result.streams.count <= 128, result.streams.contains(where: { $0.codec_type == "video" }) else {
            throw ConversionError.unsupported("The video has no readable video track or exceeds 128 streams.")
        }
        streams = result.streams; chapterCount = result.chapters?.count ?? 0
    }

    struct Plan {
        let arguments: [String]
        let warnings: [String]
        let audioCount: Int
        let subtitleTracks: [Stream]
        var subtitles: Int { subtitleTracks.count }
        let chapters: Int
    }

    func plan(target: FileFormat, preserveMetadata: Bool) -> Plan {
        var args = ["-map", "0:v:0", "-map", "0:a?", "-dn"]
        var warnings: [String] = []
        let subtitles = streams.filter { $0.codec_type == "subtitle" }
        let textCodecs: Set<String> = ["subrip", "ass", "ssa", "webvtt", "mov_text", "text", "microdvd", "mpl2", "jacosub", "pjs", "realtext", "sami", "subviewer", "subviewer1", "vplayer"]
        let matroskaCodecs: Set<String> = ["subrip", "ass", "ssa", "webvtt", "hdmv_pgs_subtitle", "dvd_subtitle", "dvb_subtitle"]
        let selected = subtitles.filter {
            (target == .mkv && (matroskaCodecs.contains($0.codec_name ?? "") || textCodecs.contains($0.codec_name ?? "")))
                || ([.mp4, .mov, .webm].contains(target) && textCodecs.contains($0.codec_name ?? ""))
        }
        for (index, track) in selected.enumerated() {
            let codec = target == .mkv ? (matroskaCodecs.contains(track.codec_name ?? "") ? "copy" : "srt") : target == .webm ? "webvtt" : "mov_text"
            args += ["-map", "0:\(track.index)", "-c:s:\(index)", codec]
        }
        if subtitles.count != selected.count {
            warnings.append("\(subtitles.count - selected.count) subtitle track(s) cannot be stored in \(target.label) and were omitted. Use MKV to retain embedded subtitle codecs.")
        }
        if selected.contains(where: { ["ass", "ssa"].contains($0.codec_name ?? "") }), target != .mkv {
            warnings.append("Styled subtitles were converted to plain timed text; fonts, positioning, and effects may change. Use MKV to retain ASS/SSA styling.")
        }
        if streams.contains(where: { $0.codec_type == "attachment" }) {
            warnings.append("Embedded attachments, including subtitle fonts, were omitted. They remain in the original file.")
        }
        if streams.filter({ $0.codec_type == "video" }).count > 1 {
            warnings.append("Only the first video track was converted. Additional video tracks remain in the original file.")
        }
        if preserveMetadata, target == .avi, streams.filter({ $0.codec_type == "audio" }).count > 1 {
            warnings.append("AVI may not retain per-track language labels. Audio tracks remain separate; use MP4, MOV, or MKV for language selection.")
        }
        let chapters = preserveMetadata && [.mp4, .mov, .mkv, .webm].contains(target) ? chapterCount : 0
        if preserveMetadata, chapterCount > chapters {
            warnings.append("\(target.label) cannot retain the source chapters; they were omitted. Use MP4, MOV, or MKV.")
        }
        args += ["-map_chapters", chapters > 0 ? "0" : "-1"]
        // Copy dispositions explicitly: automatic mapping may otherwise mark the first audio stream as default.
        for kind in ["audio", "subtitle"] {
            let mapped = kind == "audio" ? streams.filter { $0.codec_type == kind } : selected
            for (index, track) in mapped.enumerated() {
                let flags = (track.disposition ?? [:]).filter { $0.value == 1 }.map(\.key).sorted()
                args += ["-disposition:\(kind == "audio" ? "a" : "s"):\(index)", flags.isEmpty ? "0" : flags.joined(separator: "+")]
            }
        }
        return Plan(arguments: args, warnings: warnings, audioCount: streams.filter { $0.codec_type == "audio" }.count,
                    subtitleTracks: selected, chapters: chapters)
    }

    func validate(_ output: URL, probe: URL, plan: Plan) throws -> [String] {
        let result = try MediaTracks(url: output, probe: probe)
        guard result.streams.filter({ $0.codec_type == "audio" }).count == plan.audioCount,
              result.streams.filter({ $0.codec_type == "subtitle" }).count == plan.subtitles,
              result.chapterCount == plan.chapters else {
            throw ConversionError.failed("The converted video did not retain the expected audio tracks, subtitles, or chapters. No result was published.")
        }
        var warnings: [String] = []
        for kind in ["audio", "subtitle"] {
            let expected = kind == "audio" ? streams.filter { $0.codec_type == kind } : plan.subtitleTracks
            let actual = result.streams.filter { $0.codec_type == kind }
            for (index, pair) in zip(expected, actual).enumerated() {
                var flags = Set((pair.0.disposition ?? [:]).filter { $0.value == 1 }.map(\.key))
                var kept = Set((pair.1.disposition ?? [:]).filter { $0.value == 1 }.map(\.key))
                // A sole audio track needs no default flag to select it; do not retain a misleading warning.
                if kind == "audio", expected.count == 1 { flags.remove("default"); kept.remove("default") }
                if flags != kept {
                    warnings.append("The output container changed playback flags for \(kind) track \(index + 1) (source: \(flags.sorted().joined(separator: ", ")); output: \(kept.sorted().joined(separator: ", "))). Check the default/forced track selection in your player.")
                }
            }
        }
        return warnings
    }
}
