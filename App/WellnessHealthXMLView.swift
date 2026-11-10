import SwiftUI
import UniformTypeIdentifiers

struct WellnessHealthXMLView:View {
    @EnvironmentObject var store:HabitStore
    @State private var days=7
    @State private var metrics:Set<WellnessMetric>=[.heart,.respiration,.oxygen,.temperature]
    @State private var file=false
    @State private var busy=false
    @State private var task:Task<Void,Never>?
    @State private var preview:[WellnessRecord]=[]
    @State private var message=""
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        WellnessDetailHeading(eyebrow:"Importazione locale",title:"Il tuo export di Salute.",detail:"Leggi export.xml sul dispositivo, senza upload o HealthKit nella firma.",color:.mint)
        DisclosureGroup("Come ottenere il file"){Text("Su iPhone: Salute → immagine del profilo → Esporta tutti i dati sanitari. Salva lo ZIP in File. Toccalo in File per estrarlo, poi seleziona export.xml qui. Non condividere il file in chat.").font(.subheadline).padding(.top,10)}.wellnessSurface()
        Picker("Periodo",selection:$days){Text("1 giorno").tag(1);Text("7 giorni").tag(7);Text("28 giorni").tag(28);Text("90 giorni").tag(90)}.pickerStyle(.segmented).disabled(busy)
        VStack(alignment:.leading,spacing:12){Text("Quali dati importare").font(.headline)
            ForEach([WellnessMetric.heart,.respiration,.oxygen,.temperature,.hrv,.rhr,.sleep,.workout,.steps,.energy,.food,.weight,.vo2]){m in Toggle(m.title,isOn:Binding(get:{metrics.contains(m)},set:{v in if v{metrics.insert(m)}else{metrics.remove(m)}})).disabled(busy)}
        }.wellnessSurface()
        Button("Scegli export.xml",systemImage:"doc"){preview=[];file=true}.buttonStyle(.borderedProminent).disabled(busy || metrics.isEmpty)
        if busy{ProgressView("Lettura del file sul dispositivo…");Button("Annulla lettura",role:.cancel){task?.cancel()}}
        if !preview.isEmpty{VStack(alignment:.leading,spacing:12){Text("\(preview.count) campioni pronti").font(.title2.bold());ForEach(WellnessMetric.allCases){m in let count=preview.filter{$0.metric==m}.count;if count>0{Text("\(m.title): \(count)")}};Button("Conferma importazione XML"){var result=(added:0,updated:0);if store.wellnessChange({a in result=try a.merge(preview)}){message="Importati \(result.added), aggiornati \(result.updated).";preview=[]}}.buttonStyle(.borderedProminent)}.wellnessSurface()}
        if !message.isEmpty{Text(message).textSelection(.enabled)}
        Text("Lettura XML in streaming, massimo 10.000 campioni selezionati per lotto. I file grandi possono richiedere tempo. Nessun salvataggio prima della conferma. Gli allenamenti importati non hanno RPE: aggiungila nel registro e conferma i giorni completi. La SpO₂ dell’XML HealthKit viene convertita da frazione a percentuale; una temperatura relativa non viene usata come temperatura assoluta.").font(.caption).foregroundStyle(.secondary)
        NavigationLink("Comandi HRV, riposo e sonno"){WellnessShortcutsGuide()}
    }.padding(20)}.navigationTitle("Importa Salute XML")
        .onChange(of:days){_,_ in preview=[]}.onChange(of:metrics){_,_ in preview=[]}
        .onDisappear{task?.cancel()}
        .fileImporter(isPresented:$file,allowedContentTypes:[.xml]){result in
            do{let url=try result.get();read(url)}catch{message=error.localizedDescription}
        }
    }
    private func read(_ url:URL){
        let selected=metrics,since=Calendar.current.date(byAdding:.day,value:-days,to:Date())!
        busy=true;message="";preview=[]
        task=Task{
            let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()};busy=false}
            let worker=Task.detached(priority:.userInitiated){try WellnessHealthXML.read(url:url,since:since,metrics:selected)}
            do{let records=try await withTaskCancellationHandler{try await worker.value}onCancel:{worker.cancel()};try Task.checkCancellation();preview=records;message="Anteprima pronta, non ancora salvata."}
            catch is CancellationError{message="Lettura annullata. Nessun dato salvato."}
            catch{message=error.localizedDescription}
        }
    }
}
