import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: WeddingStore
    @State private var edit: EditRequest?; @State private var search = ""
    @State private var status: TaskStatus?; @State private var category: Category?; @State private var priority: Priority?
    @State private var calendar = false; @State private var day = Date(); @State private var ordering = "Scadenza"
    private var tasks: [WeddingTask] {
        store.db.tasks.filter { t in (search.isEmpty || [t.title,t.notes,t.owner].joined().localizedCaseInsensitiveContains(search)) && (status == nil || t.status == status) && (category == nil || t.category == category) && (priority == nil || t.priority == priority) && (!calendar || t.due.map {Calendar.current.isDate($0,inSameDayAs:day)} == true) }.sorted { a,b in switch ordering { case "Priorità": return a.priority.rank == b.priority.rank ? a.title < b.title : a.priority.rank > b.priority.rank; case "Titolo": return a.title.localizedStandardCompare(b.title) == .orderedAscending; default: return (a.due ?? .distantFuture) < (b.due ?? .distantFuture) } }
    }
    var body: some View {
        List {
            Section {
                Toggle("Vista calendario",isOn:$calendar)
                if calendar { DatePicker("Giorno",selection:$day,displayedComponents:.date).datePickerStyle(.graphical); Text("Il calendario filtra le attività con scadenza nel giorno selezionato. Disattivalo per vedere anche quelle senza scadenza.").font(.caption).foregroundStyle(.secondary) }
                Picker("Stato",selection:$status) { Text("Tutti").tag(nil as TaskStatus?); ForEach(TaskStatus.allCases) {Text($0.rawValue).tag(Optional($0))} }
                Picker("Categoria",selection:$category) { Text("Tutte").tag(nil as Category?); ForEach(Category.allCases) {Text($0.rawValue).tag(Optional($0))} }
                Picker("Priorità",selection:$priority) { Text("Tutte").tag(nil as Priority?); ForEach(Priority.allCases) {Text($0.rawValue).tag(Optional($0))} }
                Picker("Ordina per",selection:$ordering) { ForEach(["Scadenza","Priorità","Titolo"],id:\.self) {Text($0)} }
            }
            Section("\(tasks.count) attività · \(store.db.completed)/\(store.db.tasks.count) completate") {
                if tasks.isEmpty { EmptyHint(title:"Un passo alla volta",text:"Aggiungi un’attività con + oppure modifica i filtri.",icon:"checklist") }
                ForEach(tasks) { t in HStack {
                    Button { _ = store.change { db in if let i = db.tasks.firstIndex(where:{$0.id == t.id}) { db.tasks[i].status = t.status == .done ? .open : .done } } } label:{Image(systemName:t.status == .done ? "checkmark.circle.fill" : "circle").font(.title2).frame(minWidth:44,minHeight:44)}.buttonStyle(.borderless).accessibilityLabel(t.status == .done ? "Riapri attività" : "Completa attività")
                    Button {edit = EditRequest(kind:.task,objectID:t.id)} label:{ VStack(alignment:.leading,spacing:5) { Text(t.title).strikethrough(t.status == .done).foregroundStyle(.primary); Text("\(t.category.rawValue) · \(t.priority.rawValue)").font(.caption).foregroundStyle(.secondary); if let due = t.due {Text(due,format:.dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(due < Date() && t.status != .done ? .red : .secondary)} }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.borderless)
                } }
            }
        }.navigationTitle("Attività").searchable(text:$search,prompt:"Titolo, note o responsabile").toolbar {Button {edit = EditRequest(kind:.task)} label:{Image(systemName:"plus").accessibilityLabel("Nuova attività")}.accessibilityIdentifier("addTask")}.sheet(item:$edit) {EntityEditor($0,archive:store.db)}
    }
}
struct GuestsView: View {
    @EnvironmentObject var store: WeddingStore
    @State private var search = ""; @State private var rsvp: RSVP?; @State private var unassigned = false; @State private var edit:EditRequest?
    private var guests:[Guest] { store.db.guests.filter { g in (search.isEmpty || [g.name,g.group,g.notes,g.diet,g.allergies].joined().localizedCaseInsensitiveContains(search)) && (rsvp == nil || g.rsvp == rsvp) && (!unassigned || (g.tableID == nil && g.seats > 0)) }.sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending} }
    var body: some View {
        List {
            Section { Text("\(store.db.guests.count) nominativi · \(store.db.totalSeats) posti richiesti").font(.headline); Text("Confermati \(store.db.people(.confirmed)) · In attesa \(store.db.people(.pending)) · Non partecipano \(store.db.people(.declined))").font(.subheadline); Picker("RSVP",selection:$rsvp) {Text("Tutti").tag(nil as RSVP?); ForEach(RSVP.allCases) {Text($0.rawValue).tag(Optional($0))}}; Toggle("Solo senza tavolo",isOn:$unassigned) }
            if guests.isEmpty {EmptyHint(title:"Le persone del vostro giorno",text:"Aggiungi un invitato con +. Gli accompagnatori contano nei posti.",icon:"person.2")}
            ForEach(guests) { g in
                Button {edit = EditRequest(kind:.guest,objectID:g.id)} label:{ VStack(alignment:.leading,spacing:6) { HStack {Text(g.name).font(.headline); Spacer(); Text("\(g.seats) posti").font(.caption)}; Text([g.group,g.rsvp.rawValue,store.db.tables.first {$0.id == g.tableID}?.name ?? "Senza tavolo"].filter {!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(.secondary); if !g.allergies.isEmpty {Label(g.allergies,systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange)} }.foregroundStyle(.primary).padding(.vertical,5) }
                .swipeActions(edge:.leading) {Button("Conferma") {setRSVP(g,.confirmed)}.tint(.green)}
                .contextMenu {ForEach(RSVP.allCases) { status in Button(status.rawValue) {setRSVP(g,status)} } }
            }
        }.navigationTitle("Invitati").searchable(text:$search,prompt:"Nome, nucleo, dieta o note").toolbar { Button {edit = EditRequest(kind:.guest)} label:{Image(systemName:"plus").accessibilityLabel("Nuovo invitato")}.accessibilityIdentifier("addGuest") }.sheet(item:$edit) {EntityEditor($0,archive:store.db)}
    }
    private func setRSVP(_ guest:Guest,_ status:RSVP) { _ = store.change { db in if let i = db.guests.firstIndex(where:{$0.id == guest.id}) {db.guests[i].rsvp = status} } }
}
struct BudgetView: View {
    @EnvironmentObject var store:WeddingStore; @State private var edit:EditRequest?
    var body:some View {
        List {
            Section {
                Text(store.money(store.db.settings.budget)).font(.system(.largeTitle,design:.rounded).bold()); Text("Budget complessivo").foregroundStyle(.secondary)
                if store.db.settings.budget > 0 {ProgressView(value:Double(min(store.db.committed,store.db.settings.budget)),total:Double(store.db.settings.budget)).tint(store.db.available < 0 ? .red : Palette.rose)}
                LabeledContent("Impegnato (preventivi o previsioni)",value:store.money(store.db.committed)); LabeledContent("Disponibile",value:store.money(store.db.available)).foregroundStyle(store.db.available < 0 ? .red : .primary)
                LabeledContent("Previsioni iniziali",value:store.money(store.db.planned)); LabeledContent("Pagato",value:store.money(store.db.paid)); LabeledContent("Saldo da versare",value:store.money(store.db.outstanding))
                NavigationLink("Modifica budget e categorie") {SettingsView()}
            }
            Section("Categorie") {ForEach(Category.allCases) { c in let items = store.db.expenses.filter {$0.category == c}; let used = items.reduce(Int64(0)) {$0 + $1.committed}; let budget = store.db.settings.categoryBudgets[c.rawValue] ?? 0; if used > 0 || budget > 0 { VStack(alignment:.leading,spacing:6) {LabeledContent(c.rawValue,value:"\(store.money(used)) / \(store.money(budget))"); if budget > 0 {ProgressView(value:Double(min(used,budget)),total:Double(budget)).tint(used > budget ? .red : Palette.rose)}; if used > budget && budget > 0 {Text("Categoria oltre budget").font(.caption).foregroundStyle(.red)} } } }; if store.db.expenses.isEmpty && store.db.settings.categoryBudgets.isEmpty {Text("Imposta i budget per categoria da Impostazioni.").foregroundStyle(.secondary)} }
            Section("Registro spese") {
                if store.db.expenses.isEmpty {EmptyHint(title:"Ogni dettaglio ha il suo posto",text:"Aggiungi una spesa con +, quindi registra preventivo e pagamenti.",icon:"chart.pie")}
                ForEach(store.db.expenses.sorted {($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)}) { e in Button {edit = EditRequest(kind:.expense,objectID:e.id)} label:{VStack(alignment:.leading,spacing:6) {LabeledContent(e.title,value:store.money(e.committed)).font(.headline); Text("Pagato \(store.money(e.paid)) · Da versare \(store.money(e.balance))").font(.caption).foregroundStyle(.secondary); if let due = e.due {Text(due,format:.dateTime.day().month().year()).font(.caption).foregroundStyle(due < Date() && e.balance > 0 ? .red : .secondary)} }.foregroundStyle(.primary).padding(.vertical,5)} }
            }
            Section {Text("Il preventivo sostituisce la previsione nel totale impegnato. I costi indicativi dei fornitori non vengono sommati. I pagamenti superiori al costo sono segnalati nella spesa; il saldo non diventa negativo.").font(.caption).foregroundStyle(.secondary)}
        }.navigationTitle("Budget").toolbar {Button {edit = EditRequest(kind:.expense)} label:{Image(systemName:"plus").accessibilityLabel("Nuova spesa")}.accessibilityIdentifier("addExpense")}.sheet(item:$edit) {EntityEditor($0,archive:store.db)}
    }
}
struct CollectionView:View {
    @EnvironmentObject var store:WeddingStore; let kind:EntityKind
    @State private var edit:EditRequest?; @State private var search = ""
    var body:some View {
        List {
            if kind == .vendor {
                if store.db.vendors.isEmpty {EmptyHint(title:"Il vostro team",text:"Aggiungi location, fotografo, catering, musica e altri fornitori.",icon:"building.2")}
                ForEach(store.db.vendors.filter {search.isEmpty || [$0.name,$0.contact,$0.service,$0.notes,$0.category.rawValue,$0.status.rawValue].joined().localizedCaseInsensitiveContains(search)}) {v in Button {edit = EditRequest(kind:.vendor,objectID:v.id)} label:{VStack(alignment:.leading,spacing:6) {Text(v.name).font(.headline); Text("\(v.category.rawValue) · \(v.service)").font(.subheadline); Text("\(v.status.rawValue) · \(store.money(v.cost)) indicativi").font(.caption).foregroundStyle(.secondary); if let due = v.due { Text(due,format:.dateTime.day().month().year()).font(.caption) } }.foregroundStyle(.primary)} }
            } else {
                if store.db.notes.isEmpty {EmptyHint(title:"Spazio alle idee",text:"Crea note generali o collegate a invitati, fornitori e attività.",icon:"note.text")}
                ForEach(store.db.notes.filter {search.isEmpty || ($0.title + $0.text).localizedCaseInsensitiveContains(search)}) {n in Button {edit = EditRequest(kind:.note,objectID:n.id)} label:{VStack(alignment:.leading,spacing:6) {Text(n.title).font(.headline); Text(n.text).lineLimit(3).font(.subheadline).foregroundStyle(.secondary); Text(noteLink(n)).font(.caption).foregroundStyle(Palette.rose)}.foregroundStyle(.primary)} }
            }
        }.navigationTitle(kind == .vendor ? "Fornitori" : "Note e idee").searchable(text:$search).toolbar {Button {edit = EditRequest(kind:kind)} label:{Image(systemName:"plus").accessibilityLabel("Nuova voce")}.accessibilityIdentifier("addCollection")}.sheet(item:$edit) {EntityEditor($0,archive:store.db)}
    }
    private func noteLink(_ n:WeddingNote)->String {switch n.kind {case .general:return "Generale";case .guest:return "Invitato · " + (store.db.guests.first {$0.id == n.linkedID}?.name ?? "");case .vendor:return "Fornitore · " + (store.db.vendors.first {$0.id == n.linkedID}?.name ?? "");case .task:return "Attività · " + (store.db.tasks.first {$0.id == n.linkedID}?.title ?? "")}}
}
struct ScheduleView:View {
    @EnvironmentObject var store:WeddingStore; @State private var edit:EditRequest?; @State private var chronological = true
    private var entries:[ScheduleEntry] {chronological ? store.db.schedule.sorted {$0.start < $1.start} : store.db.schedule}
    var body:some View {
        List {
            Section {Toggle("Ordine cronologico",isOn:$chronological); if !chronological {Text("Tocca Modifica e trascina le righe per ordinare manualmente. Gli orari non cambiano.").font(.caption).foregroundStyle(.secondary)} }
            if entries.isEmpty {EmptyHint(title:"La trama del giorno",text:"Aggiungi cerimonia, ricevimento, appuntamenti e momenti da ricordare.",icon:"clock")}
            ForEach(entries) { s in Button {edit = EditRequest(kind:.schedule,objectID:s.id)} label:{ HStack(alignment:.top,spacing:16) {VStack {Text(s.start,format:.dateTime.hour().minute()).bold();Text("\(s.minutes) min").font(.caption)}.foregroundStyle(Palette.rose);VStack(alignment:.leading,spacing:6) {Text(s.title).font(.headline); Text(s.start,format:.dateTime.day().month()).font(.caption); Text(s.location).font(.subheadline); if !s.owner.isEmpty {Text(s.owner).font(.caption)}; if store.db.schedule.contains(where:{$0.id != s.id && $0.start < s.end && $0.end > s.start}) {Label("Orario sovrapposto",systemImage:"exclamationmark.triangle").font(.caption).foregroundStyle(.orange)} }.foregroundStyle(.primary) }.padding(.vertical,8)} }.onMove { source,dest in guard !chronological else {return}; _ = store.change {$0.schedule.move(fromOffsets:source,toOffset:dest)} }.moveDisabled(chronological)
        }.navigationTitle("Programma").toolbar {if !chronological {EditButton()}; Button {edit = EditRequest(kind:.schedule)} label:{Image(systemName:"plus").accessibilityLabel("Nuovo momento")}.accessibilityIdentifier("addSchedule")}.sheet(item:$edit) {EntityEditor($0,archive:store.db)}
    }
}
