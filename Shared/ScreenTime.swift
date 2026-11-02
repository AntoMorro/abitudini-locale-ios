#if SCREEN_TIME
import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import CryptoKit

enum ScreenPolicy {
    static let prefix = "al."
    static func selection(_ data: Data?) throws -> FamilyActivitySelection {
        guard let data else { throw HabitError.invalid }
        let value = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        guard !value.applicationTokens.isEmpty || !value.categoryTokens.isEmpty || !value.webDomainTokens.isEmpty else { throw HabitError.invalid }
        return value
    }
    static func apply(_ db: HabitDatabase, now: Date = Date()) {
        guard HabitEnvironment.groupURL != nil else { return }
        let defaults = UserDefaults(suiteName: HabitEnvironment.groupID)
        let known = defaults?.stringArray(forKey: "knownRules") ?? []
        let ids = db.rules.map { $0.id.uuidString }
        for old in known where !ids.contains(old) { ManagedSettingsStore(named: .init(prefix + old)).clearAllSettings() }
        for rule in db.rules {
            let store = ManagedSettingsStore(named: .init(prefix + rule.id.uuidString))
            guard HabitEngine.shouldShield(rule, db: db, now: now), let selected = try? selection(rule.activitySelection) else { store.clearAllSettings(); continue }
            store.shield.applications = selected.applicationTokens.isEmpty ? nil : selected.applicationTokens
            store.shield.webDomains = selected.webDomainTokens.isEmpty ? nil : selected.webDomainTokens
            store.shield.applicationCategories = selected.categoryTokens.isEmpty ? nil : .specific(selected.categoryTokens)
            store.shield.webDomainCategories = selected.categoryTokens.isEmpty ? nil : .specific(selected.categoryTokens)
        }
        defaults?.set(ids, forKey: "knownRules")
    }
    static func clear(_ db: HabitDatabase) { for r in db.rules { ManagedSettingsStore(named: .init(prefix + r.id.uuidString)).clearAllSettings() }; DeviceActivityCenter().stopMonitoring() }
    static func configure(_ db: HabitDatabase, now: Date = Date()) throws {
        guard HabitEnvironment.groupURL != nil else { throw HabitError.storage }
        let center = DeviceActivityCenter()
        let defaults = UserDefaults(suiteName: HabitEnvironment.groupID)
        var hashes = defaults?.dictionary(forKey: "monitorHashes") as? [String: String] ?? [:]
        var desired = Set<String>()
        func monitor(_ name: String, schedule: DeviceActivitySchedule, events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:], fingerprint: String) throws {
            desired.insert(name)
            let hash = SHA256.hash(data: Data(fingerprint.utf8)).map { String(format: "%02x", $0) }.joined()
            let activity = DeviceActivityName(name)
            if center.activities.contains(activity), hashes[name] == hash { return }
            try center.startMonitoring(activity, during: schedule, events: events)
            hashes[name] = hash
        }
        for rule in db.rules where rule.enabled {
            _ = try selection(rule.activitySelection)
            let fullDay = rule.startMinute == rule.endMinute || (rule.startMinute == 0 && rule.endMinute == 1440)
            let end = fullDay || rule.endMinute == 1440 ? DateComponents(hour: 23, minute: 59, second: 59) : DateComponents(hour: rule.endMinute / 60, minute: rule.endMinute % 60)
            let start = fullDay ? DateComponents(hour: 0) : DateComponents(hour: rule.startMinute / 60, minute: rule.startMinute % 60)
            let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
            try monitor(prefix + "window." + rule.id.uuidString, schedule: schedule, fingerprint: "\(rule.startMinute)-\(rule.endMinute)-\(TimeZone.current.identifier)")
            if let session = rule.session, HabitEngine.sessionOpen(rule, now: now), session.mode != .day {
                let name = prefix + "unlock." + rule.id.uuidString + "." + session.id.uuidString
                let calendar = Calendar.current
                // DeviceActivity intervals must be at least 15 minutes. A warning callback
                // closes short wall-clock unlocks at their chosen time; the end is a fallback.
                let actualEnd = max(session.ends, session.started.addingTimeInterval(16 * 60))
                let startDate = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: session.started)
                let endDate = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: actualEnd)
                let warning = session.mode == .session && actualEnd > session.ends ? DateComponents(second: Int(actualEnd.timeIntervalSince(session.ends))) : nil
                let oneOff = DeviceActivitySchedule(intervalStart: startDate, intervalEnd: endDate, repeats: false, warningTime: warning)
                var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
                if session.mode == .usage {
                    let selected = try selection(rule.activitySelection)
                    events[.init("spent." + rule.id.uuidString + "." + session.id.uuidString)] = DeviceActivityEvent(applications: selected.applicationTokens, categories: selected.categoryTokens, webDomains: selected.webDomainTokens, threshold: DateComponents(minute: session.minutes), includesPastActivity: false)
                }
                try monitor(name, schedule: oneOff, events: events, fingerprint: session.id.uuidString)
            }
        }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        var fingerprints: [String] = []
        for h in db.habits where h.kind == .appTime && !h.archived {
            let selected = try selection(h.activitySelection)
            events[.init("goal." + h.id.uuidString)] = DeviceActivityEvent(applications: selected.applicationTokens, categories: selected.categoryTokens, webDomains: selected.webDomainTokens, threshold: DateComponents(second: h.goal), includesPastActivity: true)
            fingerprints.append(h.id.uuidString + "-\(h.goal)-" + (h.activitySelection?.base64EncodedString() ?? ""))
        }
        if !events.isEmpty { try monitor(prefix + "goals", schedule: DeviceActivitySchedule(intervalStart: DateComponents(hour: 0), intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true), events: events, fingerprint: fingerprints.sorted().joined()) }
        // A daily callback restores end-of-day unlocks even if the app isn't reopened.
        if db.rules.contains(where: \.enabled) {
            try monitor(prefix + "midnight", schedule: DeviceActivitySchedule(intervalStart: DateComponents(hour: 0), intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true), fingerprint: "daily")
        }
        if let until = db.emergencyUntil, until > now {
            let calendar = Calendar.current
            let start = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: until.addingTimeInterval(-3600))
            let end = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: until)
            try monitor(prefix + "emergency", schedule: DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false), fingerprint: "\(until.timeIntervalSince1970)")
        }
        let obsolete = center.activities.filter { $0.rawValue.hasPrefix(prefix) && !desired.contains($0.rawValue) }
        center.stopMonitoring(obsolete)
        hashes = hashes.filter { desired.contains($0.key) }; defaults?.set(hashes, forKey: "monitorHashes")
    }
}
#endif
