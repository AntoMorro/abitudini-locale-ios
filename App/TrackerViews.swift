import SwiftUI
import Charts

struct HabitBoard: View {
    @EnvironmentObject var store: HabitStore
    @AppStorage("trackerLayout") private var layout = "cards"
    @State private var category = "Tutte"
    @State private var archived = false
    @State private var creating: Habit?
    var habits: [Habit] { store.db.habits.filter { $0.archived == archived && (category == "Tutte" || store.db.plan($0).category == category) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack { Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide))).foregroundStyle(.secondary); Spacer(); Text("\(habits.filter { Tracker.complete($0, db: store.db, date: Date()) }.count)/\(habits.count)").monospacedDigit().foregroundStyle(.secondary) }.font(.subheadline)
                    if store.db.habits.isEmpty { ContentUnavailableView("Il tuo primo quadratino", systemImage: "square.grid.3x3.fill", description: Text("Una piccola azione alla volta. Tocca + per iniziare.")) }
                    if layout == "grid" {
                        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 12) { ForEach(habits) { h in card(h, compact: true) } }
                    } else {
                        LazyVStack(spacing: 14) { ForEach(habits) { h in card(h, compact: layout == "list") } }
                    }
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle(archived ? "Archivio" : "Abitudini")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Menu {
                    Picker("Vista", selection: $layout) { Text("Schede").tag("cards"); Text("Compatta").tag("list"); Text("Griglia").tag("grid") }
                    Picker("Categoria", selection: $category) { Text("Tutte").tag("Tutte"); ForEach(Array(Set(store.db.habits.map { store.db.plan($0).category }.filter { !$0.isEmpty })).sorted(), id: \.self) { Text($0).tag($0) } }
                    Toggle("Mostra archiviate", isOn: $archived)
                    NavigationLink("Riordina abitudini") { HabitOrder() }
                } label: { Image(systemName: "line.3.horizontal.decrease") }.accessibilityLabel("Vista e filtri") }
                ToolbarItem(placement: .topBarTrailing) { Button { creating = Habit(title: "") } label: { Image(systemName: "plus") }.accessibilityLabel("Nuova abitudine") }
            }.sheet(item: $creating) { HabitEditor(habit: $0) }
        }
    }
    func card(_ h: Habit, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                NavigationLink { HabitDetail(habitID: h.id) } label: { HStack { Image(systemName: h.symbol).foregroundStyle(h.color.habitColor); Text(h.title).font(.headline).foregroundStyle(.primary).lineLimit(2) } }.accessibilityIdentifier("detail-" + h.title)
                Spacer(minLength: 2)
                if !h.archived && h.kind == .check { Button { store.toggleDay(h, date: Date()) } label: { Image(systemName: Tracker.complete(h, db: store.db, date: Date()) ? "checkmark.circle.fill" : "circle").font(.title2) }.tint(h.color.habitColor).accessibilityLabel("Completa \(h.title)") }
                else if !h.archived && h.kind == .counter { NavigationLink { HabitDetail(habitID: h.id) } label: { Image(systemName: "plus.circle").font(.title2) }.tint(h.color.habitColor) }
            }
            if layout != "list" { TrackerGrid(habit: h, db: store.db, weeks: compact ? 8 : 26) }
            let p = store.db.plan(h), progress = Tracker.periodProgress(h, db: store.db, date: Date())
            HStack { Text(p.category.isEmpty ? (p.quit ? "Da abbandonare" : "Da costruire") : p.category); Spacer(); Text(p.period == .daily ? "Ogni giorno previsto" : "\(progress.0)/\(progress.1) · \(p.period == .weekly ? "settimana" : "mese")") }.font(.caption2).foregroundStyle(.secondary)
        }.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
