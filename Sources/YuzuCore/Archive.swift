import Foundation
import Darwin

// System libarchive reads ZIP/TAR/GZIP/RAR without shell parsing of filenames.
final class ArchiveReader {
    struct Entry { let path: String; let directory: Bool; let size: Int64 }
    private let api: ArchiveAPI
    private let archive: OpaquePointer
    private static let maximumBytes: Int64 = 512 * 1024 * 1024
    private static let maximumEntries = 10_000

    init(_ url: URL) throws {
        let api = try ArchiveAPI()
        guard let handle = api.create() else { throw ConversionError.failed("Не удалось открыть архивный движок.") }
        _ = api.filters(handle)
        _ = api.formats(handle)
        let status = url.path.withCString { api.open(handle, $0, 65_536) }
        if status < 0 {
            let message = api.message(handle).map { String(cString: $0) } ?? "Нечитаемый архив"
            _ = api.free(handle)
            throw ConversionError.invalid(message)
        }
        self.api = api
        archive = handle
    }
    deinit { _ = api.free(archive) }
    var isTar: Bool { api.format(archive) & 0xFF0000 == 0x30000 } // ARCHIVE_FORMAT_TAR family

    func file(named name: String, maximumBytes: Int = 65_536) throws -> Data? {
        var entry: OpaquePointer?
        while true {
            let status = api.next(archive, &entry)
            if status == 1 { return nil }
            guard status >= 0, let entry, let path = api.path(entry) else { throw failure() }
            guard String(cString: path) == name else { continue }
            let size = api.size(entry)
            guard size >= 0, size <= maximumBytes else { throw ConversionError.invalid("Слишком большой элемент архива: \(name)") }
            var bytes = [UInt8](repeating: 0, count: Int(size))
            var offset = 0
            while offset < bytes.count {
                let count = bytes.withUnsafeMutableBytes { api.read(archive, $0.baseAddress?.advanced(by: offset), $0.count - offset) }
                guard count > 0 else { throw failure() }
                offset += count
            }
            return Data(bytes)
        }
    }

    func entries(extractingTo destination: URL? = nil) throws -> [Entry] {
        var result: [Entry] = []
        var total: Int64 = 0
        var pointer: OpaquePointer?
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let destination = destination?.resolvingSymlinksInPath()
        var names: [String: (spelling: String, directory: Bool, listed: Bool)] = [:]
        while true {
            try Task.checkCancellation()
            let status = api.next(archive, &pointer)
            if status == 1 { break } // ARCHIVE_EOF
            guard status >= 0, let pointer, let name = api.path(pointer) else { throw failure() }
            guard let path = String(validatingUTF8: name) else { throw ConversionError.invalid("Имя в архиве не является UTF-8.") }
            let rawComponents = path.split(separator: "/", omittingEmptySubsequences: true)
            let components = rawComponents.filter { $0 != "." }.map(String.init)
            let type = api.type(pointer) & 0o170000
            let size = api.size(pointer)
            guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\u{0}"),
                  !rawComponents.contains(".."), !path.contains(":"), !path.contains("\n"),
                  api.symlink(pointer) == nil, api.hardlink(pointer) == nil,
                  type == 0o100000 || type == 0o040000,
                  size >= 0, size <= Self.maximumBytes,
                  result.count < Self.maximumEntries, total <= Self.maximumBytes - size else {
                throw ConversionError.invalid("Небезопасный путь, ссылка или слишком большой архив: \(path)")
            }
            let directory = type == 0o040000
            guard !components.isEmpty || directory else { throw ConversionError.invalid("Пустое имя файла в архиве.") }
            // Reserve implicit parents too: "Folder/a" and "folder/b" alias on common Mac volumes.
            for length in 0...components.count where length > 0 || components.isEmpty {
                let spelling = components.prefix(length).joined(separator: "/").precomposedStringWithCanonicalMapping
                let key = spelling.lowercased()
                let isDirectory = length < components.count || directory
                let listed = length == components.count
                if let previous = names[key] {
                    guard previous.spelling == spelling, previous.directory, isDirectory, !listed || !previous.listed else {
                        throw ConversionError.invalid("Повторяющиеся или конфликтующие имена в архиве: \(path)")
                    }
                    names[key] = (spelling, true, previous.listed || listed)
                } else { names[key] = (spelling, isDirectory, listed) }
            }
            total += size
            let entry = Entry(path: path, directory: directory, size: size)
            result.append(entry)
            guard let destination else { continue }
            let output = destination.appendingPathComponent(components.joined(separator: "/")).standardizedFileURL
            guard output.path == destination.path || output.path.hasPrefix(destination.path + "/") else {
                throw ConversionError.invalid("Путь архива выходит за папку распаковки.")
            }
            guard output.resolvingSymlinksInPath().path == output.path else { throw ConversionError.invalid("Ссылка в папке распаковки: \(path)") }
            if entry.directory {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                continue
            }
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            let descriptor = output.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600)) }
            guard descriptor >= 0 else {
                throw ConversionError.invalid("Не удалось безопасно создать \(entry.path): \(String(cString: strerror(errno)))")
            }
            let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? file.close() }
            var written: Int64 = 0
            while true {
                try Task.checkCancellation()
                let count = buffer.withUnsafeMutableBytes { api.read(archive, $0.baseAddress, $0.count) }
                if count == 0 { break }
                guard count > 0, written <= size - Int64(count) else { throw failure() }
                written += Int64(count)
                try file.write(contentsOf: Data(buffer.prefix(count)))
            }
            guard written == size else { throw ConversionError.invalid("Неполный файл в архиве: \(path)") }
        }
        return result
    }

    private func failure() -> ConversionError {
        .invalid(api.message(archive).map { String(cString: $0) } ?? "Повреждённый или неподдерживаемый архив.")
    }
}

