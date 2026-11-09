import SwiftUI

@main struct AbitudiniLocaleApp: App {
    @StateObject private var store = HabitStore()
    var body: some Scene { WindowGroup { HabitRoot().environmentObject(store).tint(.mint).preferredColorScheme(store.db.theme == "system" ? nil : store.db.theme == "dark" ? .dark : .light).environment(\.locale, Locale(identifier: "it_IT")) } }
}
struct HabitRoot: View {
    @EnvironmentObject var store: HabitStore
    @State private var showingWellness=false
    @Environment(\.scenePhase) var phase
    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--render-probe"), let h = store.db.habits.first {
                NavigationStack { HabitDetail(habitID: h.id) }
                    .task { try? await Task.sleep(for: .seconds(2)); try? Data("rendered".utf8).write(to: HabitEnvironment.repository.directory.appendingPathComponent("probe-ready")) }
            } else {
                standardRoot
            }
            #else
            standardRoot
            #endif
        }
        .alert("Abitudini Locale", isPresented: Binding(get: { store.problem != nil }, set: { if !$0 { store.problem = nil } })) { Button("OK") { store.problem = nil } } message: { Text(store.problem ?? "") }
        .onChange(of: phase) { _, next in JournalPrivacy.shared.update(enabled:store.journal.preferences.lock,active:next == .active,background:next == .background); if next == .active { store.refresh(); store.syncReminders(); Task { await store.refreshHealth() } } else if next == .inactive { store.background() } }
        .onChange(of: store.journal.preferences.lock) { _, enabled in JournalPrivacy.shared.update(enabled:enabled,active:phase == .active,background:phase == .background) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("wellness.open"))) { _ in showingWellness=true }
        .sheet(isPresented:$showingWellness){NavigationStack{WellnessHome().toolbar{Button("Fine"){showingWellness=false}}}}
        .onReceive(NotificationCenter.default.publisher(for: .habitDataChanged)) { _ in store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in store.refresh() }
        .onOpenURL { url in if let id = UUID(uuidString: url.lastPathComponent), let h = store.db.habits.first(where: { $0.id == id }) { store.routeHabit = h } }
        .sheet(item: $store.routeHabit) { HabitEditor(habit: $0) }
        .task { store.syncReminders(); JournalPhoneBridge.shared.start(store); JournalPrivacy.shared.update(enabled:store.journal.preferences.lock,active:true) }
    }
    @ViewBuilder var standardRoot: some View {
            if !store.db.onboarded && !store.readOnly { HabitWelcome() }
            else { JournalTabs() }
    }
}
struct HabitWelcome: View {
    @EnvironmentObject var store: HabitStore
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 27) {
            Image(systemName: "leaf.fill").font(.system(size: 60)).foregroundStyle(.mint).padding(.top, 50)
            Text("Un giorno.\nUn quadratino.").font(.system(size: 42, weight: .bold, design: .rounded))
            Text("Raccogli le tue abitudini, osserva i progressi e costruisci il tuo ritmo.").font(.title3).foregroundStyle(.secondary)
            Label("Scegli le tue abitudini e i loro obiettivi", systemImage: "checklist")
            Label("Ritrova i progressi e lo storico ogni giorno", systemImage: "square.grid.3x3")
            Label("Calendario, note e promemoria, sul tuo iPhone", systemImage: "calendar")
            Button("Inizia") { store.change { $0.onboarded = true } }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
            Button("Esplora un esempio") { store.change { $0 = HabitEngine.demo() } }.frame(maxWidth: .infinity)
        }.padding(28) }
    }
}
extension String { var habitColor: Color { paletteColor } }

