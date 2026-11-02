import Foundation
import Darwin

final class HabitRepository {
    let directory: URL
    var file: URL { directory.appendingPathComponent("abitudini.json") }
    init(directory: URL) { self.directory = directory }
    func withLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("archive.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw HabitError.storage }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw HabitError.storage }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
    private func readUnlocked() throws -> HabitDatabase {
        guard FileManager.default.fileExists(atPath: file.path) else { return HabitDatabase() }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 100_000_000 else { throw HabitError.invalid }
        return try JSONDecoder().decode(HabitDatabase.self, from: Data(contentsOf: file)).validated()
    }
    func read() throws -> HabitDatabase { try withLock { try readUnlocked() } }
    @discardableResult func update(_ body: (inout HabitDatabase) throws -> Void) throws -> HabitDatabase {
        try withLock {
            var candidate = try readUnlocked(); try body(&candidate); _ = try candidate.validated()
            let data = try JSONEncoder().encode(candidate)
            if FileManager.default.fileExists(atPath: file.path) { try Data(contentsOf: file).write(to: directory.appendingPathComponent("abitudini.previous.json"), options: .atomic) }
            try data.write(to: file, options: .atomic); return candidate
        }
    }
    func restore(_ data: Data) throws -> HabitDatabase {
        let candidate = try JSONDecoder().decode(HabitDatabase.self, from: data).validated()
        return try withLock { if FileManager.default.fileExists(atPath: file.path) { try Data(contentsOf: file).write(to: directory.appendingPathComponent("abitudini.previous.json"), options: .atomic) }; try JSONEncoder().encode(candidate).write(to: file, options: .atomic); return candidate }
    }
}
