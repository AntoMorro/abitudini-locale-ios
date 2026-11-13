import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

@MainActor final class WeddingStore: ObservableObject {
    @Published private(set) var db = WeddingArchive()
    @Published var error: String?
    @Published private(set) var readOnly = false
    private let repository: WeddingRepository
    lazy var sharing = SharingService(store:self)
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let path = base.appendingPathComponent(testing ? "PromessaUITests" : "Promessa")
        repository = WeddingRepository(directory: path)
        if testing { try? FileManager.default.removeItem(at: path) }
        do { db = try repository.read() } catch { readOnly = true; self.error = "Impossibile leggere l’archivio. Nessun dato verrà sovrascritto. Puoi esportare il file originale o ripristinare un backup da Impostazioni. \(error.localizedDescription)" }
    }
    @discardableResult func change(_ body: (inout WeddingArchive) throws -> Void) -> Bool {
        guard !readOnly else { error = "Archivio in sola lettura: ripristina un backup valido."; return false }
        do {
            db = try repository.update { archive in
                let before = archive
                try body(&archive)
                _ = try archive.validated()
                if var state = before.cloud {try state.capture(before:before,after:archive);archive.cloud = state}
            }
            refreshReminders();sharing.localChanged();return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func restore(_ data: Data) -> Bool {
        guard db.cloud == nil else {error = "Prima del ripristino esci dalla condivisione ed esporta un backup. Un ripristino non deve sovrascrivere i dati del tuo partner.";return false}
        do {var candidate = try WeddingRepository.decode(data);candidate.cloud = nil;db = try repository.restore(JSONEncoder().encode(candidate));readOnly = false;refreshReminders();return true} catch {self.error = "Backup non importato. \(error.localizedDescription)";return false}
    }
    func erase() -> Bool {
        guard db.cloud == nil else {error = "Esci prima dalla condivisione. Questa cancellazione riguarda solo i dati locali, non quelli del partner.";return false}
        guard !readOnly else { return false }
        do { db = try repository.erase(); refreshReminders(); return true } catch { self.error = error.localizedDescription; return false }
    }
    func backup() throws -> Data {
        if readOnly { return try Data(contentsOf: repository.file) }
        let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys];var exported = db;exported.cloud = nil;return try encoder.encode(exported)
    }
    func cloudUpdate(_ body:(inout WeddingArchive)throws->Void) throws {db = try repository.update(body);refreshReminders()}
    func clearSharedLocal() throws {db = try repository.erase();refreshReminders()}
    func connect(_ state:CloudState, uploadLocal:Bool) throws {
        guard !readOnly else {throw WeddingError.invalid("Ripristina prima l’archivio locale.")}
        // Save a portable backup before the first link. It never contains tokens or sync metadata.
        let backupData = try backup()
        try FileManager.default.createDirectory(at:repository.directory,withIntermediateDirectories:true)
        try backupData.write(to:repository.directory.appendingPathComponent("prima-condivisione.json"),options:[.atomic,.completeFileProtection])
        try cloudUpdate {archive in
            var newState = state
            if uploadLocal {let records = try CloudProjection.records(archive);newState.pending = records.values.sorted {$0.id < $1.id}.map {CloudMutation(key:$0.id,desired:$0,keys:Set($0.fields.keys))}}
            archive.cloud = newState
        }
    }
    func money(_ value: Int64) -> String { Money.format(value, currency: db.settings.currency) }
    func setReminders(_ enabled: Bool) {
        if !enabled { _ = change { $0.settings.reminders = false }; return }
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if allowed { _ = change { $0.settings.reminders = true } }
                else { error = "Notifiche non autorizzate. Puoi abilitarle nelle Impostazioni di iOS." }
            } catch { self.error = error.localizedDescription }
        }
    }
    func refreshReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard db.settings.reminders else { return }
        // iOS has a finite pending-notification limit: reserve the next 60 deadlines.
        let taskItems = db.tasks.filter { $0.status != .done }.compactMap { t -> (UUID, String, Date)? in t.due.map { (t.id, "Attività · " + t.title, $0) } }
        let bills = db.expenses.filter { $0.balance > 0 }.compactMap { e -> (UUID, String, Date)? in e.due.map { (e.id, "Pagamento · " + e.title, $0) } }
        for item in (taskItems + bills).filter({ $0.2 > Date() }).sorted(by: { $0.2 < $1.2 }).prefix(60) {
            let content = UNMutableNotificationContent(); content.title = "Promessa"; content.body = item.1; content.sound = .default
            let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from:item.2)
            center.add(UNNotificationRequest(identifier: item.0.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))) { _ in }
        }
    }
}
struct WeddingDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(_ data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
enum EntityKind: String, Identifiable, CaseIterable {
    case task = "Attività", guest = "Invitato", vendor = "Fornitore", expense = "Spesa", table = "Tavolo", schedule = "Programma", note = "Nota"
    var id: String { rawValue }
}
struct EditRequest: Identifiable { var kind: EntityKind; var objectID: UUID?; var id: String { kind.rawValue + (objectID?.uuidString ?? "new") } }
enum Palette {
    static let plum = Color(red:0.35,green:0.24,blue:0.39)
    static let rose = Color(red:0.73,green:0.43,blue:0.47)
}
struct Metric: View {
    let title: String; let value: String; let icon: String
    var body: some View { VStack(alignment:.leading, spacing:10) { Image(systemName:icon).font(.title2).foregroundStyle(Palette.rose); Text(value).font(.title2.bold()).minimumScaleFactor(0.6); Text(title).font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth:.infinity, alignment:.leading).padding().background(.background, in:RoundedRectangle(cornerRadius:20)).accessibilityElement(children:.combine) }
}
struct EmptyHint: View {
    let title: String; let text: String; var icon = "sparkles"
    var body: some View { ContentUnavailableView(title, systemImage:icon, description:Text(text)).listRowBackground(Color.clear) }
}
struct OptionalDateField: View {
    let title: String; @Binding var date: Date?
    var body: some View {
        Toggle(title, isOn: Binding(get:{ date != nil }, set:{ date = $0 ? Date() : nil }))
        if date != nil { DatePicker("Data e ora", selection:Binding(get:{ date ?? Date() }, set:{ date = $0 })) }
    }
}
struct AmountField: View {
    let title: String; @Binding var amount: Int64; let currency: String
    @State private var draft = ""; @State private var invalid = false
    var body: some View {
        HStack { Text(title); Spacer(); TextField(currency,text:$draft).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth:170).accessibilityLabel(title).onChange(of:draft) { _, value in
            if let parsed = try? Money.parse(value, currency:currency) { amount = parsed; invalid = false } else { invalid = true }
        } }
        .onAppear { draft = Money.input(amount, currency:currency) }
        .onChange(of:amount) { _, value in if (try? Money.parse(draft,currency:currency)) != value { draft = Money.input(value,currency:currency); invalid = false } }
        if invalid { Text("Importo non valido: il valore precedente resta salvato finché non inserisci un importo valido.").font(.caption).foregroundStyle(.red) }
    }
}
