import SwiftUI
#if SCREEN_TIME
import FamilyControls
#endif

struct HabitEditor: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    @State var habit: Habit
    @State private var plan = HabitPlan()
    @State private var loaded = false
    @State private var iconSearch = ""
    @FocusState private var naming: Bool
    #if SCREEN_TIME
    @State private var selected = FamilyActivitySelection()
    @State private var picking = false
    #endif
    var isNew: Bool { !store.db.habits.contains { $0.id == habit.id } }
    var kinds: [HabitKind] {
        var result: [HabitKind] = [.check,.counter,.timer,.shortcut]
        #if HEALTH
        result += [.steps,.workout,.mindfulness]
        #endif
        #if SCREEN_TIME
        result += [.appTime]
        #endif
        return result
    }
    var body: some View {
        NavigationStack {
            Form {
                identity
                goals
                schedule
                reminders
                appearance
            }.navigationTitle(isNew ? "Nuova abitudine" : "Modifica abitudine").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() }.disabled(habit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            .onAppear {
                guard !loaded else { return }; plan = store.db.plan(habit); loaded = true
                #if SCREEN_TIME
                if let data = habit.activitySelection, let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selected = value }
                #endif
            }
            .onChange(of: habit.kind) { _, kind in if isNew { habit.goal = kind == .steps ? 10000 : kind.timed ? 1500 : 1; plan.scale = 1; plan.quit = false } }
            #if SCREEN_TIME
            .familyActivityPicker(isPresented: $picking, selection: $selected)
            #endif
        }
    }
    var identity: some View {
        Section("Abitudine") {
            TextField("Nome abitudine", text: $habit.title).focused($naming).submitLabel(.done).onSubmit { naming = false }
            TextField("Descrizione", text: $plan.description, axis: .vertical).lineLimit(2...4)
            TextField("Categoria", text: $plan.category)
            if isNew { Picker("Tracciamento", selection: $habit.kind) { ForEach(kinds) { Text($0.title).tag($0) } } } else { LabeledContent("Tracciamento", value: habit.kind.title) }
            if [.check,.counter].contains(habit.kind) { Toggle("Abitudine da abbandonare", isOn: $plan.quit) }
            if habit.kind == .counter && isNew { Toggle("Misura con decimali", isOn: Binding(get: { plan.scale == 1000 }, set: { flag in habit.goal = max(1,habit.goal / plan.scale) * (flag ? 1000 : 1); plan.scale = flag ? 1000 : 1 })) }
        }
    }
    var goals: some View {
        Section("Obiettivo") {
            if habit.kind != .check {
                TextField(plan.quit ? "Resta sotto" : "Obiettivo giornaliero", value: Binding<Double>(get: { Double(habit.goal) / Double(habit.kind.timed ? 60 : plan.scale) }, set: { value in if value.isFinite && value > 0 && value <= 100_000 { habit.goal = max(1,Int((value * Double(habit.kind.timed ? 60 : plan.scale)).rounded())) } }), format: .number).keyboardType(.decimalPad)
                if !habit.kind.timed { TextField("Unità (pagine, litri…)", text: $plan.unit) } else { Text("Obiettivo espresso in minuti").font(.caption) }
            }
            Picker("Frequenza", selection: $plan.period) { Text("Giornaliera").tag(GoalPeriod.daily); Text("Settimanale").tag(GoalPeriod.weekly); Text("Mensile").tag(GoalPeriod.monthly) }.onChange(of: plan.period) { _, period in plan.target = min(plan.target, period == .weekly ? 7 : period == .monthly ? 31 : 1) }
            if plan.period != .daily { Stepper("\(plan.target) giorni per \(plan.period == .weekly ? "settimana" : "mese")", value: $plan.target, in: 1...(plan.period == .weekly ? plan.weekdays.count : 31)) }
            if habit.kind == .timer { Toggle("Continua a schermo spento", isOn: $habit.backgroundTimer); Text("Il timer prosegue fino alla pausa; non alterna automaticamente lavoro e riposo.").font(.caption) }
            if habit.kind != .appTime { Toggle("Limita i crediti a uno al giorno", isOn: $habit.capOnceDaily); Text("Le quantità effettive rimangono nello storico anche oltre l’obiettivo.").font(.caption) }
            #if SCREEN_TIME
            if habit.kind == .appTime { Button("Scegli app o siti per l’obiettivo") { picking = true } }
            #endif
        }
    }
    var schedule: some View {
        Section("Giorni previsti") {
            ForEach(1...7, id: \.self) { day in Toggle(Calendar.current.weekdaySymbols[day-1], isOn: Binding(get: { plan.weekdays.contains(day) }, set: { flag in if flag { plan.weekdays.insert(day) } else if plan.weekdays.count > 1 { plan.weekdays.remove(day) } })) }
            DatePicker("Data di inizio", selection: $habit.created, in: Calendar.current.date(byAdding: .year, value: -20, to: Date())!...Date(), displayedComponents: .date).onChange(of: plan.weekdays) { _, days in if plan.period == .weekly { plan.target = min(plan.target,days.count) } }
            Text("I giorni non previsti non interrompono le serie giornaliere. I giorni futuri non si possono compilare.").font(.caption).foregroundStyle(.secondary)
        }
    }
    var reminders: some View {
        Section("Promemoria") {
            ForEach(plan.reminders.indices, id: \.self) { index in HStack {
                DatePicker("Orario \(index+1)", selection: Binding(get: { HabitFormat.date(plan.reminders[index]) }, set: { plan.reminders[index] = HabitFormat.minute($0) }), displayedComponents: .hourAndMinute)
                Button(role: .destructive) { plan.reminders.remove(at: index) } label: { Image(systemName: "minus.circle") }
            } }
            if plan.reminders.count < 3 { Button("Aggiungi promemoria") { let candidate = (0..<1440).first { !plan.reminders.contains($0) && $0 >= 540 } ?? 480; plan.reminders.append(candidate) } }
            Text("Fino a tre orari nei giorni previsti. iOS consente un numero limitato di richieste: l’app accetta al massimo 60 richieste totali (un orario quotidiano occupa una sola richiesta).").font(.caption).foregroundStyle(.secondary)
        }
    }
    var appearance: some View {
        Section("Aspetto") {
            NavigationLink { ScrollView { LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) { ForEach(HabitPalette.symbols.filter { iconSearch.isEmpty || $0.localizedCaseInsensitiveContains(iconSearch) }, id: \.self) { symbol in Button { habit.symbol = symbol } label: { Image(systemName: symbol).font(.title2).frame(width: 48,height: 48).background(habit.symbol == symbol ? habit.color.habitColor.opacity(0.25) : .clear,in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).accessibilityLabel(symbol) } }.padding() }.navigationTitle("Icona").searchable(text: $iconSearch, prompt: "Cerca simbolo") } label: { Label("Icona", systemImage: habit.symbol) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 9), spacing: 12) { ForEach(HabitPalette.colors,id: \.self) { color in Button { habit.color = color } label: { Circle().fill(color.paletteColor).frame(width: 26,height: 26).overlay { if habit.color == color { Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) } } }.buttonStyle(.plain).accessibilityLabel("Colore \(color)") } }
            Toggle("Archiviata", isOn: $habit.archived)
        }
    }
    func save() {
        habit.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if habit.kind == .check { habit.goal = 1; plan.scale = 1 }
        #if SCREEN_TIME
        if habit.kind == .appTime { do { let data = try JSONEncoder().encode(selected); _ = try ScreenPolicy.selection(data); habit.activitySelection = data; habit.capOnceDaily = true } catch { store.problem = "Scegli almeno un’app o un sito per l’obiettivo."; return } }
        #endif
        if store.saveTrackedHabit(habit, plan: plan) {
            if !plan.reminders.isEmpty { Task { do { _ = try await HabitReminders.authorize(); store.syncReminders() } catch { store.problem = error.localizedDescription } } }
            dismiss()
        }
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
                    ForEach(store.db.habits.filter { !$0.archived && !store.db.plan($0).quit }) { h in Toggle(h.title, isOn: Binding(get: { rule.habitIDs.contains(h.id) }, set: { value in if value { rule.habitIDs.append(h.id) } else { rule.habitIDs.removeAll { $0 == h.id }; rule.minimum = min(rule.minimum, max(1, rule.habitIDs.count)) } })) }
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
