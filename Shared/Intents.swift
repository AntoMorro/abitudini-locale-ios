import AppIntents
import WidgetKit

extension Notification.Name { static let habitDataChanged = Notification.Name("habitDataChanged") }
struct HabitEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Abitudine"
    static var defaultQuery = HabitQuery()
    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}
struct HabitQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] { try HabitEnvironment.repository.read().habits.filter { identifiers.contains($0.id.uuidString) }.map { HabitEntity(id: $0.id.uuidString, title: $0.title) } }
    func suggestedEntities() async throws -> [HabitEntity] { try HabitEnvironment.repository.read().habits.filter { !$0.archived }.map { HabitEntity(id: $0.id.uuidString, title: $0.title) } }
}
struct MarkHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Aggiungi progresso abitudine"
    @Parameter(title: "Abitudine") var habit: HabitEntity
    @Parameter(title: "Quantità", default: 1) var amount: Int
    init() {}
    init(_ value: Habit) { habit = HabitEntity(id: value.id.uuidString, title: value.title); amount = 1 }
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habit.id) else { throw HabitError.invalid }
        try HabitEnvironment.repository.update { try HabitEngine.add(id, amount: amount, db: &$0, now: Date()) }
        WidgetCenter.shared.reloadAllTimelines(); await MainActor.run { NotificationCenter.default.post(name: .habitDataChanged, object: nil) }; return .result()
    }
}
struct SetHabitProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Imposta progresso giornaliero abitudine"
    static var description = IntentDescription("Aggiorna un’abitudine di tipo Comando rapido con il totale di oggi. Richieste ripetute con lo stesso totale non aggiungono duplicati.")
    @Parameter(title: "Abitudine") var habit: HabitEntity
    @Parameter(title: "Totale di oggi") var total: Int
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habit.id), (0...1_000_000).contains(total) else { throw HabitError.invalid }
        try HabitEnvironment.repository.update { db in guard let h = db.habits.first(where: { $0.id == id }), h.kind == .shortcut, !h.archived else { throw HabitError.invalid }; db.upsert(ProgressSample(habitID: id, day: HabitEngine.day(Date()), key: "shortcut.total", amount: total, date: Date())) }
        WidgetCenter.shared.reloadAllTimelines(); await MainActor.run { NotificationCenter.default.post(name: .habitDataChanged, object: nil) }; return .result()
    }
}
#if !WIDGET_HOST
struct StartHabitTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Avvia timer abitudine"
    static var openAppWhenRun = true
    @Parameter(title: "Abitudine") var habit: HabitEntity
    @MainActor func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habit.id) else { throw HabitError.invalid }
        let db = try HabitEnvironment.repository.update { db in guard let h = db.habits.first(where: { $0.id == id }), h.kind == .timer, !h.archived else { throw HabitError.invalid }; HabitEngine.settleTimer(&db, now: Date()); db.timer = HabitTimer(habitID: id, started: Date(), uptime: ProcessInfo.processInfo.systemUptime, background: h.backgroundTimer) }
        if let h = db.habits.first(where: { $0.id == id }) { LiveTimer.start(habit: h, db: db) }
        NotificationCenter.default.post(name: .habitDataChanged, object: nil); return .result()
    }
}
struct PauseHabitTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Ferma timer abitudine"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { try HabitEnvironment.repository.update { HabitEngine.settleTimer(&$0, now: Date()) }; LiveTimer.end(); NotificationCenter.default.post(name: .habitDataChanged, object: nil); WidgetCenter.shared.reloadAllTimelines(); return .result() }
}
struct HabitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] { AppShortcut(intent: PauseHabitTimerIntent(), phrases: ["Ferma il timer in \(.applicationName)"], shortTitle: "Ferma timer", systemImageName: "pause.circle") }
}
#endif
