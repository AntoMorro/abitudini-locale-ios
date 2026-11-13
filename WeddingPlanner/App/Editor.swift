import SwiftUI

struct EntityEditor: View {
    @EnvironmentObject var store: WeddingStore
    @Environment(\.dismiss) private var dismiss
    let request: EditRequest
    @State private var baseline:WeddingArchive
    @State private var task: WeddingTask
    @State private var guest: Guest
    @State private var vendor: Vendor
    @State private var expense: Expense
    @State private var table: WeddingTable
    @State private var entry: ScheduleEntry
    @State private var note: WeddingNote
    @State private var deleting = false
    @State private var paymentAmount: Int64 = 0
    @State private var paymentDate = Date()
    @State private var paymentNotes = ""
    @State private var pendingPaymentDelete: UUID?
    init(_ request: EditRequest, archive: WeddingArchive) {
        self.request = request
        _baseline = State(initialValue:archive)
        _task = State(initialValue:archive.tasks.first { $0.id == request.objectID } ?? WeddingTask())
        _guest = State(initialValue:archive.guests.first { $0.id == request.objectID } ?? Guest())
        _vendor = State(initialValue:archive.vendors.first { $0.id == request.objectID } ?? Vendor())
        _expense = State(initialValue:archive.expenses.first { $0.id == request.objectID } ?? Expense())
        _table = State(initialValue:archive.tables.first { $0.id == request.objectID } ?? WeddingTable())
        _entry = State(initialValue:archive.schedule.first { $0.id == request.objectID } ?? ScheduleEntry(start:archive.settings.date ?? Date()))
        _note = State(initialValue:archive.notes.first { $0.id == request.objectID } ?? WeddingNote())
    }
    private var currency: String { store.db.settings.currency }
    var body: some View {
        NavigationStack {
            Form {
                switch request.kind {
                case .task: taskForm
                case .guest: guestForm
                case .vendor: vendorForm
                case .expense: expenseForm
                case .table: tableForm
                case .schedule: scheduleForm
                case .note: noteForm
                }
                if request.objectID != nil { Section { Button("Elimina \(request.kind.rawValue.lowercased())",role:.destructive) { deleting = true }.accessibilityIdentifier("deleteEntity") } }
            }
            .navigationTitle(request.kind.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement:.confirmationAction) { Button("Salva", action:save).bold().accessibilityIdentifier("saveEntity") }
            }
            .confirmationDialog("Eliminare questa voce? I collegamenti verranno rimossi, le altre informazioni saranno conservate.",isPresented:$deleting,titleVisibility:.visible) { Button("Elimina",role:.destructive,action:delete) }
            .confirmationDialog("Rimuovere il pagamento dal registro?",isPresented:Binding(get:{ pendingPaymentDelete != nil },set:{ if !$0 { pendingPaymentDelete = nil } }),titleVisibility:.visible) { Button("Rimuovi pagamento",role:.destructive) { expense.payments.removeAll { $0.id == pendingPaymentDelete }; pendingPaymentDelete = nil } }
            .alert("Controlla i dati",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error = nil}})) { Button("OK") { store.error = nil } } message:{ Text(store.error ?? "") }
        }
    }
    private func category(_ value: Binding<Category>) -> some View { Picker("Categoria",selection:value) { ForEach(Category.allCases) { Text($0.rawValue).tag($0) } } }
    private func vendorPicker(_ value: Binding<UUID?>) -> some View { Picker("Fornitore collegato",selection:value) { Text("Nessuno").tag(nil as UUID?); ForEach(store.db.vendors) { Text($0.name).tag(Optional($0.id)) } } }
    private func text(_ label:String, _ value: Binding<String>) -> some View { TextField(label,text:value,axis:.vertical).lineLimit(3...8) }
    private var taskForm: some View {
        Group {
            Section("Attività") { TextField("Titolo",text:$task.title).accessibilityIdentifier("entityTitle"); category($task.category); Picker("Stato",selection:$task.status) { ForEach(TaskStatus.allCases) { Text($0.rawValue).tag($0) } }; Picker("Priorità",selection:$task.priority) { ForEach(Priority.allCases) { Text($0.rawValue).tag($0) } }; OptionalDateField(title:"Scadenza",date:$task.due) }
            Section("Dettagli") { TextField("Responsabile",text:$task.owner); vendorPicker($task.vendorID); text("Note / checklist della voce",$task.notes) }
        }
    }
    private var guestForm: some View {
        Group {
            Section("Invitato e nucleo") { TextField("Nome",text:$guest.name).accessibilityIdentifier("entityTitle"); TextField("Nucleo familiare / gruppo",text:$guest.group); Picker("RSVP",selection:$guest.rsvp) { ForEach(RSVP.allCases) { Text($0.rawValue).tag($0) } }; Stepper("Accompagnatori: \(guest.companions)",value:$guest.companions,in:0...100) }
            Section("Accoglienza") { TextField("Preferenza alimentare",text:$guest.diet); TextField("Allergie",text:$guest.allergies); Picker("Tavolo",selection:$guest.tableID) { Text("Non assegnato").tag(nil as UUID?); ForEach(store.db.tables) { Text("\($0.name) · \(store.db.seats($0.id))/\($0.capacity) posti").tag(Optional($0.id)) } }; Text("La voce occupa \(guest.seats) posti, accompagnatori inclusi. I non partecipanti non occupano posti. Ogni nucleo di questa voce siede insieme.").font(.caption).foregroundStyle(.secondary); text("Note",$guest.notes) }
        }
    }
    private var vendorForm: some View {
        Group {
            Section("Fornitore") { TextField("Nome",text:$vendor.name).accessibilityIdentifier("entityTitle"); category($vendor.category); TextField("Servizio (es. fotografo, fiori)",text:$vendor.service); TextField("Contatto",text:$vendor.contact); Picker("Stato",selection:$vendor.status) { ForEach(VendorStatus.allCases) { Text($0.rawValue).tag($0) } }; AmountField(title:"Costo indicativo",amount:$vendor.cost,currency:currency); OptionalDateField(title:"Prossima scadenza",date:$vendor.due) }
            Section("Note e contatto manuale") { text("Note",$vendor.notes); ShareLink(item:"Buongiorno \(vendor.name), vi contatto per \(store.db.settings.names). \(vendor.service)") { Label("Condividi testo da completare",systemImage:"square.and.arrow.up") }; Text("Il costo indicativo è informativo. Per conteggiarlo nel budget crea una spesa collegata, evitando duplicazioni.").font(.caption).foregroundStyle(.secondary) }
            if request.objectID != nil {
                Section("Collegamenti salvati") {
                    ForEach(store.db.tasks.filter { $0.vendorID == vendor.id }) { Text("Attività · \($0.title)") }
                    ForEach(store.db.expenses.filter { $0.vendorID == vendor.id }) { Text("Spesa · \($0.title) · \(store.money($0.balance)) da pagare") }
                    ForEach(store.db.schedule.filter { $0.vendorID == vendor.id }) { Text("Programma · \($0.title)") }
                }
            }
        }
    }
    private var expenseForm: some View {
        Group {
            Section("Spesa") { TextField("Titolo",text:$expense.title).accessibilityIdentifier("entityTitle"); category($expense.category); vendorPicker($expense.vendorID); AmountField(title:"Previsione",amount:$expense.planned,currency:currency); Toggle("Preventivo ricevuto",isOn:Binding(get:{expense.quote != nil},set:{expense.quote = $0 ? expense.planned : nil})); if expense.quote != nil { AmountField(title:"Preventivo",amount:Binding(get:{expense.quote ?? 0},set:{expense.quote = $0}),currency:currency) }; OptionalDateField(title:"Scadenza saldo",date:$expense.due); text("Note",$expense.notes) }
            Section("Registro dei pagamenti") {
                LabeledContent("Pagato",value:store.money(expense.paid)); LabeledContent("Saldo da versare",value:store.money(expense.balance))
                if expense.overpaid > 0 { Text("Pagamenti oltre il preventivo: \(store.money(expense.overpaid))").foregroundStyle(.orange) }
                ForEach(expense.payments) { p in HStack { VStack(alignment:.leading) { Text(store.money(p.amount)); Text(p.date,format:.dateTime.day().month().year()); if !p.notes.isEmpty { Text(p.notes).font(.caption) } }; Spacer(); Button(role:.destructive) { pendingPaymentDelete = p.id } label:{ Image(systemName:"trash").frame(minWidth:44,minHeight:44) }.accessibilityLabel("Rimuovi pagamento") } }
                AmountField(title:"Nuovo pagamento",amount:$paymentAmount,currency:currency)
                DatePicker("Data pagamento",selection:$paymentDate,displayedComponents:.date)
                TextField("Nota del pagamento",text:$paymentNotes)
                Button("Aggiungi al registro") { guard paymentAmount > 0 else { store.error = "Inserisci un importo positivo."; return }; expense.payments.append(Payment(amount:paymentAmount,date:paymentDate,notes:paymentNotes)); paymentAmount = 0; paymentNotes = "" }.accessibilityIdentifier("addPayment")
                Text("Le modifiche al registro vengono salvate con Salva. Nessun pagamento viene effettuato dall’app.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var tableForm: some View {
        Group {
            Section("Tavolo") { TextField("Nome",text:$table.name).accessibilityIdentifier("entityTitle"); Stepper("Capienza: \(table.capacity)",value:$table.capacity,in:1...1000); TextField("Categoria (es. famiglia)",text:$table.category); text("Note",$table.notes) }
            Section("Posizione nella sala") { Text("Orizzontale"); Slider(value:$table.x,in:0...1).accessibilityLabel("Posizione orizzontale"); Text("Verticale"); Slider(value:$table.y,in:0...1).accessibilityLabel("Posizione verticale"); Text("Puoi anche trascinare il tavolo sulla pianta. Eliminandolo, gli invitati restano salvati ma senza tavolo.").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private var scheduleForm: some View {
        Group {
            Section("Programma") { TextField("Titolo",text:$entry.title).accessibilityIdentifier("entityTitle"); DatePicker("Inizio",selection:$entry.start); Stepper("Durata: \(entry.minutes) minuti",value:$entry.minutes,in:1...1440,step:5); TextField("Luogo",text:$entry.location); TextField("Responsabile",text:$entry.owner); vendorPicker($entry.vendorID); text("Descrizione / note",$entry.notes) }
            Section { Text("Fine: \(entry.end.formatted(date:.abbreviated,time:.shortened))").foregroundStyle(.secondary) }
        }
    }
    private var noteForm: some View {
        Group {
            Section("Nota") { TextField("Titolo",text:$note.title).accessibilityIdentifier("entityTitle"); TextEditor(text:$note.text).frame(minHeight:180).accessibilityLabel("Testo della nota") }
            Section("Collega a una voce") { Picker("Tipo",selection:$note.kind) { ForEach(LinkKind.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.onChange(of:note.kind) { _, _ in note.linkedID = nil }; if note.kind != .general { Picker("Voce",selection:$note.linkedID) { Text("Seleziona").tag(nil as UUID?); switch note.kind { case .general: EmptyView(); case .guest: ForEach(store.db.guests) { Text($0.name).tag(Optional($0.id)) }; case .vendor: ForEach(store.db.vendors) { Text($0.name).tag(Optional($0.id)) }; case .task: ForEach(store.db.tasks) { Text($0.title).tag(Optional($0.id)) } } } } }
        }
    }
    private func upsert<T:Identifiable>(_ item:T, in list:inout [T]) { if let i = list.firstIndex(where:{$0.id == item.id}) { list[i] = item } else { list.append(item) } }
    private func save() {
        if paymentAmount > 0 && request.kind == .expense { store.error = "Premi prima Aggiungi al registro, oppure azzera Nuovo pagamento."; return }
        let ok = store.change { db in switch request.kind {
        case .task:try DraftMerge.upsert(task,original:baseline.tasks.first {$0.id == task.id},in:&db.tasks)
        case .guest:try DraftMerge.upsert(guest,original:baseline.guests.first {$0.id == guest.id},in:&db.guests)
        case .vendor:try DraftMerge.upsert(vendor,original:baseline.vendors.first {$0.id == vendor.id},in:&db.vendors)
        case .expense:try DraftMerge.upsert(expense,original:baseline.expenses.first {$0.id == expense.id},in:&db.expenses)
        case .table:try DraftMerge.upsert(table,original:baseline.tables.first {$0.id == table.id},in:&db.tables)
        case .schedule:try DraftMerge.upsert(entry,original:baseline.schedule.first {$0.id == entry.id},in:&db.schedule)
        case .note:try DraftMerge.upsert(note,original:baseline.notes.first {$0.id == note.id},in:&db.notes)
        } }
        if ok { dismiss() }
    }
    private func delete() {
        guard let id = request.objectID else { return }
        let ok = store.change { db in switch request.kind { case .task: db.deleteTask(id); case .guest: db.deleteGuest(id); case .vendor: db.deleteVendor(id); case .table: db.deleteTable(id); case .expense: db.expenses.removeAll { $0.id == id }; case .schedule: db.schedule.removeAll { $0.id == id }; case .note: db.notes.removeAll { $0.id == id } } }
        if ok { dismiss() }
    }
}
