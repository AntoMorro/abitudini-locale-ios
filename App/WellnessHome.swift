import SwiftUI
import Charts
import UniformTypeIdentifiers

extension HabitStore {
    var wellness:WellnessArchive {db.wellness ?? WellnessArchive()}
    @discardableResult func wellnessChange(_ body:(inout WellnessArchive)throws->Void)->Bool {change{db in var a=db.wellness ?? WellnessArchive();try body(&a);db.wellness=a}}
}
enum WellnessFormat {
    static func number(_ n:Double?)->String {n.map{$0.formatted(.number.precision(.fractionLength(1)))} ?? "—"}
    static func hours(_ seconds:Double)->String {let m=Int(seconds/60);return "\(m/60) h \(m%60) min"}
}
struct WellnessHome:View {
    @EnvironmentObject var store:HabitStore
    @State private var date=Date()
    @State private var page="Oggi"
    @State private var manual=false
    var a:WellnessArchive{store.wellness}
    var body:some View {ScrollView{LazyVStack(alignment:.leading,spacing:22){
        HStack{Image(systemName:"heart.fill").foregroundStyle(.pink);Text("Il tuo osservatorio personale").font(.system(.title,design:.serif,weight:.semibold))}
        Text("Importazioni locali, misure con una storia.").foregroundStyle(.secondary)
        HStack{NavigationLink{WellnessImportView()}label:{Label("Importa",systemImage:"square.and.arrow.down")};Spacer();Button("Aggiungi",systemImage:"plus"){manual=true};Spacer();NavigationLink{WellnessSettings()}label:{Image(systemName:"gearshape")}.accessibilityLabel("Preferenze Salute")}
        Picker("Sezione Salute",selection:$page){ForEach(["Oggi","Recupero","Sonno","Trend","Carico"],id:\.self){Text($0)}}.pickerStyle(.segmented)
        DatePicker("Data osservata",selection:$date,in:...Date(),displayedComponents:.date)
        if a.records.isEmpty{ContentUnavailableView("Inizia dai tuoi dati",systemImage:"heart.text.clipboard",description:Text("Importa HRV, frequenza a riposo e segmenti sonno da Comandi Rapidi. I grafici si riempiranno soltanto con i campioni ricevuti."));NavigationLink("Configura i comandi"){WellnessShortcutsGuide()}}
        else {switch page{case "Recupero":WellnessRecovery(date:date);case "Sonno":WellnessSleepView(date:date);case "Trend":WellnessTrends(date:date);case "Carico":WellnessTraining(date:date);default:overview}}
        NavigationLink{WellnessShortcutsGuide()}label:{Label("Comandi Rapidi e sincronizzazione",systemImage:"square.stack.3d.up")}
        NavigationLink{WellnessRecordsView()}label:{Label("Campioni, fonti ed esportazione",systemImage:"list.bullet.rectangle")}
        NavigationLink{WellnessMethods()}label:{Label("Metodi, fonti e funzioni disponibili",systemImage:"info.circle")}
    }.padding(20)}.navigationTitle("Salute").background(Color(uiColor:.systemGroupedBackground)).sheet(isPresented:$manual){WellnessManual()}}
    private var overview:some View {VStack(alignment:.leading,spacing:18){
        let h=WellnessAnalysis.daily(a,metric:.hrv).first{Calendar.current.isDate($0.date,inSameDayAs:date)}
        let r=WellnessAnalysis.daily(a,metric:.rhr).first{Calendar.current.isDate($0.date,inSameDayAs:date)}
        let s=WellnessAnalysis.sleep(a,on:date)
        HStack{WellnessCard(title:"HRV · SDNN",value:WellnessFormat.number(h?.value),unit:"ms");WellnessCard(title:"A riposo",value:WellnessFormat.number(r?.value),unit:"bpm")}
        WellnessCard(title:"Sonno importato",value:s.seconds>0 ? WellnessFormat.hours(s.seconds):"—",unit:s.source.isEmpty ? "Nessuna notte disponibile":s.source)
        Text("Dati della data scelta, non un monitoraggio in tempo reale.").font(.caption).foregroundStyle(.secondary)
        if let last=a.records.map(\.imported).max(){Text("Ultima importazione: "+last.formatted(date:.abbreviated,time:.shortened)).font(.caption)}
        WellnessRecovery(date:date,compact:true)
        Text("Il contesto conta").font(.headline)
        let pages=store.journal.pages.filter{Calendar.current.isDate($0.date,inSameDayAs:date)}
        if pages.isEmpty{Text("Puoi annotare energia, umore e contesto nel diario. Nessun valore viene dedotto in loro assenza.").foregroundStyle(.secondary)}
        ForEach(pages.prefix(3)){JournalPageCard(page:$0)}
    }}
}
struct WellnessCard:View {var title:String;var value:String;var unit:String
    var body:some View{VStack(alignment:.leading,spacing:8){Text(title).font(.caption).foregroundStyle(.secondary);Text(value).font(.system(.title2,design:.rounded,weight:.semibold));Text(unit).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18))}
}
struct WellnessRecovery:View {
    @EnvironmentObject var store:HabitStore
    var date:Date;var compact=false
    var body:some View {let a=store.wellness,r=WellnessAnalysis.readiness(a,on:date)
        VStack(alignment:.leading,spacing:16){Text("Recupero personale").font(.title2.bold())
            HStack(alignment:.firstTextBaseline){Text(r.score.map{String(Int($0.rounded()))} ?? "—").font(.system(size:60,weight:.semibold,design:.rounded)).foregroundStyle(.mint);Text("indice 0–100").foregroundStyle(.secondary)}
            Text(r.reason);Text("Baseline: \(r.baselineDays) giorni validi precedenti · finestra 28 giorni").font(.caption).foregroundStyle(.secondary)
            if !compact{Text("HRV: ln(SDNN) e mediana giornaliera; frequenza a riposo: mediana giornaliera. Il giorno corrente è escluso dalla baseline. Nessuna equivalenza con il punteggio Athlytic.").font(.caption)
                HStack{WellnessCard(title:"Deviazione HRV",value:WellnessFormat.number(r.hrvZ),unit:"z robusto");WellnessCard(title:"Deviazione riposo",value:WellnessFormat.number(r.rhrZ),unit:"z robusto")}
                WellnessMetricChart(metric:.hrv,date:date);WellnessMetricChart(metric:.rhr,date:date)
                Text("Lettura prudente").font(.headline);Text("Cerca coerenza nelle condizioni di misura. Valori molto più alti o più bassi della tua baseline meritano contesto; un indice alto non autorizza automaticamente un allenamento intenso. Non è una diagnosi o una misura clinica di recupero.").font(.caption)
            }
        }.padding(16).background(.mint.opacity(0.07),in:RoundedRectangle(cornerRadius:18))
    }
}
struct WellnessMetricChart:View {
    @EnvironmentObject var store:HabitStore
    var metric:WellnessMetric;var date:Date;var days=28
    var body:some View {let end=Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:date))!,start=Calendar.current.date(byAdding:.day,value:-days,to:end)!
        let values=WellnessAnalysis.daily(store.wellness,metric:metric).filter{$0.date>=start && $0.date<end}
        VStack(alignment:.leading,spacing:12){Text(metric.title+" · \(days) giorni").font(.headline)
            if values.isEmpty{Text("Nessun dato importato nell’intervallo.").foregroundStyle(.secondary)}else{
                Chart(values){p in PointMark(x:.value("Data",p.date),y:.value(metric.unit,p.value)).foregroundStyle(.mint)}.chartYScale(domain:.automatic(includesZero:false)).frame(height:170).accessibilityLabel(metric.title+" per giorno")
                HStack{Text("Media "+WellnessFormat.number(WellnessAnalysis.mean(values.map(\.value))));Spacer();Text("\(values.count) giorni")}.font(.caption)
                Text("Min "+WellnessFormat.number(values.map(\.value).min())+" · max "+WellnessFormat.number(values.map(\.value).max())+" "+metric.unit).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(16).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:16))
    }
}
struct WellnessSleepView:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    var body:some View{let a=store.wellness,s=WellnessAnalysis.sleep(a,on:date),goal=a.preferences.sleepGoal*3600
        VStack(alignment:.leading,spacing:16){
            Text("La tua notte").font(.title2.bold());WellnessCard(title:"Tempo addormentato",value:s.seconds>0 ? WellnessFormat.hours(s.seconds):"—",unit:s.source)
            if s.seconds>0{
                HStack{WellnessCard(title:"Obiettivo raggiunto",value:String(Int(min(100,100*s.seconds/goal))),unit:"% di \(a.preferences.sleepGoal.formatted()) ore");WellnessCard(title:"Efficienza a letto",value:WellnessFormat.number(s.efficiency),unit:s.efficiency==nil ? "Servono segmenti a letto":"%")}
                if s.inBedSeconds>0{HStack{Text("Tempo a letto");Spacer();Text(WellnessFormat.hours(s.inBedSeconds))}}
                ForEach(WellnessPhase.allCases.filter{$0 != .inBed}){p in if let seconds=s.phases[p.rawValue],seconds>0{HStack{Text(p.title);Spacer();Text(WellnessFormat.hours(seconds)).monospacedDigit()}}}
                if let start=s.start,let end=s.end{Text(start.formatted(date:.abbreviated,time:.shortened)+" → "+end.formatted(date:.abbreviated,time:.shortened)).font(.caption)}
            }
            if !s.timeline.isEmpty {Chart(s.timeline){span in RectangleMark(xStart:.value("Inizio",span.start),xEnd:.value("Fine",span.end),y:.value("Fase",span.phase.title)).foregroundStyle(by:.value("Fase",span.phase.title))}.frame(height:160).accessibilityLabel("Fasi del sonno importate nella notte")}
            let nights=(0..<14).reversed().map{WellnessAnalysis.sleep(a,on:Calendar.current.date(byAdding:.day,value:-$0,to:Calendar.current.startOfDay(for:date))!)}
            let valid=nights.filter{$0.seconds>0}
            Chart(Array(valid.enumerated()),id:\.offset){_,n in BarMark(x:.value("Notte",n.date,unit:.day),y:.value("Ore",n.seconds/3600)).foregroundStyle(.indigo)}.frame(height:170)
            let debt=valid.reduce(0){$0+max(0,goal-$1.seconds)}
            WellnessCard(title:"Deficit rispetto al tuo obiettivo",value:WellnessFormat.hours(debt),unit:"Solo \(valid.count) notti disponibili delle ultime 14")
            if let sd=WellnessAnalysis.circularMinuteDeviation(valid.compactMap(\.end).map{Double(Calendar.current.component(.hour,from:$0)*60+Calendar.current.component(.minute,from:$0))}),valid.count>=7 {Text("Variabilità dell’orario di risveglio: \(Int(sd)) min (deviazione circolare, gestisce mezzanotte).").font(.caption)}
            Text("Finestra: da mezzogiorno del giorno precedente a mezzogiorno della data scelta. Una sola fonte per notte, sovrapposizioni risolte senza doppio conteggio. Se manca la fase, resta ‘Addormentato’; non vengono inventati REM o sonno profondo. Il deficit non è una prescrizione di ore da recuperare.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct WellnessTrends:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    @State private var metric:WellnessMetric = .hrv
    @State private var days=28
    var body:some View{VStack(alignment:.leading,spacing:18){Picker("Metrica",selection:$metric){ForEach(WellnessMetric.allCases.filter{![.sleep,.workout].contains($0)}){Text($0.title).tag($0)}};Picker("Periodo",selection:$days){Text("7 giorni").tag(7);Text("28 giorni").tag(28);Text("90 giorni").tag(90)}.pickerStyle(.segmented);WellnessMetricChart(metric:metric,date:date,days:days)
        Text("Confronti personali").font(.title2.bold())
        let h=WellnessAnalysis.daily(store.wellness,metric:.hrv),r=WellnessAnalysis.daily(store.wellness,metric:.rhr)
        let begin=Calendar.current.date(byAdding:.day,value:-days,to:date)!
        let pairs=h.filter{$0.date>=begin && $0.date<=date}.compactMap{p -> (Double,Double)? in guard let other=r.first(where:{$0.date==p.date}) else{return nil};return(p.value,other.value)}
        Text("HRV ↔ riposo: r = "+WellnessFormat.number(WellnessAnalysis.correlation(pairs))+" · \(pairs.count) giorni appaiati").font(.subheadline)
        Text("La correlazione richiede almeno 10 coppie e variabilità in entrambe le serie; non dimostra una causa.").font(.caption).foregroundStyle(.secondary)
        let tags=Array(Set(store.journal.pages.flatMap(\.tags))).sorted()
        ForEach(Array(tags.prefix(12)),id:\.self){tag in
            let tagged=Set(store.journal.pages.filter{$0.tags.contains(tag)}.map{WellnessAnalysis.day($0.date)})
            let selected=h.filter{$0.date>=begin && $0.date<=date && tagged.contains(WellnessAnalysis.day($0.date))}
            Text("#\(tag): HRV media "+WellnessFormat.number(WellnessAnalysis.mean(selected.map(\.value)))+" ms · \(selected.count) giorni").font(.caption)
        }
        Text("I tag associano le pagine al giorno della misura, non attribuiscono effetti alle abitudini. Le somme di passi ed energia si riferiscono solo ai campioni importati; evita di mescolare i totali con i singoli segmenti o più fonti sovrapposte.").font(.caption)
    }}
}
struct WellnessTraining:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    var body:some View{let a=store.wellness,l=WellnessAnalysis.load(a,on:date),key=WellnessAnalysis.day(date)
        VStack(alignment:.leading,spacing:16){Text("Allenamento e carico").font(.title2.bold())
            Toggle("Giornata completa: tutti gli allenamenti registrati (o riposo)",isOn:Binding(get:{store.wellness.confirmedTrainingDays.contains(key)},set:{v in store.wellnessChange{a in a.confirmedTrainingDays.removeAll{$0==key};if v{a.confirmedTrainingDays.append(key)}}}))
            ForEach(a.records.filter{$0.metric == .workout && Calendar.current.isDate($0.start,inSameDayAs:date)}.sorted{$0.start<$1.start}){r in WellnessCard(title:r.name.isEmpty ? "Allenamento":r.name,value:WellnessFormat.hours(r.end.timeIntervalSince(r.start)),unit:r.rpe.map{"RPE \($0.formatted()) · carico \((r.end.timeIntervalSince(r.start)/60*$0).formatted()) UA"} ?? "Inserisci RPE per calcolare il carico")}
            HStack{WellnessCard(title:"Media 7 giorni",value:WellnessFormat.number(l.acute),unit:"UA/giorno");WellnessCard(title:"Media 28 giorni",value:WellnessFormat.number(l.chronic),unit:"UA/giorno")}
            WellnessCard(title:"Rapporto 7 / 28 giorni",value:WellnessFormat.number(l.ratio),unit:"\(l.covered)/28 giorni completi")
            Text("Monotonia: "+WellnessFormat.number(l.monotony)+" · strain settimanale: "+WellnessFormat.number(l.strain)).font(.caption)
            Text("Carico sessione = minuti × RPE (0–10). Conferma anche le giornate di riposo: i giorni sconosciuti non diventano zeri. Il rapporto compare solo con 28 giorni completi e una media positiva; non predice infortuni e non prescrive un obiettivo. Usa Aggiungi → Allenamento per registrare o modifica la voce dall’archivio campioni.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
