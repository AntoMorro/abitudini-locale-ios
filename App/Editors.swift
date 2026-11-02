import SwiftUI
#if SCREEN_TIME
import FamilyControls
#endif

struct HabitEditor: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    @State var habit: Habit
    #if SCREEN_TIME
    @State private var selected = FamilyActivitySelection()
    @State private var picking = false
    #endif
    var isNew: Bool { !store.db.habits.contains { $0.id == habit.id } }
    var kinds: [HabitKind] {
        var result: [HabitKind] = [.check, .counter, .timer, .shortcut]
        #if HEALTH
        result += [.steps, .workout, .mindfulness]
        #endif
        #if SCREEN_TIME
        result += [.appTime]
        #endif
        return result
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Abitudine") { TextField("Nome abitudine", text: $habit.title); if isNew { Picker("Tipo", selection: $habit.kind) { ForEach(kinds) { Text($0.title).tag($0) } } } else { LabeledContent("Tipo", value: habit.kind.title) } }
                Section("Obiettivo") {
                    if habit.kind != .check {
                        Stepper("\(habit.kind.timed ? habit.goal / 60 : habit.goal) \(habit.kind.timed ? "minuti" : habit.kind == .steps ? "passi" : "unità")", value: Binding(get: { habit.kind.timed ? max(1, habit.goal / 60) : habit.goal }, set: { habit.goal = $0 * (habit.kind.timed ? 60 : 1) }), in: 1...100_000, step: habit.kind == .steps ? 100 : 1)
                    }
                    if habit.kind != .appTime { Toggle("Al massimo uno sblocco al giorno", isOn: $habit.capOnceDaily) }
                    if habit.kind == .timer { Toggle("Continua a schermo spento", isOn: $habit.backgroundTimer); Text("Per un ciclo di concentrazione imposta 25 minuti. Il timer continua fino a quando lo fermi; senza questa opzione si interrompe quando lasci l’app.").font(.caption).foregroundStyle(.secondary) }
                    if habit.kind == .shortcut { Text("In Comandi Rapidi usa “Imposta progresso giornaliero abitudine” e passa il totale di oggi. Puoi collegare dati di studio o altre sorgenti senza duplicare aggiornamenti ripetuti.").font(.caption).foregroundStyle(.secondary) }
                    if [.steps, .workout, .mindfulness].contains(habit.kind) { Text("Collega Salute dalle Impostazioni. Gli allenamenti sovrapposti vengono contati una volta sola.").font(.caption).foregroundStyle(.secondary) }
                    #if SCREEN_TIME
                    if habit.kind == .appTime { Button("Scegli app o siti per l’obiettivo") { picking = true }; Text("Questa versione rileva il raggiungimento di una soglia giornaliera, non un contatore in tempo reale.").font(.caption).foregroundStyle(.secondary) }
                    #endif
                }
                Section("Aspetto") {
                    Picker("Icona", selection: $habit.symbol) { Label("Spunta", systemImage: "checkmark").tag("checkmark"); Label("Studio", systemImage: "book.closed").tag("book.closed"); Label("Carte", systemImage: "rectangle.on.rectangle").tag("rectangle.on.rectangle"); Label("Movimento", systemImage: "figure.walk").tag("figure.walk"); Label("Meditazione", systemImage: "brain.head.profile").tag("brain.head.profile"); Label("Scrittura", systemImage: "pencil").tag("pencil") }
                    Picker("Colore", selection: $habit.color) { Text("Menta").tag("mint"); Text("Azzurro").tag("cyan"); Text("Blu").tag("blue"); Text("Arancione").tag("orange"); Text("Rosa").tag("pink"); Text("Viola").tag("purple") }
                    Toggle("Archiviata", isOn: $habit.archived)
                }
            }.navigationTitle(isNew ? "Nuova abitudine" : "Modifica abitudine").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salva", action: save).disabled(habit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            .onChange(of: habit.kind) { _, kind in if isNew { habit.goal = kind == .steps ? 10000 : kind.timed ? 1500 : 1; habit.capOnceDaily = true } }
            #if SCREEN_TIME
            .familyActivityPicker(isPresented: $picking, selection: $selected)
            .onAppear { if let data = habit.activitySelection, let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selected = value } }
            #endif
        }
    }
    func save() {
        habit.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if habit.kind == .check { habit.goal = 1 }
        #if SCREEN_TIME
        if habit.kind == .appTime { do { let data = try JSONEncoder().encode(selected); _ = try ScreenPolicy.selection(data); habit.activitySelection = data; habit.capOnceDaily = true } catch { store.problem = "Scegli almeno un’app o un sito per l’obiettivo."; return } }
        #endif
        if store.saveHabit(habit) { dismiss() }
    }
}
struct RuleEditor: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    @State var rule: BlockRule
    @State private var fullDay = true
    @State private var commitment = false
    @State private var until = Date().addingTimeInterval(86400)
    @FocusState private var naming: Bool
    #if SCREEN_TIME
    @State private var selected = FamilyActivitySelection()
    @State private var picking = false
    #endif
    var body: some View {
        NavigationStack {
            Form {
                Section("Blocco") { TextField("Nome blocco", text: $rule.title).focused($naming).submitLabel(.done).onSubmit { naming = false }; Toggle("Attivo", isOn: $rule.enabled)
                    #if SCREEN_TIME
                    Button("Scegli app, categorie e siti") { picking = true }
                    Text("\(selected.applicationTokens.count) app · \(selected.categoryTokens.count) categorie · \(selected.webDomainTokens.count) siti").font(.caption).foregroundStyle(.secondary)
                    #else
                    Text("Puoi preparare la regola. Per bloccare le altre app servirà la configurazione Screen Time firmata con Family Controls.").font(.caption).foregroundStyle(.secondary)
                    #endif
                }
                Section("Cosa guadagna uno sblocco") {
                    ForEach(store.db.habits.filter { !$0.archived }) { h in Toggle(h.title, isOn: Binding(get: { rule.habitIDs.contains(h.id) }, set: { value in if value { rule.habitIDs.append(h.id) } else { rule.habitIDs.removeAll { $0 == h.id }; rule.minimum = min(rule.minimum, max(1, rule.habitIDs.count)) } })) }
                    Picker("Richiedi", selection: $rule.requirement) { ForEach(Requirement.allCases) { Text($0.title).tag($0) } }
                    if rule.requirement == .atLeast { Stepper("Almeno \(rule.minimum)", value: $rule.minimum, in: 1...max(1, rule.habitIDs.count)) }
                }
                Section("Quando") {
                    Toggle("Tutto il giorno", isOn: $fullDay)
                    if !fullDay { DatePicker("Dalle", selection: Binding(get: { HabitFormat.date(rule.startMinute) }, set: { rule.startMinute = HabitFormat.minute($0) }), displayedComponents: .hourAndMinute); DatePicker("Alle", selection: Binding(get: { HabitFormat.date(rule.endMinute) }, set: { rule.endMinute = HabitFormat.minute($0) }), displayedComponents: .hourAndMinute) }
                    ForEach(1...7, id: \.self) { day in Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { rule.weekdays.contains(day) }, set: { value in if value { rule.weekdays.insert(day) } else { rule.weekdays.remove(day) } })) }
                    Text("Le fasce notturne appartengono al giorno in cui iniziano. Durata minima di una fascia: 15 minuti.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Quando usi uno sblocco") {
                    Picker("Modalità", selection: $rule.unlockMode) { ForEach(UnlockMode.allCases) { Text($0.title).tag($0) } }
                    if rule.unlockMode != .day { Stepper("\(rule.unlockMinutes) minuti", value: $rule.unlockMinutes, in: 1...240) }
                    Text("Timer continuo: il tempo scorre anche a schermo spento. Utilizzo effettivo: iOS richiude dopo la soglia cumulativa nelle app scelte. L’esecuzione in background è gestita da iOS e può avere ritardi.").font(.caption).foregroundStyle(.secondary)
                }
                if rule.enabled { Section("Impegno") { Toggle("Blocca le modifiche fino a una data", isOn: $commitment); if commitment { DatePicker("Scadenza", selection: $until, in: Date()...); Text("Fino alla scadenza non potrai modificare o spegnere questa regola dall’app. Restano disponibili le emergenze e i controlli di autorizzazione di iOS.").font(.caption).foregroundStyle(.secondary) } } }
            }.navigationTitle("Regola di sblocco").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salva", action: save).disabled(rule.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rule.habitIDs.isEmpty) } }
            .onAppear { fullDay = rule.startMinute == rule.endMinute || (rule.startMinute == 0 && rule.endMinute == 1440); commitment = rule.commitmentUntil != nil; until = rule.commitmentUntil ?? Date().addingTimeInterval(86400) }
            #if SCREEN_TIME
            .familyActivityPicker(isPresented: $picking, selection: $selected)
            .onAppear { if let data = rule.activitySelection, let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selected = value } }
            #endif
        }
    }
    func save() {
        if fullDay { rule.startMinute = 0; rule.endMinute = 1440 }
        rule.title = rule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.commitmentUntil = rule.enabled && commitment ? until : nil
        #if SCREEN_TIME
        rule.activitySelection = try? JSONEncoder().encode(selected)
        #endif
        if store.saveRule(rule) { dismiss() }
    }
}
