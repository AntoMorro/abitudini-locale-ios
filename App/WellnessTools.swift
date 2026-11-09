import SwiftUI
import UniformTypeIdentifiers

struct WellnessImportView:View {
    @EnvironmentObject var store:HabitStore
    @State private var json=""
    @State private var preview:[WellnessRecord]=[]
    @State private var message=""
    @State private var file=false
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){
        Text("Ricevi i tuoi campioni").font(.title2.bold())
        Text("Le azioni Comandi Rapidi salvano direttamente i campioni nell’archivio locale. Per un file o un testo JSON puoi controllare l’anteprima prima di confermare.")
        NavigationLink("Configura HRV, riposo e sonno"){WellnessShortcutsGuide()}
        Button("Scegli file JSON",systemImage:"doc"){file=true}
        TextEditor(text:$json).autocorrectionDisabled().textInputAutocapitalization(.never).frame(height:180).padding(8).background(.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:12)).accessibilityIdentifier("wellnessJSON")
        Button("Controlla importazione"){inspect()}.buttonStyle(.bordered).accessibilityIdentifier("wellnessPreview")
        if !preview.isEmpty{Text("\(preview.count) campioni validi").font(.headline);ForEach(WellnessMetric.allCases){m in let count=preview.filter{$0.metric==m}.count;if count>0{Text("\(m.title): \(count)")}};Button("Conferma importazione"){var result=(added:0,updated:0);if store.wellnessChange({a in result=try a.merge(preview)}){message="Importati \(result.added), aggiornati \(result.updated).";preview=[];json=""}}.buttonStyle(.borderedProminent)}
        if !message.isEmpty{Text(message).textSelection(.enabled)}
        Text("Formato versione 1. Date ISO 8601 con fuso orario. Le ripetizioni aggiornano il campione senza moltiplicarlo. L’intero lotto viene verificato prima di salvare.").font(.caption)
        Text(Self.example).font(.caption.monospaced()).textSelection(.enabled)
    }.padding()}.navigationTitle("Importa Salute").onChange(of:json){_,_ in preview=[]}.fileImporter(isPresented:$file,allowedContentTypes:[.json]){result in do{let u=try result.get();let access=u.startAccessingSecurityScopedResource();defer{if access{u.stopAccessingSecurityScopedResource()}};guard (try u.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=5_000_000 else{throw WellnessError.invalid("Massimo 5 MB per file.")};json=try String(contentsOf:u,encoding:.utf8);message="File caricato. Tocca Controlla importazione."}catch{message=error.localizedDescription;preview=[]}}}
    func inspect(){do{preview=try WellnessImport.decode(Data(json.utf8));message="Anteprima pronta. Non ancora salvata."}catch{preview=[];message=error.localizedDescription}}
    static let example="""
    {"version":1,"records":[
      {"type":"hrv","value":42,"unit":"ms",
       "start":"2026-01-01T07:00:00+01:00",
       "source":"Apple Watch"}
    ]}
    """
}
struct WellnessManual:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) var dismiss
    @State private var metric:WellnessMetric = .hrv
    @State private var number=""
    @State private var start=Date().addingTimeInterval(-3600)
    @State private var end=Date()
    @State private var source="Manuale"
    @State private var phase:WellnessPhase = .asleep
    @State private var name=""
    @State private var rpe=5.0
    @State private var error=""
    var originalID:UUID?
    init(record:WellnessRecord? = nil){
        originalID=record?.id
        if let r=record{_metric=State(initialValue:r.metric);_number=State(initialValue:String(r.value));_start=State(initialValue:r.start);_end=State(initialValue:r.end);_source=State(initialValue:r.source);_phase=State(initialValue:r.phase ?? .asleep);_name=State(initialValue:r.name);_rpe=State(initialValue:r.rpe ?? 5)}
    }
    var body:some View{NavigationStack{Form{Section("Campione"){
        Picker("Tipo",selection:$metric){ForEach(WellnessMetric.allCases){Text($0.title).tag($0)}}
        DatePicker("Inizio misurazione",selection:$start,in:...Date())
        if [.sleep,.workout].contains(metric){DatePicker("Fine",selection:$end,in:...Date())}else{TextField("Valore in "+metric.unit,text:$number).keyboardType(.decimalPad).accessibilityIdentifier("wellnessManualValue")}
        TextField("Fonte",text:$source)
        if metric == .sleep{Picker("Fase",selection:$phase){ForEach(WellnessPhase.allCases){Text($0.title).tag($0)}}}
        if metric == .workout{TextField("Nome attività",text:$name);Slider(value:$rpe,in:0...10,step:1);Text("Sforzo percepito RPE: \(Int(rpe))/10")}
    };if !error.isEmpty{Text(error).foregroundStyle(.red)};Text("Usa ‘Manuale’ per inserimenti personali. Non attribuire al Watch dati stimati o ricordati.").font(.caption)}.navigationTitle("Aggiungi campione").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Salva campione"){save()}}}}}
    func save(){do{let value:Double
        if [.sleep,.workout].contains(metric){value=end.timeIntervalSince(start)/60}else{guard let v=Double(number.replacingOccurrences(of:",",with:".")) else{throw WellnessError.invalid("Inserisci un numero.")};value=v}
        let r=WellnessRecord(metric:metric,value:value,start:start,end:[.sleep,.workout].contains(metric) ? end:start,source:source,phase:metric == .sleep ? phase:nil,name:name,rpe:metric == .workout ? rpe:nil)
        try r.validate();if store.wellnessChange({a in if let id=originalID{a.records.removeAll{$0.id==id}};try a.merge([r])}){dismiss()}
    }catch{self.error=error.localizedDescription}}
}
struct WellnessSettings:View {
    @EnvironmentObject var store:HabitStore
    var body:some View{Form{
        Section("Sonno"){Stepper(value:Binding(get:{store.wellness.preferences.sleepGoal},set:{v in store.wellnessChange{$0.preferences.sleepGoal=v}}),in:4...12,step:0.25){Text("Obiettivo personale: \(store.wellness.preferences.sleepGoal.formatted()) ore")};sourcePicker(.sleep);Text("L’obiettivo è scelto da te. Non è calcolato dal carico e non è una raccomandazione medica.").font(.caption)}
        Section("Coerenza della baseline"){sourcePicker(.hrv);sourcePicker(.rhr);Toggle("Usa solo HRV misurata durante il sonno importato",isOn:Binding(get:{store.wellness.preferences.nocturnalHRV},set:{v in store.wellnessChange{$0.preferences.nocturnalHRV=v}}));Text("Con l’opzione notturna servono segmenti sonno. Il giorno HRV segue la notte che termina a mezzogiorno; non vengono usati campioni fuori dai segmenti addormentati.").font(.caption)}
        Section("Apri i tuoi comandi"){ForEach(0..<3,id:\.self){i in TextField(["Nome comando HRV","Nome comando riposo","Nome comando sonno"][i],text:Binding(get:{store.wellness.preferences.shortcutNames[i]},set:{v in store.wellnessChange{$0.preferences.shortcutNames[i]=v}}))};Text("Aggiungi una volta i comandi firmati, poi inserisci qui i loro nomi esatti. I pulsanti nell’app li eseguiranno su tua richiesta.").font(.caption)}
    }.navigationTitle("Preferenze Salute")}
    func sourcePicker(_ m:WellnessMetric)->some View{let values=Array(Set(store.wellness.records.filter{$0.metric==m}.map(\.source))).sorted()
        let binding=Binding<String>(get:{switch m{case .hrv:return store.wellness.preferences.hrvSource;case .rhr:return store.wellness.preferences.rhrSource;default:return store.wellness.preferences.sleepSource}},set:{v in store.wellnessChange{a in switch m{case .hrv:a.preferences.hrvSource=v;case .rhr:a.preferences.rhrSource=v;default:a.preferences.sleepSource=v}}})
        return Picker(m.title+" · fonte",selection:binding){Text(m == .sleep ? "Automatica, una per notte":"Tutte (indice sospeso se miste)").tag("");ForEach(values,id:\.self){Text($0).tag($0)}}
    }
}
struct WellnessRecordsView:View {
    @EnvironmentObject var store:HabitStore
    @State private var metric:WellnessMetric = .hrv
    @State private var export:URL?
    @State private var deleting:WellnessRecord?
    @State private var confirm=false
    @State private var clearing=false
    @State private var editing:WellnessRecord?
    var body:some View{List{
        Section{Picker("Tipo",selection:$metric){ForEach(WellnessMetric.allCases){Text($0.title).tag($0)}};Text("\(store.wellness.records.count) campioni totali. Mostrati gli ultimi 200 del tipo selezionato.").font(.caption)}
        ForEach(Array(store.wellness.records.filter{$0.metric==metric}.sorted{$0.start>$1.start}.prefix(200))){r in VStack(alignment:.leading,spacing:6){Text(r.metric.title+" · "+WellnessFormat.number(r.value)+" "+r.metric.unit).font(.headline);Text(r.start.formatted(date:.abbreviated,time:.shortened)+" · "+r.source).font(.caption);if let phase=r.phase{Text(phase.title).font(.caption)};if r.metric == .workout{Text(r.name+" · RPE "+WellnessFormat.number(r.rpe)).font(.caption)};Button("Modifica campione"){editing=r};Button("Elimina campione",role:.destructive){deleting=r;confirm=true}}}
        Section("I tuoi dati"){Button("Prepara esportazione Salute JSON"){do{let u=FileManager.default.temporaryDirectory.appendingPathComponent("Salute-\(UUID().uuidString).json");try WellnessImport.export(store.wellness).write(to:u,options:.atomic);export=u}catch{store.problem=error.localizedDescription}};if let u=export{ShareLink(item:u){Label("Salva o condividi JSON Salute",systemImage:"square.and.arrow.up")}};Text("Il JSON contiene dati sanitari leggibili. Condividerlo o salvarlo in iCloud Drive è una scelta tua. Il backup completo del quaderno include anche le preferenze e i giorni di allenamento confermati.").font(.caption);Button("Elimina tutti i dati Salute",role:.destructive){clearing=true}}
    }.navigationTitle("Archivio Salute").sheet(item:$editing){WellnessManual(record:$0)}.alert("Eliminare questo campione?",isPresented:$confirm){Button("Annulla",role:.cancel){};Button("Elimina",role:.destructive){if let id=deleting?.id{store.wellnessChange{$0.records.removeAll{$0.id==id}}};deleting=nil}}.alert("Eliminare l’archivio Salute?",isPresented:$clearing){Button("Annulla",role:.cancel){};Button("Elimina Salute",role:.destructive){store.wellnessChange{$0=WellnessArchive()}}}message:{Text("Rimuove campioni, preferenze Salute e conferme degli allenamenti dal quaderno. Non modifica Salute di Apple o le pagine del diario; copie precedenti restano negli eventuali backup già esportati.")}}
}
struct WellnessShortcutsGuide:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.openURL) var openURL
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        Image(systemName:"arrow.triangle.2.circlepath").font(.system(size:36)).foregroundStyle(WellnessStyle.hrv)
        Text("Un tocco. Tre importazioni.").font(.system(size:30,weight:.bold,design:.rounded))
        Text("Comandi Rapidi legge Salute con il tuo consenso. Il quaderno conserva i campioni sul tuo iPhone.").foregroundStyle(.secondary)
        Button{run("Aggiorna Salute Quaderno")}label:{Label("Aggiorna tutti i dati",systemImage:"arrow.clockwise").frame(maxWidth:.infinity)}.buttonStyle(.borderedProminent).tint(WellnessStyle.hrv)
        VStack(alignment:.leading,spacing:16){Text("Oppure scegli una misura").font(.headline)
            ForEach(0..<3,id:\.self){i in Button{run(store.wellness.preferences.shortcutNames[i])}label:{HStack{Label(["HRV · ultimi 28 giorni","Riposo · ultimi 28 giorni","Sonno · ultimi 28 giorni"][i],systemImage:["waveform.path.ecg","heart.fill","moon.stars.fill"][i]);Spacer();Image(systemName:"arrow.up.right")}}.disabled(store.wellness.preferences.shortcutNames[i].isEmpty)}
        }.wellnessSurface()
        DisclosureGroup("Prima configurazione"){VStack(alignment:.leading,spacing:12){Text("Apri su iPhone i quattro file firmati e aggiungili a Comandi Rapidi. Non occorre ricostruire le azioni. Il comando unico richiama i tre importatori con i nomi originali.");Text("Esegui a telefono sbloccato e autorizza personalmente HRV, frequenza cardiaca a riposo e sonno. Se manca una misura, compare un avviso. Ripetere un campione non lo duplica.");Text("Ogni importatore legge gli ultimi 28 giorni disponibili e salva un unico lotto locale. Il limite è 10.000 campioni per lotto; la storia precedente già importata resta nell’archivio.");NavigationLink("Modifica i nomi dei comandi"){WellnessSettings()}}.font(.subheadline).padding(.top,10)}.wellnessSurface()
        Button("Apri Comandi Rapidi"){openURL(URL(string:"shortcuts://")!)}.buttonStyle(.bordered)
        DisclosureGroup("Privacy e dettagli"){Text("Nessuna azione invia i campioni a servizi esterni o modifica Salute di Apple. Fasi del sonno e fonte restano quelle importate; le etichette sconosciute vengono segnalate. Puoi avviare i comandi dall’app o da un’automazione scelta da te; lo sblocco può essere necessario. Le vecchie note testuali non diventano automaticamente misure.").font(.caption).padding(.top,8)}.wellnessSurface()
    }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Comandi Salute")}
    private func run(_ name:String){var c=URLComponents();c.scheme="shortcuts";c.host="run-shortcut";c.queryItems=[URLQueryItem(name:"name",value:name)];if let u=c.url{openURL(u)}}
}
struct WellnessMethods:View {
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){
        Text("Numeri spiegabili").font(.system(.title,design:.serif,weight:.semibold))
        Text("Misure, riepiloghi e indici personali hanno ruoli diversi. Le fasi di sonno sono stime del dispositivo. L’HRV importata è SDNN, non RMSSD.")
        Text("Baseline e recupero").font(.headline);Text("Mediana per giorno; logaritmo naturale della SDNN. Baseline dei 28 giorni precedenti, almeno 14 giorni appaiati HRV/riposo. z robusto = (oggi − mediana baseline) / (1,4826 × MAD), con pavimento 0,05 per ln(SDNN) e 2 bpm. Indice sperimentale = limita 0…100 [50 + 15 × limita(z HRV, −2…2) − 15 × limita(z riposo, −2…2)]. Formula originale e non validata clinicamente; non è una percentuale fisiologica, non replica l’algoritmo Athlytic e non è una prescrizione di allenamento.")
        Text("Sonno").font(.headline);Text("Finestra mezzogiorno → mezzogiorno. Fonte preferita o, in automatico, quella con più tempo addormentato nella notte. Unione degli intervalli con precedenza sveglio, profondo, REM, essenziale, addormentato generico. Le fasi specifiche sostituiscono gli intervalli generici sovrapposti. Efficienza calcolata soltanto dentro segmenti espliciti ‘a letto’. Adeguatezza = durata / obiettivo personale, massimo 100%. Nessun voto di qualità costruito da pesi arbitrari delle fasi.")
        Text("Allenamento").font(.headline);Text("Session-RPE di Foster: minuti × sforzo percepito 0–10. Rapporto delle medie mobili 7 e 28 giorni solo con copertura dichiarata completa; nessun rischio di infortunio dedotto dal rapporto. Monotonia = media 7 giorni / DS campionaria, strain = carico settimanale × monotonia. Se DS è zero, il valore resta assente.")
        Text("Cosa è disponibile").font(.headline);Text("Importazioni strutturate e JSON, storico e fonti, grafici 7/28/90 giorni, statistiche, sonno e fasi, obiettivo e deficit osservato, variabilità del risveglio, baseline e indice sperimentale, diario e confronti con tag, registro allenamenti RPE, copertura del carico, esportazione e cancellazione locale.")
        Text("Funzioni che richiedono un altro percorso").font(.headline);Text("La batteria fisiologica 24/7, stress continuo, GPS e registrazione sensori sul Watch, recupero battito dopo esercizio, suggerimenti AI generativi, allenamenti strutturati inviati al Watch e algoritmi proprietari Athlytic non sono ricreati da questi campioni. Non ci sono dati simulati nelle schermate personali. I widget e la companion richiedono una firma e una verifica separate.")
        Text("Fonti").font(.headline)
        Link("Foster et al. · session-RPE",destination:URL(string:"https://pubmed.ncbi.nlm.nih.gov/11708692/")!)
        Link("HRV-guided training · studio metodologico",destination:URL(string:"https://www.mdpi.com/2411-5142/6/4/102")!)
        Text("Lo studio usa lnRMSSD: il principio del confronto individuale non rende equivalente o validata la nostra formula su SDNN.").font(.caption)
        Link("Limiti del rapporto acuto/cronico",destination:URL(string:"https://pubmed.ncbi.nlm.nih.gov/32125672/")!)
        Link("Funzioni pubbliche Athlytic",destination:URL(string:"https://athlyticapp.helpscoutdocs.com/article/13-getting-started")!)
        Text("Tutto il calcolo avviene sul dispositivo. L’app non ha analytics o un backend sanitario. Il backup completo comprende ora i dati Salute ed è leggibile: scegli tu se e dove esportarlo.").font(.caption)
    }.padding(20)}.navigationTitle("Metodi e limiti")}
}
