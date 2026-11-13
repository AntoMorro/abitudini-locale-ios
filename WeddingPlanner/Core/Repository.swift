import Foundation
import Darwin

/// Same locked, validated, atomic JSON strategy as Quaderno Locale; isolated archive.
final class WeddingRepository {
    let directory: URL
    var file: URL { directory.appendingPathComponent("promessa.json") }
    init(directory: URL) { self.directory = directory }
    private func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("archive.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw WeddingError.invalid("Archivio non accessibile.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw WeddingError.invalid("Archivio occupato.") }
        defer { flock(descriptor, LOCK_UN) }; return try body()
    }
    private func protectedWrite(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
    static func decode(_ data: Data) throws -> WeddingArchive {
        guard data.count < 20_000_000 else { throw WeddingError.invalid("Backup troppo grande (limite 20 MB).") }
        return try JSONDecoder().decode(WeddingArchive.self, from: data).validated()
    }
    private func readUnlocked() throws -> WeddingArchive {
        guard FileManager.default.fileExists(atPath: file.path) else { return WeddingArchive() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 20_000_000 else { throw WeddingError.invalid("Archivio troppo grande.") }
        return try Self.decode(Data(contentsOf: file))
    }
    func read() throws -> WeddingArchive { try locked { try readUnlocked() } }
    private func saveUnlocked(_ archive: WeddingArchive) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive.validated())
        guard data.count < 20_000_000 else { throw WeddingError.invalid("Archivio troppo grande.") }
        if FileManager.default.fileExists(atPath: file.path) { try protectedWrite(Data(contentsOf: file), to: directory.appendingPathComponent("promessa.previous.json")) }
        try protectedWrite(data, to: file)
    }
    @discardableResult func update(_ body: (inout WeddingArchive) throws -> Void) throws -> WeddingArchive {
        try locked { var archive = try readUnlocked(); try body(&archive); try saveUnlocked(archive); return archive }
    }
    func restore(_ data: Data) throws -> WeddingArchive {
        let archive = try Self.decode(data)
        return try locked { try saveUnlocked(archive); return archive }
    }
    func erase(preservePersonalBackup:Bool = false) throws -> WeddingArchive {
        try locked {
            let empty = WeddingArchive()
            try saveUnlocked(empty)
            let previous = directory.appendingPathComponent("promessa.previous.json")
            if FileManager.default.fileExists(atPath:previous.path) { try FileManager.default.removeItem(at:previous) }
            let preShare = directory.appendingPathComponent("prima-condivisione.json")
            if !preservePersonalBackup && FileManager.default.fileExists(atPath:preShare.path) {try FileManager.default.removeItem(at:preShare)}
            return empty
        }
    }
}
