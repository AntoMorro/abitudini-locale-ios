import SwiftUI
import WidgetKit
import UniformTypeIdentifiers
#if SCREEN_TIME
import FamilyControls
#endif

@MainActor final class HabitStore: ObservableObject {
    @Published private(set) var db = HabitDatabase()
    @Published var problem: String?
    @Published var protectionStatus = ""
    @Published private(set) var protectionReady = false
    @Published var routeHabit: Habit?
    @Published var reminderStatus = ""
    private var reminderTask: Task<Void, Never>?
    private(set) var readOnly = false
    let repository = HabitEnvironment.repository
    #if HEALTH
    let health = HabitHealth()
    #endif
    var shared: Bool { HabitEnvironment.groupURL != nil }
    init() { refresh(); if let timer = db.timer, !timer.background, timer.processID != ProcessInfo.processInfo.processIdentifier { change { $0.timer = nil } } }
    func refresh() {
        do { db = try repository.read(); readOnly = false }
        catch { readOnly = true; problem = "Archivio non leggibile. L’originale è conservato e i salvataggi sono sospesi: ripristina un backup. \(error.localizedDescription)" }
        if !readOnly { do { try configureProtection(); applyProtection() } catch { protectionStatus = error.localizedDescription; protectionReady = false } }
    }
    @discardableResult func change(_ body: (inout HabitDatabase) throws -> Void, configure: Bool = false) -> Bool {
        guard !readOnly else { problem = "Ripristina un backup prima di modificare l’archivio."; return false }
        do {
            db = try repository.update(body)
            if configure { try configureProtection() }
            applyProtection(); WidgetCenter.shared.reloadAllTimelines(); syncReminders(); return true
        } catch { problem = error.localizedDescription; return false }
    }
    func applyProtection() {
        #if SCREEN_TIME
        guard AuthorizationCenter.shared.authorizationStatus == .approved, shared, protectionReady else { protectionStatus = shared ? "Autorizza Tempo di utilizzo e configura il monitoraggio" : "App Group non disponibile nel profilo di firma"; return }
        ScreenPolicy.apply(db); protectionStatus = "Regole inviate a iOS"
        #else
        protectionStatus = "Questa configurazione non blocca le altre app"
        #endif
    }
    func configureProtection() throws {
        #if SCREEN_TIME
        if db.rules.contains(where: \.enabled) || db.habits.contains(where: { $0.kind == .appTime }) {
            guard AuthorizationCenter.shared.authorizationStatus == .approved, shared else { protectionReady = false; ScreenPolicy.clear(db); throw HabitError.storage }
            do { try ScreenPolicy.configure(db); protectionReady = true } catch { ScreenPolicy.clear(db); protectionReady = false; protectionStatus = "Monitoraggio non configurato"; throw error }
        } else { ScreenPolicy.clear(db); protectionReady = true }
        #endif
    }
    func authorize() async {
        #if SCREEN_TIME
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual); try configureProtection(); applyProtection() } catch { problem = error.localizedDescription }
        #else
        problem = "Tempo di utilizzo richiede la configurazione completa con Family Controls e un profilo Apple Developer Program valido."
        #endif
    }
    @discardableResult func saveHabit(_ habit: Habit) -> Bool {
        change({ db in
            if habit.archived && db.rules.contains(where: { $0.enabled && $0.habitIDs.contains(habit.id) }) { throw HabitError.locked }
            if let old = db.habits.first(where: { $0.id == habit.id }), old != habit, db.rules.contains(where: { $0.habitIDs.contains(habit.id) && HabitEngine.locked($0, now: Date()) }) { throw HabitError.locked }
            if let i = db.habits.firstIndex(where: { $0.id == habit.id }) { db.habits[i] = habit } else { db.habits.append(habit) }
        }, configure: true)
    }
    @discardableResult func saveRule(_ rule: BlockRule) -> Bool {
        #if SCREEN_TIME
        if rule.enabled {
            guard AuthorizationCenter.shared.authorizationStatus == .approved, shared else { problem = "Autorizza Tempo di utilizzo e verifica l’App Group prima di attivare il blocco."; return false }
            do { _ = try ScreenPolicy.selection(rule.activitySelection) } catch { problem = "Scegli almeno un’app, una categoria o un sito da bloccare."; return false }
        }
        #else
        if rule.enabled { problem = "Puoi preparare questa regola; il blocco reale richiede la versione Screen Time firmata con Family Controls."; return false }
        #endif
        return change({ db in
            if let old = db.rules.first(where: { $0.id == rule.id }), old != rule, HabitEngine.locked(old, now: Date()) { throw HabitError.locked }
            if let i = db.rules.firstIndex(where: { $0.id == rule.id }) { db.rules[i] = rule } else { db.rules.append(rule) }
        }, configure: true)
    }
    func deleteRule(_ id: UUID) { change({ db in guard let rule = db.rules.first(where: { $0.id == id }) else { return }; guard !HabitEngine.locked(rule, now: Date()) else { throw HabitError.locked }; db.rules.removeAll { $0.id == id }; db.spends.removeAll { $0.ruleID == id } }, configure: true) }
    func add(_ habit: Habit, amount: Int = 1) { change { try HabitEngine.add(habit.id, amount: amount, db: &$0, now: Date()) } }
    func syncReminders() {
        reminderTask?.cancel()
        reminderTask = Task { try? await Task.sleep(for: .milliseconds(350)); guard !Task.isCancelled else { return }; let status = await HabitReminders.sync(db); if !Task.isCancelled { reminderStatus = status } }
    }
    func toggleDay(_ habit: Habit, date: Date) {
        let amount: Int? = Tracker.complete(habit, db: db, date: date) ? nil : 1
        _ = recordDay(habit, date: date, amount: amount, note: db.note(habit, on: date))
    }
    @discardableResult func recordDay(_ h: Habit, date: Date, amount: Int?, note: String) -> Bool {
        change { db in
            guard !db.rules.contains(where: { $0.habitIDs.contains(h.id) && HabitEngine.locked($0, now: Date()) }) else { throw HabitError.locked }
            try Tracker.record(h, db: &db, date: date, amount: amount, note: note)
        }
    }
    @discardableResult func saveTrackedHabit(_ h: Habit, plan: HabitPlan) -> Bool {
        var draft = db
        if let i = draft.habits.firstIndex(where: { $0.id == h.id }) { draft.habits[i] = h } else { draft.habits.append(h) }
        if draft.plans == nil { draft.plans = [:] }; draft.plans?[h.id.uuidString] = plan
        guard HabitReminders.count(draft) <= 60 else { problem = "Riduci i promemoria: massimo 60 combinazioni giorno/orario tra tutte le abitudini."; return false }
        return change({ db in
            guard !db.rules.contains(where: { $0.habitIDs.contains(h.id) && (HabitEngine.locked($0, now: Date()) || plan.quit) }) else { throw HabitError.locked }
            if h.archived && db.rules.contains(where: { $0.enabled && $0.habitIDs.contains(h.id) }) { throw HabitError.locked }
            if let i = db.habits.firstIndex(where: { $0.id == h.id }) { db.habits[i] = h } else { db.habits.append(h) }
            if db.plans == nil { db.plans = [:] }; db.plans?[h.id.uuidString] = plan
        }, configure: true)
    }
    @discardableResult func deleteHabit(_ h: Habit) -> Bool {
        change({ db in
            guard !db.rules.contains(where: { $0.habitIDs.contains(h.id) }) else { throw HabitError.locked }
            db.habits.removeAll { $0.id == h.id }; db.samples.removeAll { $0.habitID == h.id }
            db.plans?[h.id.uuidString] = nil; db.notes = db.notes?.filter { !$0.key.hasPrefix(h.id.uuidString + "|") }
            if db.timer?.habitID == h.id { db.timer = nil }
        }, configure: true)
    }
    func startTimer(_ habit: Habit) {
        change { db in HabitEngine.settleTimer(&db, now: Date()); db.timer = HabitTimer(habitID: habit.id, started: Date(), uptime: ProcessInfo.processInfo.systemUptime, background: habit.backgroundTimer) }
        LiveTimer.start(habit: habit, db: db)
    }
    func pauseTimer() { change { HabitEngine.settleTimer(&$0, now: Date()) }; LiveTimer.end() }
    func background() { if db.timer?.background == false { pauseTimer() } }
    func spend(_ id: UUID) { change({ try HabitEngine.spend(id, db: &$0, now: Date()) }, configure: true) }
    func emergency() {
        change({ db in guard db.emergencyUses > 0 else { throw HabitError.noCredit }; db.emergencyUses -= 1; db.emergencyUntil = Date().addingTimeInterval(3600) }, configure: true)
    }
    func connectHealth() async {
        #if HEALTH
        do { try await health.authorize(); change { $0.healthEnabled = true }; try await health.refresh(repository); refresh() } catch { problem = "Salute: \(error.localizedDescription)" }
        #else
        problem = "Salute è disponibile nel pacchetto con le capability appropriate."
        #endif
    }
    func refreshHealth() async {
        #if HEALTH
        guard db.healthEnabled else { return }
        do { try await health.refresh(repository); refresh(); WidgetCenter.shared.reloadAllTimelines() } catch { problem = "Salute: \(error.localizedDescription)" }
        #endif
    }
    func restore(_ data: Data) {
        do {
            var restored = try JSONDecoder().decode(HabitDatabase.self, from: data).validated()
            // Restores never silently activate app shields or retain authorization tokens.
            for i in restored.rules.indices { restored.rules[i].enabled = false; restored.rules[i].session = nil; restored.rules[i].activitySelection = nil; restored.rules[i].commitmentUntil = nil }
            for i in restored.habits.indices where restored.habits[i].kind == .appTime { restored.habits[i].activitySelection = nil }
            restored.timer = nil
            restored.emergencyUses = min(restored.emergencyUses, db.emergencyUses)
            restored.emergencyUntil = nil
            db = try repository.restore(JSONEncoder().encode(restored)); readOnly = false
            try configureProtection(); applyProtection(); WidgetCenter.shared.reloadAllTimelines(); syncReminders()
        } catch { problem = error.localizedDescription }
    }
}
struct HabitBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json,.commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { guard let d = configuration.file.regularFileContents else { throw HabitError.invalid }; data = d }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
