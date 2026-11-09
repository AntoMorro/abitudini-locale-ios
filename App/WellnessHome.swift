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
    @Environment(\.openURL) private var openURL
    @State private var date=Date()
    @State private var page="Oggi"
    @State private var manual=false
    @State private var tools=false
    var a:WellnessArchive{store.wellness}
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:22){
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--wellness-preview"){Text("ANTEPRIMA · DATI FITTIZI").font(.caption.bold()).foregroundStyle(.orange)}
            #endif
            heading
            pagePicker
            if a.records.isEmpty {emptyState}
            else {switch page{case "Sonno":WellnessSleepView(date:date);case "Trend":WellnessTrends(date:date);default:overview}}
            NavigationLink{WellnessRecordsView()}label:{WellnessUtilityRow(title:"Campioni, fonti ed esportazione",subtitle:"I tuoi dati, sempre sul dispositivo",symbol:"square.stack.3d.up",color:WellnessStyle.hrv)}.buttonStyle(.plain)
            NavigationLink{WellnessShortcutsGuide()}label:{WellnessUtilityRow(title:"Comandi Rapidi e sincronizzazione",subtitle:"Importa e aggiorna le tue misure",symbol:"arrow.trianglehead.2.clockwise.rotate.90",color:WellnessStyle.sleep)}.buttonStyle(.plain)
            Text("Dati importati · nessun monitoraggio in tempo reale").font(.caption2).foregroundStyle(.secondary).frame(maxWidth:.infinity).padding(.bottom,12)
        }.padding(.horizontal,20).padding(.top,8)}
        .background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Salute").navigationBarTitleDisplayMode(.inline)
        .toolbar{
            ToolbarItem(placement:.topBarTrailing){Button{tools=true}label:{Image(systemName:"slider.horizontal.3")}.accessibilityLabel("Strumenti Salute")}
            ToolbarItem(placement:.topBarTrailing){Button{manual=true}label:{Image(systemName:"plus")}.accessibilityLabel("Aggiungi")}
        }
        .sheet(isPresented:$manual){WellnessManual()}
        .sheet(isPresented:$tools){NavigationStack{WellnessToolsMenu()}}
    }
    private var heading:some View {VStack(alignment:.leading,spacing:16){
        HStack(alignment:.top){VStack(alignment:.leading,spacing:5){Text("Il tuo ritmo.").font(.system(size:34,weight:.bold,design:.rounded));Text("Uno sguardo a come stai.").font(.subheadline).foregroundStyle(.secondary)};Spacer()}
        HStack(spacing:12){
            Button{move(-1)}label:{Image(systemName:"chevron.left").frame(width:36,height:40)}.accessibilityLabel("Giorno precedente")
            DatePicker("Data osservata",selection:$date,in:...Date(),displayedComponents:.date).labelsHidden().frame(maxWidth:.infinity)
            Button{move(1)}label:{Image(systemName:"chevron.right").frame(width:36,height:40)}.disabled(Calendar.current.isDateInToday(date)).accessibilityLabel("Giorno successivo")
        }.tint(.primary)
        HStack{Button{runAll()}label:{Label("Aggiorna dati",systemImage:"arrow.clockwise").font(.subheadline.weight(.semibold))}.buttonStyle(.borderedProminent).tint(WellnessStyle.hrv).accessibilityIdentifier("wellnessRefresh")
            Spacer();if let last=a.records.map(\.imported).max(){VStack(alignment:.trailing,spacing:2){Text("Ultimo aggiornamento").font(.caption2);Text(last,style:.relative).font(.caption.weight(.medium))}.foregroundStyle(.secondary)}
        }
    }}
    private var pagePicker:some View {HStack(spacing:6){ForEach([("Oggi","square.grid.2x2"),("Sonno","moon.stars"),("Trend","chart.xyaxis.line")],id:\.0){title,symbol in Button{page=title}label:{Label(title,systemImage:symbol).font(.subheadline.weight(.semibold)).frame(maxWidth:.infinity).padding(.vertical,12).background(page==title ? Color(uiColor:.secondarySystemGroupedBackground):.clear,in:Capsule())}.buttonStyle(.plain).foregroundStyle(page==title ? Color.primary:Color.secondary).accessibilityAddTraits(page==title ? .isSelected:[])}}.padding(5).background(Color.primary.opacity(0.045),in:Capsule())}
    private var emptyState:some View {VStack(alignment:.leading,spacing:18){Image(systemName:"heart.text.clipboard").font(.system(size:36)).foregroundStyle(WellnessStyle.hrv);Text("Il tuo spazio,\ni tuoi dati.").font(.system(size:28,weight:.bold,design:.rounded));Text("Aggiungi i comandi una volta. Poi importa HRV, battito a riposo e sonno con un tocco.").foregroundStyle(.secondary);NavigationLink("Configura i comandi"){WellnessShortcutsGuide()}.buttonStyle(.borderedProminent).tint(WellnessStyle.hrv)}.wellnessSurface()}
    private var overview:some View {
        let h=WellnessAnalysis.daily(a,metric:.hrv),r=WellnessAnalysis.daily(a,metric:.rhr)
        let todayH=h.first{Calendar.current.isDate($0.date,inSameDayAs:date)},todayR=r.first{Calendar.current.isDate($0.date,inSameDayAs:date)}
        let s=WellnessAnalysis.sleep(a,on:date)
        return VStack(alignment:.leading,spacing:18){
            NavigationLink{ScrollView{WellnessRecovery(date:date).padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Recupero")}label:{WellnessRecoveryHero(readiness:WellnessAnalysis.readiness(a,on:date))}.buttonStyle(.plain).accessibilityIdentifier("wellnessRecovery")
            ViewThatFits(in:.horizontal){HStack(alignment:.top,spacing:12){hrvTile(h,todayH);restTile(r,todayR)};VStack(spacing:12){hrvTile(h,todayH);restTile(r,todayR)}}
            Button{page="Sonno"}label:{HStack(spacing:16){Image(systemName:"moon.stars.fill").font(.title).foregroundStyle(WellnessStyle.sleep).frame(width:52,height:60).background(WellnessStyle.sleep.opacity(0.1),in:RoundedRectangle(cornerRadius:18));VStack(alignment:.leading,spacing:5){Text("La tua notte").font(.subheadline.weight(.semibold));Text(s.seconds>0 ? WellnessFormat.hours(s.seconds):"Nessun dato").font(.system(.title2,design:.rounded,weight:.bold));Text(s.seconds>0 ? "Tocca per esplorare le fasi":"Importa i segmenti di sonno").font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)}.wellnessSurface()}.buttonStyle(.plain).accessibilityIdentifier("wellnessSleepCard")
            Text("I dati si riferiscono al giorno selezionato. I trattini indicano misure mancanti.").font(.caption).foregroundStyle(.secondary)
            let pages=store.journal.pages.filter{Calendar.current.isDate($0.date,inSameDayAs:date)}
            if !pages.isEmpty{Text("Dal tuo diario").font(.title3.bold());ForEach(pages.prefix(2)){JournalPageCard(page:$0)}}
        }
    }
    private func lastWeek(_ values:[WellnessPoint])->[WellnessPoint]{let end=Calendar.current.startOfDay(for:date),start=Calendar.current.date(byAdding:.day,value:-6,to:end)!;return values.filter{$0.date>=start && $0.date<=end}}
    private func hrvTile(_ values:[WellnessPoint],_ today:WellnessPoint?)->some View{WellnessMetricTile(title:"HRV · SDNN",symbol:"waveform.path.ecg",value:WellnessFormat.number(today?.value),unit:"ms · mediana del giorno",color:WellnessStyle.hrv,points:lastWeek(values)).frame(minWidth:130)}
    private func restTile(_ values:[WellnessPoint],_ today:WellnessPoint?)->some View{WellnessMetricTile(title:"A riposo",symbol:"heart.fill",value:WellnessFormat.number(today?.value),unit:"bpm · mediana del giorno",color:WellnessStyle.rest,points:lastWeek(values)).frame(minWidth:130)}
    private func move(_ days:Int){if let next=Calendar.current.date(byAdding:.day,value:days,to:date){date=min(next,Date())}}
    private func runAll(){var c=URLComponents();c.scheme="shortcuts";c.host="run-shortcut";c.queryItems=[URLQueryItem(name:"name",value:"Aggiorna Salute Quaderno")];if let u=c.url{openURL(u)}}
}

struct WellnessToolsMenu:View {
    @Environment(\.dismiss) private var dismiss
    var body:some View {List{
        Section("Dati"){NavigationLink("Importa file o testo JSON"){WellnessImportView()};NavigationLink("Campioni, fonti ed esportazione"){WellnessRecordsView()};NavigationLink("Comandi Rapidi e sincronizzazione"){WellnessShortcutsGuide()}}
        Section("Personalizza"){NavigationLink("Preferenze Salute"){WellnessSettings()};NavigationLink("Allenamento e carico"){ScrollView{WellnessTraining(date:Date()).padding(20)}.navigationTitle("Allenamento")};NavigationLink("Metodi e limiti"){WellnessMethods()}}
    }.navigationTitle("Strumenti Salute").toolbar{ToolbarItem(placement:.confirmationAction){Button("Fine"){dismiss()}}}}
}
struct WellnessCard:View {var title:String;var value:String;var unit:String
    var body:some View{VStack(alignment:.leading,spacing:8){Text(title).font(.caption).foregroundStyle(.secondary);Text(value).font(.system(.title2,design:.rounded,weight:.bold));Text(unit).font(.caption).foregroundStyle(.secondary)}.wellnessSurface()}
}
struct WellnessRecovery:View {
    @EnvironmentObject var store:HabitStore
    var date:Date;var compact=false
    var body:some View {let r=WellnessAnalysis.readiness(store.wellness,on:date)
        VStack(alignment:.leading,spacing:20){
            WellnessRecoveryHero(readiness:r).allowsHitTesting(false)
            VStack(alignment:.leading,spacing:10){Text("La tua baseline").font(.headline);ProgressView(value:Double(min(14,r.baselineDays)),total:14).tint(WellnessStyle.hrv);Text(r.reason).font(.subheadline).foregroundStyle(.secondary);Text("\(r.baselineDays) giorni precedenti validi · finestra di 28 giorni").font(.caption).foregroundStyle(.secondary)}.wellnessSurface()
            if !compact{WellnessMetricChart(metric:.hrv,date:date);WellnessMetricChart(metric:.rhr,date:date)
                DisclosureGroup("Come leggere questo indice"){VStack(alignment:.leading,spacing:12){Text("Indice sperimentale, non clinico. Confronta ln(SDNN) e frequenza a riposo con la tua baseline; il giorno scelto è escluso dalla baseline.");Text("Deviazione HRV: "+WellnessFormat.number(r.hrvZ)+" · riposo: "+WellnessFormat.number(r.rhrZ)+" (z robusto)");Text("Un valore alto non prescrive un allenamento intenso. Cerca coerenza delle fonti e delle condizioni di misura.");NavigationLink("Formula e limiti"){WellnessMethods()}}.font(.caption).padding(.top,8)}.wellnessSurface()
            }
        }
    }
}
struct WellnessMetricChart:View {
    @EnvironmentObject var store:HabitStore
    var metric:WellnessMetric;var date:Date;var days=28
    @State private var selected:Date?
    private var color:Color{metric == .hrv ? WellnessStyle.hrv:metric == .rhr ? WellnessStyle.rest:WellnessStyle.sleep}
    var body:some View {
        let end=Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:date))!,start=Calendar.current.date(byAdding:.day,value:-days,to:end)!
        let values=WellnessAnalysis.daily(store.wellness,metric:metric).filter{$0.date>=start && $0.date<end}
        let point=selected.flatMap{day in values.first{Calendar.current.isDate($0.date,inSameDayAs:day)}}
        return VStack(alignment:.leading,spacing:16){
            HStack{Text(metric.title).font(.headline);Spacer();Text("\(values.count) / \(days) giorni").font(.caption).foregroundStyle(.secondary)}
            HStack(alignment:.firstTextBaseline,spacing:6){Text(WellnessFormat.number(point?.value ?? WellnessAnalysis.mean(values.map(\.value)))).font(.system(size:34,weight:.bold,design:.rounded));Text(metric.unit).foregroundStyle(.secondary);Spacer()}
            Text(point.map{$0.date.formatted(date:.abbreviated,time:.omitted)} ?? "Media dei giorni disponibili").font(.caption).foregroundStyle(.secondary)
            if values.isEmpty{ContentUnavailableView("Nessun dato",systemImage:"chart.bar",description:Text("Importa i campioni per questo periodo."))}
            else {
                Chart(values){p in
                    BarMark(x:.value("Data",p.date,unit:.day),y:.value(metric.unit,p.value)).foregroundStyle(color.gradient).cornerRadius(4)
                    if let point,point.id==p.id{RuleMark(x:.value("Selezione",p.date)).foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth:1,dash:[4,3]))}
                }.chartXScale(domain:start...end).chartXSelection(value:$selected).frame(height:180).accessibilityLabel(metric.title+" per giorno").accessibilityValue("\(values.count) giorni con dati, media "+WellnessFormat.number(WellnessAnalysis.mean(values.map(\.value)))+" "+metric.unit)
                HStack{stat("Minimo",values.map(\.value).min());Spacer();stat("Massimo",values.map(\.value).max());Spacer();stat("Media",WellnessAnalysis.mean(values.map(\.value)))}
                Text("Tocca o trascina sul grafico. I giorni senza campioni restano vuoti.").font(.caption2).foregroundStyle(.secondary)
            }
        }.wellnessSurface()
    }
    private func stat(_ label:String,_ value:Double?)->some View{VStack(alignment:.leading,spacing:4){Text(label).font(.caption2).foregroundStyle(.secondary);Text(WellnessFormat.number(value)).font(.subheadline.weight(.semibold)).monospacedDigit()}}
}
struct WellnessSleepView:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    var body:some View {
        let a=store.wellness,s=WellnessAnalysis.sleep(a,on:date),goal=a.preferences.sleepGoal*3600
        let nights=(0..<14).reversed().map{WellnessAnalysis.sleep(a,on:Calendar.current.date(byAdding:.day,value:-$0,to:Calendar.current.startOfDay(for:date))!)}
        let valid=nights.filter{$0.seconds>0}
        return VStack(alignment:.leading,spacing:20){
            VStack(alignment:.leading,spacing:20){
                Label("LA TUA NOTTE",systemImage:"moon.stars.fill").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(WellnessStyle.sleep)
                ViewThatFits(in:.horizontal){HStack(spacing:22){duration(s);sleepRing(s,goal)};VStack(alignment:.leading,spacing:18){duration(s);sleepRing(s,goal)}}
                if let start=s.start,let end=s.end{HStack{Label(start.formatted(date:.omitted,time:.shortened),systemImage:"bed.double");Spacer();Label(end.formatted(date:.omitted,time:.shortened),systemImage:"sunrise")}.font(.subheadline).foregroundStyle(.secondary)}
            }.wellnessSurface()
            if !s.timeline.isEmpty{
                VStack(alignment:.leading,spacing:18){Text("Il viaggio nel sonno").font(.headline)
                    Chart(s.timeline){span in RectangleMark(xStart:.value("Inizio",span.start),xEnd:.value("Fine",span.end),y:.value("Fase",span.phase.title),height:.ratio(0.7)).foregroundStyle(WellnessStyle.phase(span.phase)).cornerRadius(3)}.frame(height:180).accessibilityLabel("Fasi del sonno importate nella notte")
                    ForEach(WellnessPhase.allCases.filter{$0 != .inBed}){phase in if let seconds=s.phases[phase.rawValue],seconds>0{phaseRow(phase,seconds,s)}}
                }.wellnessSurface()
            }
            VStack(alignment:.leading,spacing:16){Text("Le ultime 14 notti").font(.headline)
                if valid.isEmpty{Text("Importa il sonno per vedere lo storico.").foregroundStyle(.secondary)}else{
                    Chart(Array(valid.enumerated()),id:\.offset){_,n in BarMark(x:.value("Notte",n.date,unit:.day),y:.value("Ore",n.seconds/3600)).foregroundStyle(WellnessStyle.sleep.gradient).cornerRadius(4);RuleMark(y:.value("Obiettivo",a.preferences.sleepGoal)).foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth:1,dash:[4,4]))}.chartXScale(domain:nights.first!.date...Calendar.current.date(byAdding:.day,value:1,to:date)!).frame(height:160).accessibilityLabel("Durata del sonno nelle ultime 14 notti")
                    Text("\(valid.count) notti disponibili · linea tratteggiata: obiettivo personale").font(.caption).foregroundStyle(.secondary)
                }
            }.wellnessSurface()
            HStack(alignment:.top,spacing:12){WellnessCard(title:"Efficienza a letto",value:WellnessFormat.number(s.efficiency),unit:s.efficiency==nil ? "Mancano segmenti a letto":"% del tempo a letto");WellnessCard(title:"Deficit osservato",value:valid.isEmpty ? "—":WellnessFormat.hours(valid.reduce(0){$0+max(0,goal-$1.seconds)}),unit:"\(valid.count) notti su 14")}
            DisclosureGroup("Dettagli della notte"){VStack(alignment:.leading,spacing:12){Text("Fonte: "+(s.source.isEmpty ? "nessuna":s.source));if s.inBedSeconds>0{Text("Tempo a letto: "+WellnessFormat.hours(s.inBedSeconds))};if let sd=WellnessAnalysis.circularMinuteDeviation(valid.compactMap(\.end).map{Double(Calendar.current.component(.hour,from:$0)*60+Calendar.current.component(.minute,from:$0))}),valid.count>=7{Text("Variabilità del risveglio: \(Int(sd)) min")};Text("Una fonte per notte, da mezzogiorno a mezzogiorno. Intervalli sovrapposti risolti senza doppio conteggio. Le fasi mancanti restano non specificate; il deficit non è una prescrizione.")}.font(.caption).foregroundStyle(.secondary).padding(.top,8)}.wellnessSurface()
        }
    }
    private func duration(_ s:WellnessSleep)->some View{VStack(alignment:.leading,spacing:7){Text(s.seconds>0 ? WellnessFormat.hours(s.seconds):"—").font(.system(size:31,weight:.bold,design:.rounded)).minimumScaleFactor(0.7);Text(s.seconds>0 ? "Tempo addormentato":"Nessuna notte importata").font(.subheadline).foregroundStyle(.secondary)}.frame(minWidth:125,maxWidth:.infinity,alignment:.leading)}
    private func sleepRing(_ s:WellnessSleep,_ goal:Double)->some View{WellnessRing(progress:s.seconds>0 ? s.seconds/goal:nil,color:WellnessStyle.sleep,title:s.seconds>0 ? "\(Int(min(100,100*s.seconds/goal)))%":"—",subtitle:"obiettivo \(store.wellness.preferences.sleepGoal.formatted()) h")}
    private func phaseRow(_ phase:WellnessPhase,_ seconds:Double,_ s:WellnessSleep)->some View{VStack(spacing:7){HStack{Circle().fill(WellnessStyle.phase(phase)).frame(width:7,height:7);Text(phase.title);Spacer();Text(WellnessFormat.hours(seconds)).monospacedDigit()}.font(.caption);GeometryReader{g in Capsule().fill(WellnessStyle.phase(phase).opacity(0.16)).overlay(alignment:.leading){Capsule().fill(WellnessStyle.phase(phase)).frame(width:g.size.width*min(1,seconds/max(1,s.phases.values.reduce(0,+))))}}.frame(height:5)}}
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
