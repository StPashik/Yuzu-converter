import AppKit
import XCTest
import YuzuCore
@testable import YuzuApp

private actor WindowGate {
    private var resume: CheckedContinuation<Void, Never>?
    func wait() async { await withCheckedContinuation { resume = $0 } }
    var isWaiting: Bool { resume != nil }
    func release() { resume?.resume(); resume = nil }
}

final class QueueWindowTests: XCTestCase {
    @MainActor
    private func render(_ controller: QueueWindowController, name: String) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output = root.appendingPathComponent(".build/queue-preview")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let surface = try XCTUnwrap(controller.window?.contentView)
        surface.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        surface.layoutSubtreeIfNeeded()
        controller.window?.displayIfNeeded()
        let hosting = try XCTUnwrap(surface.subviews.first { String(describing: type(of: $0)).contains("NSHostingView") })
        XCTAssertGreaterThan(hosting.frame.width, 530)
        XCTAssertEqual(hosting.frame.height, surface.bounds.height, accuracy: 4)
        let bitmap = try XCTUnwrap(surface.bitmapImageRepForCachingDisplay(in: surface.bounds))
        surface.cacheDisplay(in: surface.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(data.count, 4500, "The queue must render its controls and content")
        try data.write(to: output.appendingPathComponent(name + ".png"))
    }

    @MainActor
    func testWindowClosingAndMaterialChangesPreserveJobsAndRenderFiveLanguages() async throws {
        _ = NSApplication.shared
        let previousLanguage = L10n.language
        defer { L10n.language = previousLanguage }
        L10n.language = .english
        let gate = WindowGate()
        let queue = JobQueue { request, progress in
            let name = request.files.urls[0].lastPathComponent
            if name == "Damaged video.mov" {
                await progress(QueueProgress(completed: 1, published: [URL(fileURLWithPath: "/tmp/Completed.mp4")]))
                throw NSError(domain: "QueueFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "The second file could not be read. The completed result is preserved."])
            }
            if name == "Mountain light.mov" { await gate.wait(); try Task.checkCancellation() }
            return [URL(fileURLWithPath: "/tmp/Result.zip")]
        }
        let controller = QueueWindowController(queue: queue)
        defer { controller.close() }
        controller.setMaterial(reduceTransparency: true)
        try render(controller, name: "en-empty-light")
        func add(_ names: [String]) {
            let kind: JobKind = names[0] == "Project files" ? .compress : .conversion(names[0].hasSuffix(".pdf") ? .png : .mp4)
            queue.enqueue(JobRequest(files: ScopedFiles(names.map { URL(fileURLWithPath: "/tmp/" + $0) }),
                                     kind: kind, destinations: []))
        }
        add(["Project files"])
        await queue.waitForCurrentJob()
        add(["Damaged video.mov", "Completed clip.mov"])
        await queue.waitForCurrentJob()
        add(["Mountain light.mov"])
        while !(await gate.isWaiting) { try await Task.sleep(nanoseconds: 10_000_000) }
        add(["Presentation — 100% café.pdf"])
        let expected = queue.entries.map(\.state)
        XCTAssertEqual(expected, [.completed, .failed, .running, .waiting])
        controller.close()
        XCTAssertEqual(queue.entries.map(\.state), expected)
        controller.present()
        XCTAssertTrue(try XCTUnwrap(controller.window).isVisible)
        controller.setMaterial(reduceTransparency: false)
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { XCTAssertTrue(controller.window?.contentView is NSGlassEffectView) }
        else { XCTAssertTrue(controller.window?.contentView is NSVisualEffectView) }
        #else
        XCTAssertTrue(controller.window?.contentView is NSVisualEffectView)
        #endif
        XCTAssertEqual(queue.entries.map(\.state), expected)
        // WindowServer owns the glass composition; offscreen snapshots exercise the opaque accessibility fallback.
        controller.setMaterial(reduceTransparency: true)
        XCTAssertTrue(controller.window?.contentView is NSBox)
        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            controller.window?.appearance = NSAppearance(named: appearance)
            for language in AppLanguage.allCases {
                L10n.language = language
                controller.refreshLanguage()
                try render(controller, name: "\(language.rawValue)-jobs-\(theme)")
            }
        }
        queue.cancelAll()
        await gate.release()
        await queue.waitForCurrentJob()
        XCTAssertTrue(queue.isIdle)
        XCTAssertEqual(queue.entries.map(\.state), [.completed, .failed, .cancelled, .cancelled])
    }
}
