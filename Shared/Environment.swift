import Foundation

enum HabitEnvironment {
    static var testing: Bool { ProcessInfo.processInfo.arguments.contains("--ui-testing") }
    static var groupID: String? { Bundle.main.object(forInfoDictionaryKey: "HabitAppGroup") as? String }
    static var groupURL: URL? { guard !testing, let id = groupID else { return nil }; return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) }
    static var repository: HabitRepository {
        let local = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(testing ? "HabitUITests-\(ProcessInfo.processInfo.processIdentifier)" : "AbitudiniLocale", isDirectory: true)
        return HabitRepository(directory: groupURL ?? local)
    }
    static var sharedRepository: HabitRepository? { groupURL.map { HabitRepository(directory: $0) } }
}
