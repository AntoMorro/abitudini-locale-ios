import SwiftUI
import Charts
import UniformTypeIdentifiers

struct JournalMore:View {
    @EnvironmentObject var store:HabitStore
    @State private var newBook=false
    @State private var habitsSettings=false
    @State private var habitsStats=false
    var body:some View {NavigationStack{List{
        Section("Il tuo quaderno"){NavigationLink("Modelli e raccolte"){JournalTemplates()};NavigationLink("Indice delle pagine"){JournalIndex()};Button("Nuovo quaderno"){newBook=true};NavigationLink("Revisioni e andamento"){JournalReview()};NavigationLink("In questo giorno"){JournalMemories()}}
        Section("Connessioni"){NavigationLink("Apple Watch e cattura rapida"){JournalWatchSetup()};NavigationLink("Importa da Promemoria"){JournalRemindersImport()}}
        Section("Personalizza e conserva"){NavigationLink("Preferenze, privacy ed esportazione"){JournalPreferencesView()};Button("Statistiche abitudini"){habitsStats=true};Button("Impostazioni e backup completo"){habitsSettings=true}}
    }.navigationTitle("Il tuo spazio").sheet(isPresented:$newBook){JournalBookEditor(book:JournalBook(title:""))}.sheet(isPresented:$habitsSettings){HabitSettings()}.sheet(isPresented:$habitsStats){TrackerOverview()}}}
}
struct JournalIndex:View {
    @EnvironmentObject var store:HabitStore
    var body:some View {List{ForEach(store.journal.pages.sorted{$0.number<$1.number}){p in NavigationLink{JournalPageDetail(id:p.id)}label:{HStack{Text("\(p.number)").monospacedDigit().foregroundStyle(.secondary).frame(width:40);VStack(alignment:.leading){Text(p.title);Text(store.journal.books.first{$0.id==p.notebookID}?.title ?? "").font(.caption).foregroundStyle(.secondary)}}}}}.navigationTitle("Indice")}
}
struct JournalMemories:View {
    @EnvironmentObject var store:HabitStore
    var body:some View {ScrollView{LazyVStack{ForEach(JournalEngine.onThisDay(store.journal)){JournalPageCard(page:$0)};if JournalEngine.onThisDay(store.journal).isEmpty{ContentUnavailableView("I ricordi prendono tempo",systemImage:"clock.arrow.circlepath",description:Text("Qui ritroverai le pagine dello stesso giorno negli anni precedenti."))}}.padding()}.navigationTitle("In questo giorno")}
}
struct JournalReview:View {
    @EnvironmentObject var store:HabitStore
    @State private var draft:JournalPage?
    var recent:[JournalPage]{store.journal.pages.filter{$0.date>=Date().addingTimeInterval(-30*86400) && $0.date<=Date()}}
    var mood:[JournalPage]{recent.filter{$0.mood != nil}.sorted{$0.date<$1.date}}
    var mean:Double{mood.isEmpty ? 0:Double(mood.compactMap(\.mood).reduce(0,+))/Double(mood.count)}
    var body:some View {ScrollView{VStack(alignment:.leading,spacing:22){
        Text("Fermati. Rileggi. Scegli.").font(.system(.title,design:.serif,weight:.semibold))
        HStack{metric("Pagine",value:"\(recent.count)");Spacer();metric("Giorni di scrittura",value:"\(Set(recent.map{JournalEngine.day($0.date)}).count)");Spacer();metric("Umore medio",value:mood.isEmpty ? "—":mean.formatted(.number.precision(.fractionLength(1))))}
        if !mood.isEmpty{Chart(mood){p in PointMark(x:.value("Data",p.date),y:.value("Umore",p.mood!)).foregroundStyle(.mint)}.chartYScale(domain:1...5).frame(height:170).accessibilityLabel("Umore registrato negli ultimi 30 giorni")}
        Text("Ultimi 30 giorni. Sono le tue registrazioni personali, non una valutazione medica o una relazione causale tra umore e abitudini.").font(.caption).foregroundStyle(.secondary)
        ForEach(["settimana","mese"],id:\.self){id in if let t=JournalTemplate.all.first(where:{$0.id==id}){Button(t.title){draft=JournalPage(title:t.title,body:t.body,template:t.id)}.buttonStyle(.bordered)}}
        Text("Attività aperte").font(.headline);Text("\(store.journal.bullets.filter{$0.kind == .task && $0.status == .open}.count) da rivedere. Usa Agenda → Rivedi attività precedenti per una migrazione consapevole.")
        Text("Abitudini e diario").font(.headline);Text("I check-in e il tracker sono nello stesso archivio. Una giornata senza registrazioni non viene trattata come completata.").foregroundStyle(.secondary)
    }.padding(20)}.navigationTitle("Rivedi il tuo percorso").sheet(item:$draft){JournalPageEditor(page:$0)}}
    func metric(_ label:String,value:String)->some View{VStack(alignment:.leading,spacing:7){Text(value).font(.title2.bold());Text(label).font(.caption).foregroundStyle(.secondary)}}
}
struct JournalPreferencesView:View {
    @EnvironmentObject var store:HabitStore
    @State private var exportURL:URL?
    @State private var preparing=false
    var prefs:JournalPreferences{store.journal.preferences}
    var body:some View {Form{
        Section("Il tuo spazio personale"){
            Toggle("Blocca il quaderno quando esci",isOn:Binding(get:{prefs.lock},set:{v in if store.journalChange({$0.preferences.lock=v}){JournalPrivacy.shared.update(enabled:v,active:true)}}))
            Text("Usa Face ID, Touch ID o il codice del dispositivo. Il blocco protegge l'accesso nell'app; i backup esportati sono file leggibili e vanno conservati in un luogo personale.").font(.caption)
            Picker("Aspetto",selection:Binding(get:{store.db.theme},set:{v in store.change{$0.theme=v}})){Text("Sistema").tag("system");Text("Chiaro").tag("light");Text("Scuro").tag("dark")}
        }
        Section("Un momento per scrivere"){
            Toggle("Promemoria del diario",isOn:Binding(get:{prefs.dailyReminderMinute != nil},set:{v in store.journalChange{$0.preferences.dailyReminderMinute=v ? 1230:nil};if v{Task{_ = try? await HabitReminders.authorize();store.syncReminders()}}}))
            if let m=prefs.dailyReminderMinute{DatePicker("Orario del diario",selection:Binding(get:{HabitFormat.date(m)},set:{date in store.journalChange{$0.preferences.dailyReminderMinute=HabitFormat.minute(date)}}),displayedComponents:.hourAndMinute)}
            Text("I promemoria delle abitudini hanno precedenza. L'app programma al massimo 60 avvisi complessivi; aprila per aggiornare quelli successivi.").font(.caption)
        }
        Section("Esporta il journal"){
            Button("Prepara PDF con pagine e immagini"){do{exportURL=try JournalExport.pdf(store.journal)}catch{store.problem=error.localizedDescription}}
            Button("Prepara testo Markdown"){do{let u=FileManager.default.temporaryDirectory.appendingPathComponent("Quaderno-\(UUID().uuidString).md");try JournalEngine.markdown(store.journal).write(to:u,atomically:true,encoding:.utf8);exportURL=u}catch{store.problem=error.localizedDescription}}
            if let url=exportURL{ShareLink(item:url){Label("Salva o condividi esportazione",systemImage:"square.and.arrow.up")}}
            Button("Prepara backup completo JSON"){do{let u=FileManager.default.temporaryDirectory.appendingPathComponent("Quaderno-completo-\(UUID().uuidString).json");try JSONEncoder().encode(store.db).write(to:u,options:.atomic);exportURL=u}catch{store.problem=error.localizedDescription}}
            Text("Il JSON comprende abitudini, storico, journal, foto, disegni e audio. Salvalo da Condividi → Salva su File, anche in iCloud Drive. Il PDF non contiene l'audio. Per ripristinare usa Altro → Impostazioni e backup completo. Limite dell'archivio: 90 MB.").font(.caption)
        }
        Section("Ispirazioni"){
            Text("Registro rapido e migrazione dal metodo Bullet Journal di Ryder Carroll; pagine e raccolte ispirate ai setup pubblici di AmandaRachLee; modelli, ricordi e check-in dalle funzioni pubbliche di Day One, Daylio e Diario di Apple. Layout e testi dei modelli sono originali.").font(.caption)
            Link("Metodo Bullet Journal",destination:URL(string:"https://bulletjournal.com/pages/migration")!)
            Text("Archivio locale, senza account del journal o analytics. Siri, dettatura, Promemoria e iCloud Drive sono servizi Apple separati, usati solo quando li scegli.").font(.caption)
        }
    }.navigationTitle("Preferenze quaderno")}
}
struct JournalWatchSetup:View {
    @EnvironmentObject var store:HabitStore
    @StateObject private var bridge=JournalPhoneBridge.shared
    var body:some View {ScrollView{VStack(alignment:.leading,spacing:20){
        Image(systemName:"applewatch").font(.system(size:48)).foregroundStyle(.mint)
        Text("Un pensiero, al polso.").font(.system(.title,design:.serif,weight:.semibold))
        Text("La companion permette di annotare con tastiera/dettatura, registrare l'umore e completare attività o abitudini a spunta. Le azioni restano in coda sul Watch finché l'iPhone conferma il salvataggio.")
        Toggle("Invia il riepilogo al mio Watch",isOn:Binding(get:{store.journal.preferences.watchEnabled},set:{v in store.journalChange{$0.preferences.watchEnabled=v};bridge.publish(store.db)}))
        Text(bridge.status).font(.caption).foregroundStyle(.secondary)
        Button("Aggiorna collegamento"){bridge.start(store);bridge.publish(store.db)}
        Text("Installazione della companion").font(.headline)
        Text("La build watchOS deve essere firmata e installata per il Watch abbinato. La compilazione non dimostra che Sideloadly su Windows possa installarla: questa procedura resta da verificare con i profili disponibili. Non serve acquistare una membership solo per provare il journal iPhone.")
        Text("Percorso utilizzabile con le app Apple").font(.headline)
        Text("Sul Watch chiedi a Siri di creare un promemoria, per esempio «Aggiungi leggere il capitolo alla lista Quaderno». Poi apri Altro → Importa da Promemoria su iPhone e scegli quella lista. La prima volta l'app chiede l'accesso ai promemoria. L'importazione crea attività nel journal senza modificare gli originali.")
        NavigationLink{JournalRemindersImport()}label:{Label("Apri importazione Promemoria",systemImage:"checklist")}
        Text("Tasto Azione Ultra").font(.headline)
        Text("Con la companion installata puoi assegnare un comando rapido di cattura al tasto Azione dalle impostazioni del Watch. Il widget/complicazione della companion apre l'annotazione: non mostra conteggi fittizi. In alternativa usa un comando Apple compatibile che crei un promemoria nella tua lista.")
        Text("La companion conserva un riepilogo limitato, non l'intero diario. Disattivando l'invio, il riepilogo viene svuotato alla successiva comunicazione con il Watch.").font(.caption).foregroundStyle(.secondary)
    }.padding(22)}.navigationTitle("Apple Watch")}
}
struct JournalRemindersImport:View {
    @EnvironmentObject var store:HabitStore
    @StateObject private var importer=JournalReminderImporter()
    @State private var selection=""
    @State private var busy=false
    @State private var result=""
    var body:some View {Form{
        Section("Cattura dal tuo Apple Watch"){Text("Crea i promemoria con Siri sul Watch, poi importa la lista che scegli. L'app non completa, modifica o elimina i promemoria originali.")}
        if !importer.ready{Button("Consenti accesso a Promemoria"){Task{await importer.authorize();selection=importer.calendars.first?.calendarIdentifier ?? ""}}}else{Picker("Lista da importare",selection:$selection){ForEach(importer.calendars,id:\.calendarIdentifier){Text($0.title).tag($0.calendarIdentifier)}};Button("Importa attività non completate"){busy=true;Task{let values=await importer.load(selection);let count=importer.importItems(values,store:store);result="\(count) nuove attività importate. Gli elementi già importati sono stati saltati.";busy=false}}.disabled(busy || selection.isEmpty)}
        if busy{ProgressView()};if let error=importer.error{Text(error).foregroundStyle(.red)};if !result.isEmpty{Text(result)}
    }.navigationTitle("Da Promemoria")}
}
