import SwiftUI
import Charts

struct WellnessExplore:View {
    var date:Date
    var body:some View{
        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){
            NavigationLink{WellnessActivationView(date:date)}label:{tile("Stress e contesto","waveform.path.ecg",.cyan)}.accessibilityIdentifier("insightStress")
            NavigationLink{WellnessLoadView(date:date)}label:{tile("Carico","chart.xyaxis.line",.mint)}.accessibilityIdentifier("insightLoad")
            NavigationLink{WellnessMonitorView(date:date)}label:{tile("Monitor salute","heart.text.square",.pink)}.accessibilityIdentifier("insightMonitor")
            NavigationLink{WellnessSummaryGallery(date:date)}label:{tile("Riepiloghi e widget","square.grid.2x2",.indigo)}.accessibilityIdentifier("insightWidgets")
        }.buttonStyle(.plain)
    }
    private func tile(_ title:String,_ icon:String,_ color:Color)->some View{HStack(spacing:9){Image(systemName:icon).foregroundStyle(color);Text(title).font(.subheadline.weight(.semibold));Spacer(minLength:0)}.padding(16).frame(maxWidth:.infinity,minHeight:60,alignment:.leading).background(color.opacity(0.10),in:RoundedRectangle(cornerRadius:20))}
}
struct WellnessDetailHeading:View {
    var eyebrow:String;var title:String;var detail:String;var color:Color
    var body:some View{VStack(alignment:.leading,spacing:10){Text(eyebrow.uppercased()).font(.caption2.bold()).tracking(1.5).foregroundStyle(color);Text(title).font(.system(size:32,weight:.bold,design:.rounded));Text(detail).font(.subheadline).foregroundStyle(.secondary)}}
}
struct WellnessActivationView:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    var data:WellnessActivation{WellnessInsights.activation(store.wellness,on:date)}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        WellnessDetailHeading(eyebrow:"Stress e contesto",title:"Il ritmo della giornata.",detail:"Un indicatore cardiaco relativo. Non misura lo stress psicologico.",color:.cyan)
        summary
        plot
        context
        DisclosureGroup("Calcolo e limiti"){Text("Ogni barra è la mediana dei campioni di una finestra di 15 minuti, da una sola fonte. Scostamento = 100 × (battito − baseline a riposo) / baseline. La baseline richiede 14 giorni precedenti, su 28. Movimento, emozioni e altri fattori possono cambiare il battito: lo scostamento non è un punteggio validato di stress. Sonno e attività sono marcati solo se importati; l’assenza di un allenamento non dimostra che eri a riposo. Non è monitoraggio continuo.").font(.caption).padding(.top,10)}.wellnessSurface()
        NavigationLink("Importare battito e parametri"){WellnessExtraImportGuide()}
    }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Stress e contesto")}
    private var summary:some View{VStack(alignment:.leading,spacing:12){
        Text("ULTIMA FINESTRA IMPORTATA").font(.caption2.bold()).tracking(1)
        HStack(alignment:.firstTextBaseline){Text(WellnessFormat.number(data.points.last?.relativePercent)).font(.system(size:54,weight:.bold,design:.rounded)).foregroundStyle(.cyan);Text("% rispetto al riposo").font(.caption).foregroundStyle(.secondary)}
        HStack{Text(data.points.last.map{$0.date.formatted(date:.omitted,time:.shortened)} ?? "Nessun campione");Spacer();Text(data.points.last.map{WellnessFormat.number($0.bpm)+" bpm"} ?? "—")}.font(.subheadline)
        Text("Baseline a riposo: "+WellnessFormat.number(data.rest)+" bpm · \(data.restDays) giorni").font(.caption).foregroundStyle(.secondary)
    }.wellnessSurface()}
    private var plot:some View{VStack(alignment:.leading,spacing:16){
        Text(data.rest == nil ? "Battito importato":"Scostamento cardiaco").font(.headline)
        if data.points.isEmpty{ContentUnavailableView("Servono campioni di battito",systemImage:"waveform.path.ecg",description:Text("HRV e frequenza a riposo non descrivono l’intera giornata."))}
        else{let start=Calendar.current.startOfDay(for:date),end=Calendar.current.date(byAdding:.day,value:1,to:start)!
            Chart(data.points){p in BarMark(x:.value("Ora",p.date),y:.value(data.rest == nil ? "bpm":"%",p.relativePercent ?? p.bpm),width:.fixed(5)).foregroundStyle(p.context=="Sonno importato" ? Color.indigo:p.context=="Allenamento importato" ? Color.mint:Color.cyan)}
                .chartXScale(domain:start...end).chartXAxis{AxisMarks(values:.stride(by:.hour,count:6)){AxisValueLabel(format:.dateTime.hour(.defaultDigits(amPM:.omitted)))}}.frame(height:210)
            Text("\(data.sampleCount) campioni · \(data.points.count) finestre osservate").font(.caption)
            Text("Gli spazi vuoti non sono periodi di calma: mancano campioni.").font(.caption2).foregroundStyle(.secondary)
        }
    }.wellnessSurface()}
    private var context:some View{VStack(alignment:.leading,spacing:12){
        Text("Il contesto che conosciamo").font(.headline)
        ForEach(["Sonno importato","Allenamento importato","Contesto non noto"],id:\.self){key in HStack{Circle().fill(key=="Sonno importato" ? Color.indigo:key=="Allenamento importato" ? Color.mint:Color.cyan).frame(width:8,height:8);Text(key);Spacer();Text("\(data.points.filter{$0.context==key}.count) finestre").monospacedDigit()}.font(.caption)}
        Text(data.source.isEmpty ? "Nessuna fonte disponibile":"Fonte battito: "+data.source).font(.caption2).foregroundStyle(.secondary)
    }.wellnessSurface()}
}
struct WellnessLoadView:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    @State private var days=30
    @State private var manual=false
    var load:WellnessLoad{WellnessAnalysis.load(store.wellness,on:date)}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        WellnessDetailHeading(eyebrow:"Training load",title:"Dai forma al tuo carico.",detail:"Durata × sforzo percepito. Giorni completi, confronti leggibili.",color:.mint)
        HStack{WellnessCard(title:"Breve termine",value:WellnessFormat.number(load.acute),unit:"7 giorni · UA/giorno");WellnessCard(title:"Lungo termine",value:WellnessFormat.number(load.chronic),unit:"28 giorni · UA/giorno")}
        Picker("Storico carico",selection:$days){Text("30 g").tag(30);Text("60 g").tag(60);Text("6 mesi").tag(180);Text("Anno").tag(365)}.pickerStyle(.segmented)
        history
        HStack{WellnessCard(title:"Rapporto 7 / 28",value:WellnessFormat.number(load.ratio),unit:"descrittivo");WellnessCard(title:"Copertura",value:"\(load.covered)/28",unit:"giorni completi")}
        Button("Registra allenamento",systemImage:"plus"){manual=true}.buttonStyle(.borderedProminent).tint(WellnessStyle.hrv)
        DisclosureGroup("Giornata e allenamenti"){WellnessTraining(date:date).padding(.top,12)}.wellnessSurface()
        Text("Le medie compaiono solo quando tutti i giorni della finestra sono confermati, compresi i riposi. RPE mancante non vale zero. Il rapporto non stima rischio di infortunio o capacità di allenarti.").font(.caption).foregroundStyle(.secondary)
    }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Carico").sheet(isPresented:$manual){WellnessManual(kind:.workout)}}
    private var history:some View{
        let points=WellnessInsights.loadHistory(store.wellness,on:date,days:days)
        return VStack(alignment:.leading,spacing:16){Text("La tua traiettoria").font(.headline)
            if !points.contains(where:{$0.acute != nil || $0.chronic != nil}){ContentUnavailableView("Completa il registro",systemImage:"chart.xyaxis.line",description:Text("Servono almeno 7 giorni completi per la prima linea."))}
            else{Chart(points){p in
                if let value=p.acute{LineMark(x:.value("Giorno",p.date),y:.value("UA",value),series:.value("Segmento","breve\(p.acuteSegment)")).foregroundStyle(.cyan).lineStyle(StrokeStyle(lineWidth:2))}
                if let value=p.chronic{LineMark(x:.value("Giorno",p.date),y:.value("UA",value),series:.value("Segmento","lungo\(p.chronicSegment)")).foregroundStyle(.mint).lineStyle(StrokeStyle(lineWidth:3))}
            }.chartLegend(.hidden).frame(height:210)}
            HStack{Label("7 giorni",systemImage:"minus").foregroundStyle(.cyan);Spacer();Label("28 giorni",systemImage:"minus").foregroundStyle(.mint)}.font(.caption)
            Text("Le linee si interrompono dove la copertura è incompleta.").font(.caption2).foregroundStyle(.secondary)
        }.wellnessSurface()
    }
}
struct WellnessMonitorView:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    var vitals:[WellnessVital]{WellnessInsights.vitalMetrics.map{WellnessInsights.vital(store.wellness,metric:$0,on:date)}}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        WellnessDetailHeading(eyebrow:"Health monitor",title:"Il tuo riferimento sei tu.",detail:"Confronti personali di HRV, riposo, respirazione, ossigenazione e temperatura.",color:.pink)
        VStack(alignment:.leading,spacing:12){Text("PANORAMICA").font(.caption2.bold()).tracking(1);Text(summary).font(.title2.bold());Text("Fasce statistiche personali, non intervalli clinici né previsione di malattia.").font(.caption).foregroundStyle(.secondary)}.wellnessSurface()
        ForEach(vitals){v in NavigationLink{WellnessVitalDetail(vital:v)}label:{VStack(alignment:.leading,spacing:12){
            HStack{Text(v.metric.title).font(.headline);Spacer();Image(systemName:"chevron.right").font(.caption)}
            HStack(alignment:.firstTextBaseline){Text(WellnessFormat.number(v.value)).font(.system(size:32,weight:.bold,design:.rounded));Text(v.metric.unit).foregroundStyle(.secondary)}
            HStack{Circle().fill(v.outside == nil ? Color.gray:v.outside == true ? Color.orange:Color.mint).frame(width:7,height:7);Text(v.outside == nil ? "Baseline: \(v.baselineDays)/14 giorni":v.outside == true ? "Fuori fascia personale":"Nella fascia personale").font(.caption)}
            WellnessSparkline(values:v.points,color:v.outside == true ? .orange:.mint)
        }.wellnessSurface()}.buttonStyle(.plain).accessibilityIdentifier("vital"+v.metric.rawValue)}
        NavigationLink("Importare i parametri mancanti"){WellnessExtraImportGuide()}
    }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Monitor salute")}
    private var summary:String{let known=vitals.filter{$0.outside != nil};return known.isEmpty ? "Baseline in costruzione":"\(known.filter{$0.outside==true}.count) fuori fascia · \(known.count)/5 confrontabili"}
}
struct WellnessVitalDetail:View {
    var vital:WellnessVital
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        WellnessCard(title:"Mediana del giorno",value:WellnessFormat.number(vital.value),unit:vital.metric.unit)
        VStack(alignment:.leading,spacing:16){Text("28 giorni e giorno selezionato").font(.headline)
            Chart(vital.points){p in PointMark(x:.value("Data",p.date),y:.value(vital.metric.unit,p.value)).foregroundStyle(.mint)
                if let lower=vital.lower,let upper=vital.upper{RuleMark(y:.value("Limite inferiore",lower)).foregroundStyle(.secondary.opacity(0.35)).lineStyle(StrokeStyle(dash:[3,3]));RuleMark(y:.value("Limite superiore",upper)).foregroundStyle(.secondary.opacity(0.35)).lineStyle(StrokeStyle(dash:[3,3]))}
            }.chartYScale(domain:.automatic(includesZero:false)).frame(height:210)
            Text("Baseline: "+WellnessFormat.number(vital.baseline)+" "+vital.metric.unit).font(.headline)
            Text("Fascia: "+WellnessFormat.number(vital.lower)+" – "+WellnessFormat.number(vital.upper)+" "+vital.metric.unit).font(.caption)
            Text("Fonte: "+(vital.source.isEmpty ? "nessuna":vital.source)).font(.caption)
        }.wellnessSurface()
        Text("Mediana dei 28 giorni precedenti, almeno 14 osservazioni giornaliere della stessa fonte. Fascia = mediana ± 2 × dispersione robusta (1,4826 × MAD), con pavimenti di stabilità esplicitati nei metodi. HRV valutata in logaritmo. Il giorno scelto è escluso dalla baseline. Non indica valori clinicamente normali.").font(.caption).foregroundStyle(.secondary)
    }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle(vital.metric.title)}
}
struct WellnessAdvancedSleep:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    @State private var planning=false
    var data:WellnessNightInsights{WellnessInsights.night(store.wellness,on:date)}
    var body:some View{VStack(alignment:.leading,spacing:18){
        HStack(alignment:.top){WellnessCard(title:"REM + profondo osservati",value:data.restorativeSeconds.map{WellnessFormat.hours($0)} ?? "—",unit:data.classifiedSeconds>0 ? "quote classificate":"Fasi non disponibili");WellnessCard(title:"Veglia durante la notte",value:data.sleep.seconds>0 ? WellnessFormat.hours(data.awakeWithinSleep):"—",unit:"\(data.awakenings) intervalli osservati")}
        if data.sleep.seconds>0{Text("Fasi specifiche: \(Int(100*data.classifiedSeconds/data.sleep.seconds))% del sonno importato. La quota generica non viene assegnata a REM o profondo.").font(.caption).foregroundStyle(.secondary)}
        VStack(alignment:.leading,spacing:16){
            Label("IL PIANO DELLA PROSSIMA NOTTE",systemImage:"moon.zzz.fill").font(.caption2.bold()).tracking(1).foregroundStyle(.indigo)
            Text(WellnessFormat.hours(data.targetSeconds)).font(.system(size:36,weight:.bold,design:.rounded))
            HStack{VStack(alignment:.leading){Text("A letto alle").font(.caption);Text(data.bedtime.formatted(date:.omitted,time:.shortened)).font(.title2.bold())};Spacer();VStack(alignment:.trailing){Text("Sveglia").font(.caption);Text(data.wake.formatted(date:.omitted,time:.shortened)).font(.title2.bold())}}
            Text("Base: \(store.wellness.preferences.sleepGoal.formatted()) h · extra pianificato: \(Int(data.extraSeconds/60)) min").font(.caption)
            Text("Deficit osservato: \(WellnessFormat.hours(data.observedDeficit)) su \(data.availableNights) notti importate delle ultime 7.").font(.caption).foregroundStyle(.secondary)
            Button("Personalizza il piano"){planning=true}.buttonStyle(.bordered)
            Text("Piano organizzativo, non previsione del fabbisogno biologico. Extra = deficit medio osservato, arrotondato a 15 min, massimo 60 min e almeno 3 notti; totale massimo 12 h. Puoi disattivarlo.").font(.caption2).foregroundStyle(.secondary)
        }.wellnessSurface()
    }.sheet(isPresented:$planning){WellnessSleepPlanning()}}
}
struct WellnessSleepPlanning:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) var dismiss
    var plan:WellnessSleepPlan{store.wellness.preferences.sleepPlan ?? WellnessSleepPlan()}
    var body:some View{NavigationStack{Form{
        Section("I tuoi orari"){DatePicker("Sveglia",selection:Binding(get:{Calendar.current.date(bySettingHour:plan.wakeMinute/60,minute:plan.wakeMinute%60,second:0,of:Date()) ?? Date()},set:{d in update{p in p.wakeMinute=Calendar.current.component(.hour,from:d)*60+Calendar.current.component(.minute,from:d)}}),displayedComponents:.hourAndMinute)
            Stepper("Tempo per addormentarti: \(Int(plan.latencyMinutes)) min",value:Binding(get:{plan.latencyMinutes},set:{v in update{$0.latencyMinutes=v}}),in:0...120,step:5)
            Toggle("Aggiungi parte del deficit osservato",isOn:Binding(get:{plan.compensateDeficit},set:{v in update{$0.compensateDeficit=v}}))
        }
        Text("L’obiettivo base si modifica in Preferenze Salute. Questo piano aiuta a organizzare gli orari; non prescrive quanto devi dormire.").font(.caption)
    }.navigationTitle("Pianifica la notte").toolbar{ToolbarItem(placement:.confirmationAction){Button("Fine"){dismiss()}}}}}
    private func update(_ change:(inout WellnessSleepPlan)->Void){var next=plan;change(&next);let value=next;store.wellnessChange{$0.preferences.sleepPlan=value}}
}
struct WellnessSummaryGallery:View {
    @EnvironmentObject var store:HabitStore
    var date:Date
    var body:some View{let s=WellnessInsights.snapshot(store.wellness,on:date)
        ScrollView{VStack(alignment:.leading,spacing:20){
            WellnessDetailHeading(eyebrow:"Riepiloghi",title:"Tutto, a colpo d’occhio.",detail:"Schede con i tuoi dati locali, disponibili anche qui senza estensioni.",color:.indigo)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){
                WellnessCard(title:"Recupero sperimentale",value:WellnessFormat.number(s.recovery),unit:"indice su 100")
                WellnessCard(title:"Piano sonno",value:WellnessFormat.hours(s.targetSeconds),unit:"a letto "+s.bedtime.formatted(date:.omitted,time:.shortened))
                WellnessCard(title:"HRV · SDNN",value:WellnessFormat.number(s.hrv),unit:"ms · giorno scelto")
                WellnessCard(title:"Carico breve",value:WellnessFormat.number(s.load7),unit:"UA/giorno · 7 giorni")
            }
            VStack(alignment:.leading,spacing:14){Label("Widget della schermata Home",systemImage:"square.grid.2x2").font(.headline)
                Text(store.shared ? "Archivio App Group disponibile. I widget richiedono la versione con estensione inclusa e firmata.":"Questa installazione non dispone dell’App Group firmato. Le schede qui sopra funzionano; i widget Home richiedono la build con estensione e profili compatibili.").font(.subheadline)
                Toggle("Condividi i riepiloghi con i widget",isOn:Binding(get:{store.wellness.preferences.widgetsEnabled==true},set:{v in store.wellnessChange{$0.preferences.widgetsEnabled=v}})).disabled(!store.shared)
                Text("Condivisione disattivata per impostazione iniziale. Le schede possono mostrare dati sanitari sulla Home; non vengono inviati online. Il refresh dipende da iOS e dall’importazione.").font(.caption).foregroundStyle(.secondary)
            }.wellnessSurface()
        }.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Riepiloghi e widget")
    }
}
struct WellnessExtraImportGuide:View {
    var body:some View{WellnessHealthXMLView()}
}
