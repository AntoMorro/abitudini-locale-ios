import SwiftUI
import UniformTypeIdentifiers

struct SettingsView:View {
    @EnvironmentObject var store:WeddingStore
    @State private var settings = WeddingSettings(); @State private var loaded = false
    @State private var baseline = WeddingSettings()
    @State private var document = WeddingDocument(Data()); @State private var exporting = false; @State private var exportType = UTType.json; @State private var exportName = "Promessa-backup"
    @State private var importing = false; @State private var pendingData:Data?; @State private var pendingSummary = ""
    @State private var restoring = false; @State private var deleting = false
    var body:some View {
        Form {
            Section("Il vostro giorno") {
                TextField("Nomi / titolo",text:$settings.names)
                OptionalDateField(title:"Data del matrimonio",date:$settings.date)
                TextField("Luogo",text:$settings.location)
            }
            Section("Budget") {
                Picker("Valuta",selection:Binding(get:{settings.currency},set:{new in
                    guard new != settings.currency else {return}
                    if store.db.settings.budget > 0 || !store.db.expenses.isEmpty || store.db.vendors.contains(where:{$0.cost > 0}) || store.db.settings.categoryBudgets.values.contains(where:{$0 > 0}) || settings.budget > 0 || settings.categoryBudgets.values.contains(where:{$0 > 0}) {store.error = "Per cambiare valuta l’archivio deve essere privo di importi. Non viene effettuata alcuna conversione. Esporta prima un backup."} else {settings.currency = new}
                })) {ForEach(["EUR","USD","GBP","CHF","CAD","AUD","JPY"],id:\.self) {Text($0)}}
                AmountField(title:"Budget totale",amount:$settings.budget,currency:settings.currency).id("total-" + settings.currency)
                ForEach(Category.allCases) {c in AmountField(title:c.rawValue,amount:Binding(get:{settings.categoryBudgets[c.rawValue] ?? 0},set:{settings.categoryBudgets[c.rawValue] = $0}),currency:settings.currency).id(c.rawValue + settings.currency)}
                let categories = settings.categoryBudgets.values.reduce(Int64(0),+)
                if categories > settings.budget {Text("I budget di categoria superano il budget totale di \(Money.format(categories-settings.budget,currency:settings.currency)).").font(.caption).foregroundStyle(.orange)}
                Button("Salva impostazioni",action:saveSettings).accessibilityIdentifier("saveSettings")
                Text("La valuta cambia solo l’unità del registro; non sono disponibili cambi o conversioni. Salva anche i cambiamenti a nomi, data e luogo con questo pulsante.").font(.caption).foregroundStyle(.secondary)
            }.disabled(store.readOnly)
            Section("Promemoria locali") {
                Toggle("Avvisa alle scadenze",isOn:Binding(get:{store.db.settings.reminders},set:{store.setReminders($0)})).disabled(store.readOnly)
                Text("Solo attività aperte e saldi non pagati; sono programmate le prossime 60 scadenze. Apri l’app periodicamente per aggiornare l’elenco. Contenuto visibile nelle notifiche secondo le impostazioni di iOS.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Dati e backup") {
                NavigationLink {SharingView()} label:{Label("Condividi con il partner",systemImage:"person.2")}
                Button {do {startExport(try store.backup(),type:.json,name:"Promessa-backup")} catch {store.error = error.localizedDescription}} label:{Label(store.readOnly ? "Esporta archivio originale" : "Esporta backup completo",systemImage:"square.and.arrow.up")}.accessibilityIdentifier("exportBackup")
                Button {importing = true} label:{Label("Importa backup",systemImage:"square.and.arrow.down")}
                Button {startExport(Data(("\u{FEFF}" + WeddingExport.guests(store.db)).utf8),type:.commaSeparatedText,name:"Promessa-invitati")} label:{Label("Esporta invitati CSV",systemImage:"person.2")}.disabled(store.readOnly)
                Button {startExport(Data(("\u{FEFF}" + WeddingExport.schedule(store.db)).utf8),type:.commaSeparatedText,name:"Promessa-programma")} label:{Label("Esporta programma CSV",systemImage:"clock")}.disabled(store.readOnly)
                Text("Archivio JSON privato sul telefono. Ogni salvataggio conserva la versione precedente. La condivisione Firebase, se attivata, sincronizza i dati con il partner; i backup esportati in File restano copie manuali. I file includono dati personali e allergie: conservali con cura.").font(.caption).foregroundStyle(.secondary)
                Button("Esporta backup prima della condivisione") {do {let base = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0];let data = try Data(contentsOf:base.appendingPathComponent("Promessa/prima-condivisione.json"));startExport(data,type:.json,name:"Promessa-prima-condivisione")} catch {store.error = "Nessun backup precedente alla condivisione disponibile."}}
                Button("Esporta versione precedente") {do {let base = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0];let data = try Data(contentsOf:base.appendingPathComponent("Promessa/promessa.previous.json"));startExport(data,type:.json,name:"Promessa-backup-precedente")} catch {store.error = "Nessuna versione precedente disponibile."}}
            }
            Section {Button("Elimina tutti i dati locali",role:.destructive) {deleting = true}.disabled(store.readOnly);Text("Promessa 1.1 · iOS 17 o successivo. Condivisione Firebase facoltativa; nessun analytics o servizio AI.").font(.caption).foregroundStyle(.secondary)}
        }.navigationTitle("Impostazioni").toolbar {ToolbarItem(placement:.topBarTrailing) {Button("Salva",action:saveSettings).bold().disabled(store.readOnly)}}.onAppear {if !loaded {settings = store.db.settings;baseline = settings;loaded = true}}
        .fileExporter(isPresented:$exporting,document:document,contentType:exportType,defaultFilename:exportName) {result in if case .failure(let e) = result {store.error = e.localizedDescription}}
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) {result in
            do {let url = try result.get();let granted = url.startAccessingSecurityScopedResource();defer {if granted {url.stopAccessingSecurityScopedResource()}};guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0) < 20_000_000 else {throw WeddingError.invalid("Backup troppo grande.")};let data = try Data(contentsOf:url);let archive = try WeddingRepository.decode(data);pendingData = data;pendingSummary = "\(archive.settings.names): \(archive.guests.count) invitati, \(archive.tasks.count) attività, \(archive.expenses.count) spese. L’archivio attuale sarà sostituito, non unito. Esporta prima un backup.";restoring = true} catch {store.error = "Importazione annullata: \(error.localizedDescription)"}
        }
        .alert("Sostituire l’archivio?",isPresented:$restoring) {Button("Annulla",role:.cancel) {pendingData = nil};Button("Sostituisci",role:.destructive) {if let data = pendingData,store.restore(data) {settings = store.db.settings};pendingData = nil}} message:{Text(pendingSummary)}
        .alert("Eliminare tutti i dati?",isPresented:$deleting) {Button("Annulla",role:.cancel) {};Button("Elimina tutto",role:.destructive) {if store.erase() {settings = store.db.settings}}} message:{Text("Invitati, attività, spese, fornitori, tavoli, programma, note e copia locale precedente verranno cancellati. Esporta prima un backup. I backup già esportati restano in File.")}
    }
    private func startExport(_ data:Data,type:UTType,name:String) {document = WeddingDocument(data);exportType = type;exportName = name;exporting = true}
    private func saveSettings() {let reminders = store.db.settings.reminders;if store.change({$0.settings = try DraftMerge.merge(baseline,edited:settings,current:$0.settings);$0.settings.reminders = reminders}) {settings = store.db.settings;baseline = settings}}
}
struct GlobalSearchView:View {
    @EnvironmentObject var store:WeddingStore; @State private var search = ""; @State private var edit:EditRequest?
    private struct Result:Identifiable {var kind:EntityKind;var objectID:UUID;var title:String;var body:String;var id:UUID {objectID}}
    private var results:[Result] {
        let db = store.db
        let tasks = db.tasks.map {Result(kind:.task,objectID:$0.id,title:$0.title,body:[$0.notes,$0.owner,$0.category.rawValue,$0.status.rawValue].joined(separator:" "))}
        let guests = db.guests.map {Result(kind:.guest,objectID:$0.id,title:$0.name,body:[$0.group,$0.notes,$0.diet,$0.allergies,$0.rsvp.rawValue].joined(separator:" "))}
        let vendors = db.vendors.map {Result(kind:.vendor,objectID:$0.id,title:$0.name,body:[$0.contact,$0.notes,$0.service,$0.category.rawValue].joined(separator:" "))}
        let expenses = db.expenses.map {Result(kind:.expense,objectID:$0.id,title:$0.title,body:$0.notes + " " + $0.category.rawValue)}
        let tables = db.tables.map {Result(kind:.table,objectID:$0.id,title:$0.name,body:$0.notes + " " + $0.category)}
        let schedule = db.schedule.map {Result(kind:.schedule,objectID:$0.id,title:$0.title,body:[$0.location,$0.notes,$0.owner].joined(separator:" "))}
        let notes = db.notes.map {Result(kind:.note,objectID:$0.id,title:$0.title,body:$0.text)}
        return (tasks + guests + vendors + expenses + tables + schedule + notes).filter {($0.title + " " + $0.body).localizedCaseInsensitiveContains(search)}
    }
    var body:some View {List {if search.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {EmptyHint(title:"Ritrova ogni dettaglio",text:"Cerca tra invitati, attività, fornitori, spese, programma, tavoli e note.",icon:"magnifyingglass")} else if results.isEmpty {EmptyHint(title:"Nessun risultato",text:"Prova un nome o una parola diversa.",icon:"magnifyingglass")} else {ForEach(results) {r in Button {edit = EditRequest(kind:r.kind,objectID:r.objectID)} label:{VStack(alignment:.leading,spacing:5) {Text(r.title).font(.headline);Text(r.kind.rawValue).font(.caption).foregroundStyle(Palette.rose);Text(r.body).lineLimit(2).font(.subheadline).foregroundStyle(.secondary)}.foregroundStyle(.primary)}}}}.navigationTitle("Cerca ovunque").searchable(text:$search).sheet(item:$edit) {EntityEditor($0,archive:store.db)}}
}
