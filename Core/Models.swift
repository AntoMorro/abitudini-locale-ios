import Foundation

enum HabitKind: String, Codable, CaseIterable, Identifiable {
    case check, counter, timer, steps, workout, mindfulness, appTime, shortcut
    var id: String { rawValue }
    var title: String { switch self { case .check: return "Spunta manuale"; case .counter: return "Contatore"; case .timer: return "Timer / Pomodoro"; case .steps: return "Passi"; case .workout: return "Allenamento"; case .mindfulness: return "Meditazione"; case .appTime: return "Tempo in un’app"; case .shortcut: return "Comando rapido" } }
    var timed: Bool { [.timer, .workout, .mindfulness, .appTime].contains(self) }
    var automatic: Bool { [.steps, .workout, .mindfulness, .appTime].contains(self) }
}
struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var symbol = "checkmark"
    var color = "mint"
    var kind: HabitKind = .check
    var goal = 1
    var capOnceDaily = true
    var archived = false
    var backgroundTimer = false
    var activitySelection: Data?
    var created = Date()
}
struct ProgressSample: Identifiable, Codable, Equatable {
    var id = UUID()
    var habitID: UUID
    var day: String
    var key: String
    var amount: Int
    var date: Date
}
struct HabitTimer: Codable, Equatable {
    var id = UUID()
    var habitID: UUID
    var started: Date
    var uptime: Double
    var background: Bool
    var processID = ProcessInfo.processInfo.processIdentifier
}
enum Requirement: String, Codable, CaseIterable, Identifiable {
    case all, any, atLeast
    var id: String { rawValue }
    var title: String { switch self { case .all: return "Tutte"; case .any: return "Una qualsiasi"; case .atLeast: return "Almeno N" } }
}
enum UnlockMode: String, Codable, CaseIterable, Identifiable {
    case day, session, usage
    var id: String { rawValue }
    var title: String { switch self { case .day: return "Fino a fine giornata"; case .session: return "Timer continuo"; case .usage: return "Minuti di utilizzo effettivo" } }
}
struct UnlockSession: Codable, Equatable {
    var id = UUID()
    var day: String
    var mode: UnlockMode
    var started: Date
    var ends: Date
    var minutes: Int
    var exhausted = false
}
struct BlockRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var enabled = false
    var habitIDs: [UUID] = []
    var requirement: Requirement = .all
    var minimum = 1
    var weekdays: Set<Int> = Set(1...7)
    var startMinute = 0
    var endMinute = 1440
    var unlockMode: UnlockMode = .session
    var unlockMinutes = 15
    var activitySelection: Data?
    var commitmentUntil: Date?
    var session: UnlockSession?
}
struct Spend: Codable, Identifiable, Equatable {
    var id = UUID()
    var ruleID: UUID
    var day: String
    var date: Date
}
struct HabitDatabase: Codable {
    var wellness: WellnessArchive?
    var journal: JournalDatabase?
    var plans: [String: HabitPlan]?
    var notes: [String: String]?
    var checkInMinute: Int?
    var version = 1
    var habits: [Habit] = []
    var samples: [ProgressSample] = []
    var rules: [BlockRule] = []
    var spends: [Spend] = []
    var timer: HabitTimer?
    var onboarded = false
    var theme = "dark"
    var healthEnabled = false
    var emergencyUses = 3
    var emergencyUntil: Date?
    func validated() throws -> HabitDatabase {
        guard version == 1, habits.count <= 200, rules.count <= 8, samples.count <= 1_000_000, spends.count <= 1_000_000, (0...3).contains(emergencyUses), ["dark", "light", "system"].contains(theme) else { throw HabitError.invalid }
        guard Set(habits.map(\.id)).count == habits.count, Set(rules.map(\.id)).count == rules.count, Set(samples.map(\.id)).count == samples.count, Set(spends.map(\.id)).count == spends.count else { throw HabitError.invalid }
        let ids = Set(habits.map(\.id)), ruleIDs = Set(rules.map(\.id))
        guard checkInMinute == nil || (0..<1440).contains(checkInMinute!), Tracker.reminderRequestCount(self) <= 60 else { throw HabitError.invalid }
        for (id, p) in plans ?? [:] {
            guard let uuid = UUID(uuidString: id), ids.contains(uuid), [1,1000].contains(p.scale), !p.weekdays.isEmpty, p.weekdays.isSubset(of: Set(1...7)), (1...(p.period == .weekly ? p.weekdays.count : p.period == .monthly ? 31 : 1)).contains(p.target), p.reminders.count <= 3, Set(p.reminders).count == p.reminders.count, p.reminders.allSatisfy({ (0..<1440).contains($0) }), p.description.count <= 2000, p.category.count <= 100, p.unit.count <= 30 else { throw HabitError.invalid }
        }
        guard (notes?.count ?? 0) <= 1_000_000, (notes ?? [:]).allSatisfy({ key, value in key.count == 47 && value.count <= 10_000 && UUID(uuidString: String(key.prefix(36))).map(ids.contains) == true }) else { throw HabitError.invalid }
        for h in habits { guard !h.title.isEmpty, (1...10_000_000).contains(h.goal), (h.activitySelection?.count ?? 0) < 1_000_000 else { throw HabitError.invalid } }
        for r in rules {
            let duration = (r.endMinute - r.startMinute + 1440) % 1440
            guard !r.title.isEmpty, r.habitIDs.allSatisfy(ids.contains), Set(r.habitIDs).count == r.habitIDs.count, (1...max(1,r.habitIDs.count)).contains(r.minimum), !r.weekdays.isEmpty, r.weekdays.isSubset(of: Set(1...7)), (0..<1440).contains(r.startMinute), (0...1440).contains(r.endMinute), duration == 0 || duration >= 15, (1...1440).contains(r.unlockMinutes), (r.activitySelection?.count ?? 0) < 1_000_000, !r.enabled || !r.habitIDs.isEmpty else { throw HabitError.invalid }
            if let s = r.session { guard s.ends >= s.started, (1...1440).contains(s.minutes) else { throw HabitError.invalid } }
        }
        for s in samples { guard ids.contains(s.habitID), (0...1_000_000_000).contains(s.amount), s.day.count == 10, !s.key.isEmpty else { throw HabitError.invalid } }
        guard Set(samples.map { $0.habitID.uuidString + "|" + $0.day + "|" + $0.key }).count == samples.count else { throw HabitError.invalid }
        for s in spends { guard ruleIDs.contains(s.ruleID), s.day.count == 10 else { throw HabitError.invalid } }
        if let t = timer { guard ids.contains(t.habitID), t.uptime.isFinite, t.uptime >= 0 else { throw HabitError.invalid } }
        _ = try wellness?.validated()
        _ = try journal?.validated()
        return self
    }
    mutating func upsert(_ value: ProgressSample) {
        if let i = samples.firstIndex(where: { $0.habitID == value.habitID && $0.day == value.day && $0.key == value.key }) { samples[i].amount = value.amount; samples[i].date = value.date }
        else { samples.append(value) }
    }
}
enum HabitError: LocalizedError {
    case invalid, locked, noCredit, alreadyOpen, storage, missing
    var errorDescription: String? { switch self { case .invalid: return "Dati non validi: verifica obiettivi, fasce orarie e collegamenti."; case .locked: return "L’impegno è ancora attivo: questa modifica è disponibile dopo la scadenza."; case .noCredit: return "Completa prima le abitudini richieste nella fascia prevista."; case .alreadyOpen: return "C’è già uno sblocco attivo per questo blocco."; case .storage: return "Archivio condiviso non disponibile. Verifica i profili di firma e l’App Group."; case .missing: return "Elemento non più disponibile." } }
}