struct TrackerGrid: View {
    let habit: Habit
    let db: HabitDatabase
    var weeks = 26
    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = (cal.component(.weekday, from: today) - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -((weeks - 1)*7 + weekday), to: today)!
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<weeks, id: \.self) { column in
                    VStack(spacing: 3) { ForEach(0..<7, id: \.self) { row in
                        let date = cal.date(byAdding: .day, value: column*7+row, to: start)!
                        let complete = Tracker.complete(habit, db: db, date: date)
                        let amount = Tracker.total(habit, db: db, date: date)
                        let due = Tracker.scheduled(habit, db: db, date: date) && date <= today
                        RoundedRectangle(cornerRadius: 2).fill(date > today || date < cal.startOfDay(for: habit.created) ? Color.clear : complete ? habit.color.habitColor : amount > 0 && !db.plan(habit).quit ? habit.color.habitColor.opacity(0.4) : Color.gray.opacity(due ? 0.18 : 0.07))
                            .frame(width: max(1,(geometry.size.width - CGFloat(weeks-1)*3)/CGFloat(weeks)), height: max(1,(geometry.size.width - CGFloat(weeks-1)*3)/CGFloat(weeks)))
                            .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(complete ? "completata" : "non completata")")
                    } }
                }
            }
        }.aspectRatio(CGFloat(weeks)/7, contentMode: .fit).accessibilityElement(children: .ignore).accessibilityLabel("Griglia di \(weeks) settimane di \(habit.title)")
    }
}
struct HabitDetail: View {
    @EnvironmentObject var store: HabitStore
    let habitID: UUID
    @State private var editing: Habit?
    @State private var selected = Date()
    @State private var logging = false
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var habit: Habit? { store.db.habits.first { $0.id == habitID } }
    var body: some View {
        Group { if let h = habit {
            List {
                Section {
                    Label(h.title, systemImage: h.symbol).font(.title2.bold()).foregroundStyle(h.color.habitColor)
                    if !store.db.plan(h).description.isEmpty { Text(store.db.plan(h).description).foregroundStyle(.secondary) }
                    TrackerGrid(habit: h, db: store.db, weeks: 26)
                    NavigationLink("Un anno di progressi") { ScrollView(.horizontal) { TrackerGrid(habit: h, db: store.db, weeks: 53).frame(width: 760).padding() }.navigationTitle("Il tuo anno") }
                    let stats = Tracker.stats(h, db: store.db)
                    HStack { metric("Serie attuale", stats.current); Spacer(); metric("Record", stats.longest); Spacer(); metric("Giorni", stats.completions) }
                    Text("Le serie contano \(store.db.plan(h).period == .daily ? "giorni previsti" : store.db.plan(h).period == .weekly ? "settimane con obiettivo raggiunto" : "mesi con obiettivo raggiunto"). Il periodo corrente ancora aperto non interrompe la serie.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Oggi") {
                    if h.kind == .timer { TimelineView(.periodic(from: .now, by: 1)) { ctx in HabitProgressRow(habit: h, now: ctx.date) } }
                    else if h.kind.automatic { HabitProgressRow(habit: h); Text("Valori aggiornati dalla sorgente autorizzata.").font(.caption) }
                    else { Button(Tracker.complete(h, db: store.db, date: Date()) ? "Modifica oggi" : "Registra oggi") { selected = Date(); logging = true }.disabled(h.archived) }
                }
                Section("Calendario e note") {
                    DatePicker("Giorno", selection: $selected, in: min(h.created, Date())...Date(), displayedComponents: .date).datePickerStyle(.graphical)
                    Text("\(Tracker.total(h, db: store.db, date: selected)) \(store.db.plan(h).unit) · \(Tracker.complete(h, db: store.db, date: selected) ? "Completata" : "Non completata")").font(.caption)
                    if !store.db.note(h, on: selected).isEmpty { Text(store.db.note(h, on: selected)) }
                    Button("Modifica giorno selezionato") { logging = true }.disabled(h.archived || h.kind.automatic).accessibilityIdentifier("editDay")
                }
                Section("Ultimi dodici mesi") { MonthChart(habit: h, db: store.db) }
                Section {
                    ShareLink(item: "\(h.title): \(Tracker.stats(h, db: store.db).completions) giorni completati con Abitudini Locale") { Label("Condividi riepilogo", systemImage: "square.and.arrow.up") }
                    ShareLink(item: Tracker.csv(store.db)) { Label("Esporta dati CSV", systemImage: "tablecells") }
                    Button(h.archived ? "Ripristina abitudine" : "Archivia abitudine") { var next = h; next.archived.toggle(); _ = store.saveHabit(next) }
                    Button("Elimina abitudine", role: .destructive) { deleting = true }
                }
            }.navigationTitle(h.title).navigationBarTitleDisplayMode(.inline).toolbar { Button("Modifica") { editing = h } }
            .sheet(item: $editing) { HabitEditor(habit: $0) }
            .sheet(isPresented: $logging) { DayLog(habit: h, date: selected) }
            .alert("Eliminare abitudine e storico?", isPresented: $deleting) { Button("Annulla", role: .cancel) {}; Button("Elimina", role: .destructive) { if store.deleteHabit(h) { dismiss() } } } message: { Text("Questa operazione cancella anche note e progressi. Le abitudini collegate a blocchi devono essere prima scollegate.") }
        } else { ContentUnavailableView("Abitudine non disponibile", systemImage: "archivebox") } }
    }
    func metric(_ title: String, _ value: Int) -> some View { VStack(alignment: .leading) { Text("\(value)").font(.title2.bold().monospacedDigit()); Text(title).font(.caption2).foregroundStyle(.secondary) } }
}
struct DayLog: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let date: Date
    @State private var value = ""
    @State private var note = ""
    @State private var done = false
    var body: some View {
        NavigationStack { Form {
            Section(date.formatted(date: .complete, time: .omitted)) {
                if habit.kind == .check { Toggle(store.db.plan(habit).quit ? "Giornata senza questa abitudine" : "Completata", isOn: $done) }
                else { TextField(habit.kind.timed ? "Minuti totali" : "Totale \(store.db.plan(habit).unit)", text: $value).keyboardType(.decimalPad).accessibilityIdentifier("dayAmount"); if store.db.plan(habit).quit { Text("Una giornata registrata sotto il limite è riuscita. Un giorno senza registrazione resta sconosciuto.").font(.caption) } }
            }
            Section("Nota del giorno") { TextEditor(text: $note).frame(minHeight: 100).accessibilityIdentifier("dayNote") }
            Section { Button("Cancella registrazione", role: .destructive) { if store.recordDay(habit, date: date, amount: nil, note: "") { dismiss() } } }
        }.navigationTitle("Registra giornata").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salva giornata") { save() } } }
        .onAppear { let raw = Tracker.total(habit, db: store.db, date: date); value = String(Double(raw)/Double(habit.kind.timed ? 60 : store.db.plan(habit).scale)); done = Tracker.complete(habit, db: store.db, date: date); note = store.db.note(habit, on: date) }
    }
    func save() {
        let amount: Int?
        if habit.kind == .check { amount = done ? 1 : nil }
        else {
            guard let number = Double(value.replacingOccurrences(of: ",", with: ".")), number.isFinite, number >= 0, number <= 1_000_000 else { store.problem = "Inserisci un valore positivo valido."; return }
            amount = Int((number * Double(habit.kind.timed ? 60 : store.db.plan(habit).scale)).rounded())
        }
        if store.recordDay(habit, date: date, amount: amount, note: note) { dismiss() }
    }
}
struct MonthChart: View {
    var habit: Habit
    var db: HabitDatabase
    var data: [(Date,Int)] {
        let c = Calendar.current, this = c.dateInterval(of: .month, for: Date())!.start
        return (0..<12).reversed().map { offset in
            let start = c.date(byAdding: .month, value: -offset, to: this)!, days = c.range(of: .day, in: .month, for: start)!
            let count = days.filter { d in let date = c.date(byAdding: .day, value: d-1, to: start)!; return date <= Date() && Tracker.complete(habit, db: db, date: date) }.count
            return (start,count)
        }
    }
    var body: some View { Chart(data, id: \.0) { point in BarMark(x: .value("Mese", point.0, unit: .month), y: .value("Completamenti", point.1)).foregroundStyle(habit.color.habitColor) }.frame(height: 170).chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }.accessibilityLabel("Completamenti mensili") }
}
struct HabitOrder: View {
    @EnvironmentObject var store: HabitStore
    var body: some View { List { ForEach(store.db.habits) { h in Label(h.title, systemImage: h.symbol) }.onMove { from, to in store.change { $0.habits.move(fromOffsets: from, toOffset: to) } } }.environment(\.editMode, .constant(.active)).navigationTitle("Riordina") }
}
struct TrackerOverview: View {
    @EnvironmentObject var store: HabitStore
    var body: some View { NavigationStack { List {
        ForEach(store.db.habits.filter { !$0.archived }) { h in Section { NavigationLink { HabitDetail(habitID: h.id) } label: { Label(h.title, systemImage: h.symbol).foregroundStyle(h.color.habitColor) }; let stats = Tracker.stats(h, db: store.db); LabeledContent("Giorni completati", value: "\(stats.completions)"); LabeledContent("Tasso nei giorni previsti conclusi", value: stats.rate.formatted(.percent.precision(.fractionLength(0)))); LabeledContent("Serie / record", value: "\(stats.current) / \(stats.longest)"); MonthChart(habit: h, db: store.db) } }
    }.navigationTitle("Statistiche") } }
}