enum HabitFormat {
    static func amount(_ amount: Int, habit: Habit) -> String { habit.kind.timed ? "\(amount / 60):" + String(format: "%02d", amount % 60) : "\(amount)" }
    static func date(_ minute: Int) -> Date { Calendar.current.date(byAdding: .minute, value: minute, to: Calendar.current.startOfDay(for: Date()))! }
    static func minute(_ date: Date) -> Int { Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date) }
}
struct HabitProgressRow: View {
    @EnvironmentObject var store: HabitStore
    let habit: Habit
    var now = Date()
    var body: some View {
        let amount = HabitEngine.progress(habit, in: store.db, now: now)
        HStack(spacing: 11) {
            Image(systemName: habit.symbol).foregroundStyle(habit.color.habitColor).frame(width: 25)
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(habit.title).font(.subheadline.weight(.medium)); Spacer(); Text("\(HabitFormat.amount(amount, habit: habit)) / \(HabitFormat.amount(habit.goal, habit: habit))").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                ProgressView(value: min(1, Double(amount) / Double(habit.goal))).tint(habit.color.habitColor)
            }
            if habit.kind == .timer {
                Button { if store.db.timer?.habitID == habit.id { store.pauseTimer() } else { store.startTimer(habit) } } label: { Image(systemName: store.db.timer?.habitID == habit.id ? "pause.circle.fill" : "play.circle.fill").font(.title2) }.buttonStyle(.plain).tint(habit.color.habitColor).accessibilityLabel("Timer \(habit.title)")
            } else if [.check, .counter].contains(habit.kind) {
                Button { store.add(habit) } label: { Image(systemName: amount >= habit.goal && habit.capOnceDaily ? "checkmark.circle.fill" : "plus.circle.fill").font(.title2) }.buttonStyle(.plain).tint(habit.color.habitColor).disabled(amount >= habit.goal && habit.capOnceDaily).accessibilityLabel("Completa \(habit.title)")
            }
        }.padding(.vertical, 5)
    }
}
struct BlocksView: View {
    @EnvironmentObject var store: HabitStore
    @State private var draft: BlockRule?
    @State private var habit: Habit?
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: store.db.timer == nil ? 60 : 1)) { context in
                List {
                    Section { VStack(alignment: .leading, spacing: 7) { Text("Guadagna le tue distrazioni.").font(.headline); Text(store.protectionStatus).font(.caption).foregroundStyle(.secondary) } }
                    ForEach(store.db.rules) { rule in
                        Section {
                            HStack {
                                Button { draft = rule } label: { Label(rule.title, systemImage: "lock.shield").font(.headline).foregroundStyle(.primary) }.buttonStyle(.plain)
                                Spacer()
                                Toggle("Attiva \(rule.title)", isOn: Binding(get: { rule.enabled }, set: { value in var next = rule; next.enabled = value; _ = store.saveRule(next) })).labelsHidden()
                            }
                            Text(rule.requirement.title.uppercased()).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            ForEach(rule.habitIDs.compactMap { id in store.db.habits.first { $0.id == id } }) { h in HabitProgressRow(habit: h, now: context.date) }
                            let credits = HabitEngine.credits(rule, db: store.db, now: context.date)
                            if HabitEngine.sessionOpen(rule, now: context.date), let session = rule.session {
                                HStack { Image(systemName: "lock.open.fill").foregroundStyle(.mint); if session.mode == .usage { Text("Sblocco: \(session.minutes) minuti di utilizzo effettivo") } else { Text("Sbloccato fino alle \(session.ends.formatted(date: .omitted, time: .shortened))") } }.font(.caption)
                            } else {
                                Button("Usa sblocco · \(credits) disponibili") { store.spend(rule.id) }.buttonStyle(.borderedProminent).disabled(credits == 0 || !HabitEngine.active(rule, now: context.date) || !store.protectionReady)
                            }
                            if let until = rule.commitmentUntil, until > context.date { Label("Impegno fino a \(until.formatted(date: .abbreviated, time: .shortened))", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                            Button("Modifica regola") { draft = rule }.font(.caption)
                        }
                    }.onDelete { offsets in let ids = offsets.map { store.db.rules[$0].id }; ids.forEach(store.deleteRule) }
                    if store.db.rules.isEmpty { Section { Text("Crea le abitudini, poi scegli cosa deve sbloccare le app.").foregroundStyle(.secondary); Button("Nuova abitudine") { habit = Habit(title: "") }; Button("Nuovo blocco") { draft = BlockRule(title: "") } } }
                }
            }.navigationTitle("blocchi").toolbar { Button { draft = BlockRule(title: "") } label: { Image(systemName: "plus") }.accessibilityLabel("Nuovo blocco").accessibilityIdentifier("newBlock") }
            .sheet(item: $draft) { RuleEditor(rule: $0) }.sheet(item: $habit) { HabitEditor(habit: $0) }
        }
    }
}
struct HabitInsights: View {
    @EnvironmentObject var store: HabitStore
    @State private var draft: Habit?
    @State private var segment = "Abitudini"
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: store.db.timer == nil ? 60 : 1)) { context in
                List {
                    Section { Picker("Mostra", selection: $segment) { Text("Abitudini").tag("Abitudini"); Text("Tempo di utilizzo").tag("Tempo di utilizzo") }.pickerStyle(.segmented) }
                    if segment == "Abitudini" {
                        ForEach(store.db.habits.filter { !$0.archived }) { h in Section {
                            HabitProgressRow(habit: h, now: context.date)
                            HabitHeatmap(habit: h, db: store.db, now: context.date)
                            HStack { Text(h.kind.title).font(.caption).foregroundStyle(.secondary); Spacer(); Button("Modifica") { draft = h }.font(.caption) }
                        } }
                        if store.db.habits.isEmpty { Section { Text("Una piccola azione, ogni giorno.").foregroundStyle(.secondary); Button("Nuova abitudine") { draft = Habit(title: "") } } }
                        if store.db.habits.contains(where: \.archived) { Section("Archiviate") { ForEach(store.db.habits.filter(\.archived)) { h in Button(h.title) { draft = h } } } }
                    } else { ScreenTimeInsights() }
                }
            }.navigationTitle("statistiche").toolbar { Button { draft = Habit(title: "") } label: { Image(systemName: "plus") }.accessibilityLabel("Nuova abitudine") }.sheet(item: $draft) { HabitEditor(habit: $0) }
        }
    }
}
struct HabitHeatmap: View {
    var habit: Habit; var db: HabitDatabase; var now = Date()
    var body: some View {
        let values = HabitEngine.heatmap(habit, db: db, now: now)
        VStack(alignment: .leading, spacing: 5) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 21), spacing: 3) { ForEach(values.indices, id: \.self) { i in RoundedRectangle(cornerRadius: 2).fill(values[i].1 > 0 ? habit.color.habitColor.opacity(0.25 + values[i].1 * 0.75) : .gray.opacity(0.15)).aspectRatio(1, contentMode: .fit).accessibilityLabel("\(values[i].0.formatted(date: .abbreviated, time: .omitted)): \(Int(values[i].1 * 100))%") } }
            Text("Ultime 12 settimane").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
