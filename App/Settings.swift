import SwiftUI
import UniformTypeIdentifiers
#if SCREEN_TIME
import FamilyControls
import DeviceActivity
#endif

struct ScreenTimeInsights: View {
    @EnvironmentObject var store: HabitStore
    @State private var week = false
    var body: some View {
        Section {
            #if SCREEN_TIME
            if AuthorizationCenter.shared.authorizationStatus == .approved {
                Toggle("Questa settimana", isOn: $week)
                let interval = Calendar.current.dateInterval(of: week ? .weekOfYear : .day, for: Date())!
                DeviceActivityReport(.init("abitudini.total"), filter: DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .all)).frame(height: 200)
                Text("Il report è elaborato nell’estensione protetta di iOS. I totali di utilizzo non vengono copiati nei backup o nei widget.").font(.caption).foregroundStyle(.secondary)
            } else { Button("Autorizza Tempo di utilizzo") { Task { await store.authorize() } }; Text("Serve la versione con Family Controls e un profilo Apple Developer Program valido.").font(.caption).foregroundStyle(.secondary) }
            #else
            Label("Report disponibile nella configurazione Screen Time", systemImage: "hourglass")
            Text("Questo pacchetto non legge Tempo di utilizzo e non blocca altre app. Usa il pacchetto completo con i profili di firma appropriati.").font(.caption).foregroundStyle(.secondary)
            #endif
        }
    }
}
struct HabitSettings: View {
    @EnvironmentObject var store: HabitStore
    @State private var exporting = false
    @State private var importing = false
    @State private var backup = HabitBackupDocument(data: Data())
    @State private var pending: Data?
    @State private var restore = false
    @State private var emergency = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Tempo di utilizzo") {
                    Text(store.protectionStatus).font(.subheadline)
                    Button("Autorizza Tempo di utilizzo") { Task { await store.authorize() } }
                    Text("L’autorizzazione è individuale e rimane revocabile dalle impostazioni di iOS. La membership Apple Developer Program serve alla firma della configurazione completa.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Salute") {
                    #if HEALTH
                    Button("Richiedi accesso a Salute") { Task { await store.connectHealth() } }
                    Button("Aggiorna passi, allenamenti e meditazione") { Task { await store.refreshHealth() } }
                    Text("Aggiornamento quando apri l’app o premi Aggiorna. Un valore zero può significare attività assente o lettura non concessa: Apple non comunica la differenza.").font(.caption).foregroundStyle(.secondary)
                    #else
                    Text("Disponibile nei pacchetti Widget e Screen Time con HealthKit correttamente firmato.").font(.caption).foregroundStyle(.secondary)
                    #endif
                }
                Section("Widget e schermata di blocco") {
                    LabeledContent("Archivio condiviso", value: store.shared ? "Disponibile" : "Non attivo in questo profilo")
                    Text("Installa il pacchetto con widget, poi tieni premuta la schermata Home e aggiungi Abitudini Locale. I widget mostrano le prime abitudini attive. Le Live Activity richiedono anche il consenso nelle impostazioni iOS.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Aspetto") { Picker("Tema", selection: Binding(get: { store.db.theme }, set: { theme in store.change { $0.theme = theme } })) { Text("Scuro").tag("dark"); Text("Chiaro").tag("light"); Text("Come iPhone").tag("system") } }
                Section("Archivio e iCloud Drive") {
                    Button("Esporta backup in File") { do { backup = HabitBackupDocument(data: try JSONEncoder().encode(store.db)); exporting = true } catch { store.problem = error.localizedDescription } }
                    Button("Ripristina backup") { importing = true }
                    Text("Scegli iCloud Drive nel pannello File per conservare una copia. Il backup è manuale. Dopo un ripristino le regole sono disattivate e le app vanno selezionate di nuovo prima di riattivarle.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Emergenza") {
                    Button("Sospendi tutti i blocchi per un’ora · \(store.db.emergencyUses) rimaste", role: .destructive) { emergency = true }.disabled(store.db.emergencyUses == 0)
                    Text("Le emergenze sono limitate nell’archivio locale. I blocchi non sono una protezione contro la manomissione del telefono, del suo orologio o delle autorizzazioni di iOS.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Comandi Rapidi") { Text("Puoi aggiungere quantità, impostare il totale giornaliero e avviare o fermare timer. Le azioni sono disponibili anche per l’Action Button attraverso Comandi Rapidi. Per sorgenti esterne, le credenziali e le automazioni restano sotto il tuo controllo.").font(.caption) }
                Section("Versione e copertura") {
                    Text("Abitudini Locale 1.0 · app nativa indipendente, ispirata al flusso di Habits First di Eric Su. Non affiliata all’originale.").font(.caption)
                    Text("Non sono inclusi account/sync cloud, blocchi per posizione o Bluetooth, NFC, integrazioni dirette AnkiWeb, Duolingo, KOReader, Chess.com e servizi multimediali. Il timer di studio non include cicli automatici pausa/lavoro. Le funzioni disponibili dipendono dal pacchetto e dai profili di firma.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("impostazioni")
            .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "AbitudiniLocale-backup") { result in if case .failure(let e) = result { store.problem = e.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(), access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 100_000_000 else { throw HabitError.invalid }
                    let data = try Data(contentsOf: url); _ = try JSONDecoder().decode(HabitDatabase.self, from: data).validated(); pending = data; restore = true
                } catch { store.problem = error.localizedDescription }
            }
            .alert("Sostituire l’archivio?", isPresented: $restore) { Button("Annulla", role: .cancel) { pending = nil }; Button("Ripristina", role: .destructive) { if let data = pending { store.restore(data) }; pending = nil } } message: { Text("I dati correnti saranno sostituiti. Le regole ripristinate partiranno disattivate.") }
            .alert("Usare un’emergenza?", isPresented: $emergency) { Button("Annulla", role: .cancel) {}; Button("Sospendi per un’ora", role: .destructive) { store.emergency() } } message: { Text("Consumerai una delle emergenze rimaste nell’archivio locale.") }
        }
    }
}
