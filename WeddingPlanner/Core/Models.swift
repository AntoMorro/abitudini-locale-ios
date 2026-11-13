import Foundation

enum WeddingError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let reason): return reason } }
}
enum Category: String, CaseIterable, Codable, Identifiable {
    case ceremony = "Cerimonia", reception = "Ricevimento", clothes = "Abiti", documents = "Documenti", guests = "Invitati", vendors = "Fornitori", decor = "Decorazioni", travel = "Viaggio", other = "Altro"
    var id: String { rawValue }
}
enum RSVP: String, CaseIterable, Codable, Identifiable {
    case pending = "In attesa", confirmed = "Confermato", declined = "Non partecipa"
    var id: String { rawValue }
}
enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case open = "Da fare", progress = "In corso", done = "Completata"
    var id: String { rawValue }
}
enum Priority: String, CaseIterable, Codable, Identifiable {
    case low = "Bassa", normal = "Normale", high = "Alta"
    var id: String { rawValue }
    var rank: Int { switch self { case .low: return 0; case .normal: return 1; case .high: return 2 } }
}
enum VendorStatus: String, CaseIterable, Codable, Identifiable {
    case research = "Da contattare", contacted = "Contattato", quote = "Preventivo ricevuto", booked = "Confermato", excluded = "Escluso"
    var id: String { rawValue }
}
struct WeddingSettings: Codable, Equatable {
    var names = "Il nostro matrimonio"
    var date: Date?
    var location = ""
    var currency = "EUR"
    var budget: Int64 = 0
    var categoryBudgets: [String: Int64] = [:]
    var reminders = false
}
struct WeddingTask: Codable, Identifiable, Equatable {
    var id = UUID(); var title = ""; var category = Category.other
    var due: Date?; var priority = Priority.normal; var status = TaskStatus.open
    var notes = ""; var owner = ""; var vendorID: UUID?
}
struct Vendor: Codable, Identifiable, Equatable {
    var id = UUID(); var name = ""; var category = Category.vendors
    var contact = ""; var service = ""; var cost: Int64 = 0
    var status = VendorStatus.research; var due: Date?; var notes = ""
}
struct Payment: Codable, Identifiable, Equatable {
    var id = UUID(); var amount: Int64 = 0; var date = Date(); var notes = ""
}
struct Expense: Codable, Identifiable, Equatable {
    var id = UUID(); var title = ""; var category = Category.other
    var planned: Int64 = 0; var quote: Int64?; var payments: [Payment] = []
    var due: Date?; var vendorID: UUID?; var notes = ""
    var paid: Int64 { payments.reduce(0) { $0 + $1.amount } }
    var committed: Int64 { quote ?? planned }
    var balance: Int64 { max(0, committed - paid) }
    var overpaid: Int64 { max(0, paid - committed) }
    var allocated: Int64 { max(committed, paid) }
}
struct Guest: Codable, Identifiable, Equatable {
    var id = UUID(); var name = ""; var group = ""; var rsvp = RSVP.pending
    var companions = 0; var diet = ""; var allergies = ""; var notes = ""; var tableID: UUID?
    var seats: Int { rsvp == .declined ? 0 : 1 + companions }
}
struct WeddingTable: Codable, Identifiable, Equatable {
    var id = UUID(); var name = ""; var capacity = 8
    var x = 0.5; var y = 0.5; var category = ""; var notes = ""
}
struct ScheduleEntry: Codable, Identifiable, Equatable {
    var id = UUID(); var title = ""; var start = Date(); var minutes = 30
    var location = ""; var notes = ""; var owner = ""; var vendorID: UUID?
    var end: Date { start.addingTimeInterval(Double(minutes) * 60) }
}
enum LinkKind: String, Codable, CaseIterable { case general = "Generale", guest = "Invitato", vendor = "Fornitore", task = "Attività" }
struct WeddingNote: Codable, Identifiable, Equatable {
    var id = UUID(); var title = ""; var text = ""; var kind = LinkKind.general; var linkedID: UUID?
}
struct WeddingArchive: Codable, Equatable {
    var schema = 1; var settings = WeddingSettings()
    var tasks: [WeddingTask] = []; var vendors: [Vendor] = []; var expenses: [Expense] = []
    var guests: [Guest] = []; var tables: [WeddingTable] = []; var schedule: [ScheduleEntry] = []; var notes: [WeddingNote] = []
    var planned: Int64 { expenses.reduce(0) { $0 + $1.planned } }
    var committed: Int64 { expenses.reduce(0) { $0 + $1.committed } }
    var paid: Int64 { expenses.reduce(0) { $0 + $1.paid } }
    var outstanding: Int64 { expenses.reduce(0) { $0 + $1.balance } }
    var allocated: Int64 { expenses.reduce(0) { $0 + $1.allocated } }
    var available: Int64 { settings.budget - allocated }
    var totalSeats: Int { guests.reduce(0) { $0 + $1.seats } }
    var unassigned: [Guest] { guests.filter { $0.seats > 0 && $0.tableID == nil } }
    var completed: Int { tasks.filter { $0.status == .done }.count }
    func seats(_ id: UUID) -> Int { guests.filter { $0.tableID == id }.reduce(0) { $0 + $1.seats } }
    func freeSeats(_ id: UUID) -> Int { max(0, (tables.first { $0.id == id }?.capacity ?? 0) - seats(id)) }
    func people(_ rsvp: RSVP) -> Int { guests.filter { $0.rsvp == rsvp }.reduce(0) { $0 + 1 + $1.companions } }
    func overdue(at now: Date) -> [WeddingTask] { tasks.filter { $0.status != .done && ($0.due.map { $0 < now } ?? false) }.sorted { $0.due! < $1.due! } }
    func countdown(now: Date, calendar: Calendar = .current) -> Int? { settings.date.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: $0)).day ?? 0 } }
    mutating func deleteTable(_ id: UUID) { tables.removeAll { $0.id == id }; for i in guests.indices where guests[i].tableID == id { guests[i].tableID = nil } }
    mutating func deleteVendor(_ id: UUID) { vendors.removeAll { $0.id == id }; for i in tasks.indices where tasks[i].vendorID == id { tasks[i].vendorID = nil }; for i in expenses.indices where expenses[i].vendorID == id { expenses[i].vendorID = nil }; for i in schedule.indices where schedule[i].vendorID == id { schedule[i].vendorID = nil }; clearLinks(.vendor, id) }
    mutating func deleteGuest(_ id: UUID) { guests.removeAll { $0.id == id }; clearLinks(.guest, id) }
    mutating func deleteTask(_ id: UUID) { tasks.removeAll { $0.id == id }; clearLinks(.task, id) }
    private mutating func clearLinks(_ kind: LinkKind, _ id: UUID) { for i in notes.indices where notes[i].kind == kind && notes[i].linkedID == id { notes[i].kind = .general; notes[i].linkedID = nil } }
    mutating func assign(_ guest: UUID, to table: UUID?) throws {
        guard let i = guests.firstIndex(where: { $0.id == guest }), table == nil || tables.contains(where: { $0.id == table }) else { throw WeddingError.invalid("Invitato o tavolo inesistente.") }
        guests[i].tableID = table
    }
    func validated() throws -> WeddingArchive {
        func require(_ condition: Bool, _ reason: String) throws { if !condition { throw WeddingError.invalid(reason) } }
        let limit: Int64 = 1_000_000_000_000
        func money(_ value: Int64) -> Bool { (0...limit).contains(value) }
        func text(_ value: String) -> Bool { value.count <= 100_000 }
        func title(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 500 }
        func date(_ value: Date?) -> Bool { value.map { $0.timeIntervalSince1970.isFinite && abs($0.timeIntervalSince1970) < 32_000_000_000 } ?? true }
        var ids: [UUID] = tasks.map(\.id)
        ids.append(contentsOf:vendors.map(\.id))
        ids.append(contentsOf:expenses.map(\.id))
        ids.append(contentsOf:guests.map(\.id))
        ids.append(contentsOf:tables.map(\.id))
        ids.append(contentsOf:schedule.map(\.id))
        ids.append(contentsOf:notes.map(\.id))
        for expense in expenses { ids.append(contentsOf:expense.payments.map(\.id)) }
        try require(schema == 1, "Versione del backup non supportata.")
        try require(ids.count <= 50_000 && Set(ids).count == ids.count, "Archivio troppo grande o identificativi duplicati.")
        try require(title(settings.names) && text(settings.location) && date(settings.date) && ["EUR", "USD", "GBP", "CHF", "CAD", "AUD", "JPY"].contains(settings.currency) && money(settings.budget) && settings.categoryBudgets.allSatisfy { Category(rawValue: $0.key) != nil && money($0.value) }, "Impostazioni o budget non validi.")
        let vendorIDs = Set(vendors.map(\.id)), tableIDs = Set(tables.map(\.id))
        func vendor(_ id: UUID?) -> Bool { id.map { vendorIDs.contains($0) } ?? true }
        for t in tasks { try require(title(t.title) && text(t.owner) && text(t.notes) && date(t.due) && vendor(t.vendorID), "Attività non valida o collegamento mancante.") }
        for v in vendors { try require(title(v.name) && text(v.contact) && text(v.service) && text(v.notes) && money(v.cost) && date(v.due), "Fornitore non valido.") }
        for e in expenses { try require(title(e.title) && money(e.planned) && (e.quote.map(money) ?? true) && date(e.due) && text(e.notes) && vendor(e.vendorID), "Spesa non valida."); for p in e.payments { try require(p.amount > 0 && money(p.amount) && date(p.date) && text(p.notes), "Pagamento non valido.") } }
        for g in guests { try require(title(g.name) && (0...100).contains(g.companions) && [g.group,g.diet,g.allergies,g.notes].allSatisfy(text) && (g.tableID.map { tableIDs.contains($0) } ?? true), "Invitato non valido o tavolo mancante.") }
        for t in tables { try require(title(t.name) && (1...1000).contains(t.capacity) && t.x.isFinite && t.y.isFinite && (0...1).contains(t.x) && (0...1).contains(t.y) && text(t.category) && text(t.notes), "Tavolo non valido.") }
        for s in schedule { try require(title(s.title) && date(s.start) && (1...1440).contains(s.minutes) && [s.location,s.notes,s.owner].allSatisfy(text) && vendor(s.vendorID), "Voce del programma non valida.") }
        for n in notes { let linked: Bool; switch n.kind { case .general: linked = n.linkedID == nil; case .guest: linked = guests.contains { $0.id == n.linkedID }; case .vendor: linked = vendors.contains { $0.id == n.linkedID }; case .task: linked = tasks.contains { $0.id == n.linkedID } }; try require(title(n.title) && text(n.text) && linked, "Nota o collegamento non valido.") }
        return self
    }
}
