import SwiftUI
import Charts

enum WellnessStyle {
    static let ink = Color(red:0.08, green:0.14, blue:0.20)
    static let lime = Color(red:0.77, green:0.94, blue:0.43)
    static let hrv = Color(red:0.12, green:0.52, blue:0.43)
    static let rest = Color(red:0.82, green:0.31, blue:0.33)
    static let sleep = Color(red:0.40, green:0.37, blue:0.80)
    static func phase(_ p:WellnessPhase)->Color {
        switch p {case .inBed:return .gray;case .asleep:return .indigo;case .awake:return .orange;case .core:return .cyan;case .deep:return .indigo;case .rem:return .purple}
    }
}

struct WellnessSurface:ViewModifier {
    func body(content:Content)->some View {
        content.padding(20).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:26))
    }
}
extension View {func wellnessSurface()->some View{modifier(WellnessSurface())}}

struct WellnessRing:View {
    var progress:Double?
    var color:Color
    var title:String
    var subtitle:String
    var body:some View {
        ZStack {
            Circle().stroke(color.opacity(0.14),lineWidth:12)
            if let progress {Circle().trim(from:0,to:min(1,max(0,progress))).stroke(color,style:StrokeStyle(lineWidth:12,lineCap:.round)).rotationEffect(.degrees(-90))}
            VStack(spacing:2){Text(title).font(.system(size:35,weight:.bold,design:.rounded)).minimumScaleFactor(0.6);Text(subtitle).font(.caption2).foregroundStyle(.secondary)}.padding(18)
        }.frame(width:128,height:128).accessibilityElement(children:.ignore).accessibilityLabel(title+" "+subtitle)
    }
}

struct WellnessSparkline:View {
    var values:[WellnessPoint]
    var color:Color
    var body:some View {
        if !values.isEmpty {
            Chart(values){p in
                // Keep only observed days. No synthetic zeros or interpolated samples.
                BarMark(x:.value("Giorno",p.date,unit:.day),y:.value("Valore",p.value)).foregroundStyle(color.opacity(0.75)).cornerRadius(2)
            }.chartXAxis(.hidden).chartYAxis(.hidden).frame(height:42).accessibilityHidden(true)
        } else {HStack(spacing:4){ForEach(0..<12,id:\.self){_ in Capsule().fill(color.opacity(0.12)).frame(height:3)}}.frame(height:42).accessibilityHidden(true)}
    }
}

struct WellnessMetricTile:View {
    var title:String
    var symbol:String
    var value:String
    var unit:String
    var color:Color
    var points:[WellnessPoint]
    var body:some View {
        VStack(alignment:.leading,spacing:12){
            Label(title,systemImage:symbol).font(.caption.weight(.semibold)).foregroundStyle(color)
            VStack(alignment:.leading,spacing:2){Text(value).font(.system(size:31,weight:.bold,design:.rounded)).minimumScaleFactor(0.7);Text(unit).font(.caption).foregroundStyle(.secondary)}
            WellnessSparkline(values:points,color:color)
            Text("Ultimi 7 giorni").font(.caption2).foregroundStyle(.secondary)
        }.wellnessSurface()
    }
}

struct WellnessRecoveryHero:View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var readiness:WellnessReadiness
    var body:some View {
        Group {
            if typeSize.isAccessibilitySize {VStack(alignment:.leading,spacing:20){copy;ring.frame(maxWidth:.infinity)}}
            else {HStack(spacing:16){copy;ring}}
        }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
            .foregroundStyle(.white).background(WellnessStyle.ink.gradient,in:RoundedRectangle(cornerRadius:30))
    }
    private var copy:some View {VStack(alignment:.leading,spacing:10){
        HStack(spacing:6){Circle().fill(WellnessStyle.lime).frame(width:6,height:6);Text("IL TUO RECUPERO").font(.caption2.weight(.bold)).tracking(1.6)}.foregroundStyle(WellnessStyle.lime)
        Text(readiness.score == nil ? "Ogni giorno\nconta.":"Ascolta il\ntuo ritmo.").font(.system(size:28,weight:.bold,design:.rounded)).fixedSize(horizontal:false,vertical:true)
        Text(readiness.score == nil ? "\(readiness.baselineDays) / 14 giorni di baseline":"Indice personale · sperimentale").font(.caption).foregroundStyle(.white.opacity(0.75))
        Label("Esplora il recupero",systemImage:"arrow.up.right").font(.caption.weight(.semibold)).padding(.top,4)
    }.frame(minWidth:110,maxWidth:.infinity,alignment:.leading)}
    private var ring:some View {ZStack{
        Circle().stroke(.white.opacity(0.12),lineWidth:11)
        if let score=readiness.score{Circle().trim(from:0,to:min(1,max(0,score/100))).stroke(WellnessStyle.lime,style:StrokeStyle(lineWidth:11,lineCap:.round)).rotationEffect(.degrees(-90))}
        VStack(spacing:2){Text(readiness.score.map{String(Int($0.rounded()))} ?? "—").font(.system(size:44,weight:.bold,design:.rounded));Text(readiness.score == nil ? "in costruzione":"su 100").font(.caption2).foregroundStyle(.white.opacity(0.7))}
    }.frame(width:118,height:118).accessibilityElement(children:.ignore).accessibilityLabel(readiness.score.map{"Recupero sperimentale \(Int($0)) su 100"} ?? "Baseline in costruzione")}
}

struct WellnessUtilityRow:View {
    var title:String;var subtitle:String;var symbol:String;var color:Color = .secondary
    var body:some View {HStack(spacing:14){Image(systemName:symbol).font(.title3).foregroundStyle(color).frame(width:40,height:40).background(color.opacity(0.1),in:RoundedRectangle(cornerRadius:12));VStack(alignment:.leading,spacing:3){Text(title).font(.subheadline.weight(.semibold));Text(subtitle).font(.caption).foregroundStyle(.secondary)};Spacer(minLength:4);Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)}.padding(16).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:20))}
}

// Simulator-only fixtures live in an isolated --ui-testing repository.
#if DEBUG
extension HabitStore {
    func seedWellnessPreview(){
        guard HabitEnvironment.testing,ProcessInfo.processInfo.arguments.contains("--wellness-preview") else{return}
        change {db in db.theme=ProcessInfo.processInfo.arguments.contains("--wellness-dark") ? "dark":"light"}
        wellnessChange {a in
            a=WellnessArchive();let cal=Calendar.current,now=Date()
            for i in 0..<30 {
                let day=cal.date(byAdding:.day,value:-i,to:cal.startOfDay(for:now))!
                let time=min(day.addingTimeInterval(10*3600),now.addingTimeInterval(-60))
                let h=48+Double((i*7)%19),r=54+Double((i*3)%8)
                var samples=[WellnessRecord(metric:.hrv,value:h,start:time,end:time,source:"Dati dimostrativi"),WellnessRecord(metric:.rhr,value:r,start:time,end:time,source:"Dati dimostrativi")]
                let begin=day.addingTimeInterval(-3600),durations:[(WellnessPhase,Double)]=[(.core,100),(.deep,65),(.rem,45),(.awake,12),(.core,120),(.rem,65),(.core,35)]
                var cursor=begin
                for (phase,minutes) in durations {let end=cursor.addingTimeInterval(minutes*60);if end<now{samples.append(WellnessRecord(metric:.sleep,value:minutes,start:cursor,end:end,source:"Dati dimostrativi",phase:phase))};cursor=end}
                try a.merge(samples)
            }
        }
    }
}
#endif
