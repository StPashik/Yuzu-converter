import XCTest
@testable import YuzuCore

final class FileMoveTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    func testRelocationUsesComponentsAndDoesNotFollowFileOrSymlinkDescendants() throws {
        let source = root.appendingPathComponent("Folder"), destination = root.appendingPathComponent("Renamed")
        let move = FileMove(source: source, destination: destination, includesDescendants: true)
        XCTAssertEqual(move.relocating(source), destination)
        XCTAssertEqual(move.relocating(source.appendingPathComponent("Nested/100% café.txt")), destination.appendingPathComponent("Nested/100% café.txt"))
        XCTAssertNil(move.relocating(root.appendingPathComponent("Folder sibling/file.txt")))
        XCTAssertNil(move.relocating(try XCTUnwrap(URL(string: "https://example.com/Folder/file.txt"))))
        XCTAssertNil(FileMove(source: source, destination: destination, includesDescendants: false)
            .relocating(source.appendingPathComponent("child.txt")))
    }

    func testOnlyCompletedMovesEmitMappingsIncludingNormalizedChildrenAndCollisions() throws {
        let folder = root.appendingPathComponent("Folder"), target = root.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: target.appendingPathComponent("Folder"), withIntermediateDirectories: true)
        let child = folder.appendingPathComponent("child.txt")
        try Data("Original child".utf8).write(to: child)
        var moves: [FileMove] = []
        _ = try FileOperations.copy([folder, child], to: root, move: true, onMove: { moves.append($0) })
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves[0].source.path, moves[0].destination.path)
        XCTAssertEqual(moves[0].relocating(child)?.path, child.path)
        moves = []
        let results = try FileOperations.copy([child, folder], to: target, move: true, onMove: { moves.append($0) })
        XCTAssertEqual(results.map(\.lastPathComponent), ["Folder_yuzu"])
        XCTAssertEqual(moves.count, 1)
        XCTAssertTrue(moves[0].includesDescendants)
        let relocated = try XCTUnwrap(moves[0].relocating(child))
        XCTAssertEqual(try String(contentsOf: relocated), "Original child")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        moves = []
        _ = try FileOperations.copy([relocated], to: root, move: false, onMove: { moves.append($0) })
        XCTAssertTrue(moves.isEmpty)
        XCTAssertEqual(try String(contentsOf: relocated), "Original child")
    }

    func testMovingDirectorySymlinkDoesNotRelocateItsTargetChildren() throws {
        let original = root.appendingPathComponent("Original"), link = root.appendingPathComponent("Link")
        let target = root.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let child = original.appendingPathComponent("child.txt")
        try Data("Keep target".utf8).write(to: child)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        var moves: [FileMove] = []
        let outputs = try FileOperations.copy([link], to: target, move: true, onMove: { moves.append($0) })
        XCTAssertEqual(moves.count, 1)
        XCTAssertFalse(moves[0].includesDescendants)
        XCTAssertNil(moves[0].relocating(link.appendingPathComponent("child.txt")))
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: outputs[0].path), original.path)
        XCTAssertEqual(try String(contentsOf: child), "Keep target")
    }
}