private final class ArchiveAPI {
    let library: UnsafeMutableRawPointer
    let create: @convention(c) () -> OpaquePointer?
    let filters: @convention(c) (OpaquePointer) -> Int32
    let formats: @convention(c) (OpaquePointer) -> Int32
    let format: @convention(c) (OpaquePointer) -> Int32
    let open: @convention(c) (OpaquePointer, UnsafePointer<CChar>, Int) -> Int32
    let next: @convention(c) (OpaquePointer, UnsafeMutablePointer<OpaquePointer?>) -> Int32
    let read: @convention(c) (OpaquePointer, UnsafeMutableRawPointer?, Int) -> Int
    let free: @convention(c) (OpaquePointer) -> Int32
    let message: @convention(c) (OpaquePointer) -> UnsafePointer<CChar>?
    let path: @convention(c) (OpaquePointer) -> UnsafePointer<CChar>?
    let symlink: @convention(c) (OpaquePointer) -> UnsafePointer<CChar>?
    let hardlink: @convention(c) (OpaquePointer) -> UnsafePointer<CChar>?
    let type: @convention(c) (OpaquePointer) -> UInt32
    let size: @convention(c) (OpaquePointer) -> Int64

    init() throws {
        guard let library = dlopen("/usr/lib/libarchive.2.dylib", RTLD_NOW | RTLD_LOCAL) else {
            throw ConversionError.unsupported("Системная libarchive недоступна.")
        }
        self.library = library
        func symbol<T>(_ name: String, _ type: T.Type) throws -> T {
            guard let pointer = dlsym(library, name) else { throw ConversionError.unsupported("libarchive: отсутствует \(name)") }
            return unsafeBitCast(pointer, to: type)
        }
        create = try symbol("archive_read_new", (@convention(c) () -> OpaquePointer?).self)
        filters = try symbol("archive_read_support_filter_all", (@convention(c) (OpaquePointer) -> Int32).self)
        formats = try symbol("archive_read_support_format_all", (@convention(c) (OpaquePointer) -> Int32).self)
        format = try symbol("archive_format", (@convention(c) (OpaquePointer) -> Int32).self)
        open = try symbol("archive_read_open_filename", (@convention(c) (OpaquePointer, UnsafePointer<CChar>, Int) -> Int32).self)
        next = try symbol("archive_read_next_header", (@convention(c) (OpaquePointer, UnsafeMutablePointer<OpaquePointer?>) -> Int32).self)
        read = try symbol("archive_read_data", (@convention(c) (OpaquePointer, UnsafeMutableRawPointer?, Int) -> Int).self)
        free = try symbol("archive_read_free", (@convention(c) (OpaquePointer) -> Int32).self)
        message = try symbol("archive_error_string", (@convention(c) (OpaquePointer) -> UnsafePointer<CChar>?).self)
        path = try symbol("archive_entry_pathname", (@convention(c) (OpaquePointer) -> UnsafePointer<CChar>?).self)
        symlink = try symbol("archive_entry_symlink", (@convention(c) (OpaquePointer) -> UnsafePointer<CChar>?).self)
        hardlink = try symbol("archive_entry_hardlink", (@convention(c) (OpaquePointer) -> UnsafePointer<CChar>?).self)
        type = try symbol("archive_entry_filetype", (@convention(c) (OpaquePointer) -> UInt32).self)
        size = try symbol("archive_entry_size", (@convention(c) (OpaquePointer) -> Int64).self)
    }
    deinit { dlclose(library) }
}
