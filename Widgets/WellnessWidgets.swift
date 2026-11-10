import SwiftUI
import WidgetKit

struct WellnessWidgetEntry:TimelineEntry{var date:Date;var snapshot:WellnessWidgetSnapshot?}
struct WellnessWidgetProvider:TimelineProvider {
    func placeholder(in context:Context)->WellnessWidgetEntry{.init(date:Date(),snapshot:nil)}
    func getSnapshot(in context:Context,completion:@escaping(WellnessWidgetEntry)->Void){completion(entry())}
    func getTimeline(in context:Context,completion:@escaping(Timeline<WellnessWidgetEntry>)->Void){completion(Timeline(entries:[entry()],policy:.after(Date().addingTimeInterval(1800))))}
    private func entry()->WellnessWidgetEntry{.init(date:Date(),snapshot:WellnessWidgetBridge.read())}
}
struct WellnessNativeWidgetView:View {
    var entry:WellnessWidgetEntry;var type:String
    @Environment(\.widgetFamily) var family
    var title:String{switch type{case "sleep":return "Piano sonno";case "vitals":return "HRV e riposo";case "load":return "Carico";default:return "Recupero"}}
    var body:some View {
        VStack(alignment:.leading,spacing:8){
            Label(title,systemImage:type=="sleep" ? "moon.stars.fill":type=="load" ? "chart.xyaxis.line":"heart.fill").font(.caption.bold()).foregroundStyle(.mint)
            if let s=entry.snapshot {
                if !Calendar.current.isDate(s.date,inSameDayAs:entry.date){Text("Apri il quaderno per aggiornare").font(.caption)}
                else{content(s)}
                if let last=s.lastImport,family != .accessoryCircular{Text("Importato "+last.formatted(date:.abbreviated,time:.shortened)).font(.system(size:9)).foregroundStyle(.secondary).lineLimit(2)}
            }else{Text("Apri Salute → Riepiloghi e abilita la condivisione.").font(.caption)}
        }.frame(maxWidth:.infinity,alignment:.leading).containerBackground(for:.widget){Color(red:0.06,green:0.12,blue:0.17)}.foregroundStyle(.white).privacySensitive().widgetURL(URL(string:"abitudinilocale://wellness"))
    }
    @ViewBuilder private func content(_ s:WellnessWidgetSnapshot)->some View {
        switch type {
        case "sleep":Text(duration(s.targetSeconds)).font(.system(.title2,design:.rounded,weight:.bold));Text("A letto "+s.bedtime.formatted(date:.omitted,time:.shortened)).font(.caption)
        case "vitals":Text(number(s.hrv)+" ms").font(.system(.title2,design:.rounded,weight:.bold));Text(number(s.rest)+" bpm a riposo").font(.caption)
        case "load":Text(number(s.load7)).font(.system(.title2,design:.rounded,weight:.bold));Text("7 giorni · UA/giorno").font(.caption);if family != .accessoryCircular{Text("28 giorni: "+number(s.load28)+" · \(s.coverage)/28 completi").font(.caption2)}
        default:Text(s.recovery.map{String(Int($0.rounded()))} ?? "—").font(.system(size:40,weight:.bold,design:.rounded));Text("Indice sperimentale / 100").font(.caption2)
        }
    }
    private func number(_ d:Double?)->String{d.map{$0.formatted(.number.precision(.fractionLength(1)))} ?? "—"}
    private func duration(_ s:Double)->String{let m=Int(s/60);return "\(m/60) h \(m%60) min"}
}
struct RecoveryWellnessWidget:Widget {var body:some WidgetConfiguration{StaticConfiguration(kind:"QuadernoRecovery",provider:WellnessWidgetProvider()){WellnessNativeWidgetView(entry:$0,type:"recovery")}.configurationDisplayName("Recupero locale").description("Indice sperimentale dai campioni importati.").supportedFamilies([.systemSmall,.systemMedium,.accessoryRectangular])}}
struct SleepWellnessWidget:Widget {var body:some WidgetConfiguration{StaticConfiguration(kind:"QuadernoSleep",provider:WellnessWidgetProvider()){WellnessNativeWidgetView(entry:$0,type:"sleep")}.configurationDisplayName("Piano sonno locale").description("Obiettivo organizzativo e ora per andare a letto.").supportedFamilies([.systemSmall,.systemMedium,.accessoryRectangular])}}
struct VitalsWellnessWidget:Widget {var body:some WidgetConfiguration{StaticConfiguration(kind:"QuadernoVitals",provider:WellnessWidgetProvider()){WellnessNativeWidgetView(entry:$0,type:"vitals")}.configurationDisplayName("HRV e riposo locali").description("Le mediane del giorno importate nel quaderno.").supportedFamilies([.systemSmall,.systemMedium,.accessoryRectangular])}}
struct LoadWellnessWidget:Widget {var body:some WidgetConfiguration{StaticConfiguration(kind:"QuadernoLoad",provider:WellnessWidgetProvider()){WellnessNativeWidgetView(entry:$0,type:"load")}.configurationDisplayName("Carico locale").description("Medie 7 e 28 giorni con copertura confermata.").supportedFamilies([.systemSmall,.systemMedium,.accessoryRectangular])}}
