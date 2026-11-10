import Foundation

struct WellnessSleepPlan:Codable,Equatable {
    var wakeMinute=420
    var latencyMinutes=20.0
    var compensateDeficit=true
    var valid:Bool{(0..<1440).contains(wakeMinute) && latencyMinutes.isFinite && (0...120).contains(latencyMinutes)}
}
struct WellnessNightInsights {
    var sleep:WellnessSleep;var classifiedSeconds:Double;var restorativeSeconds:Double?
    var awakeWithinSleep:Double;var awakenings:Int;var availableNights:Int;var averageSleep:Double?
    var observedDeficit:Double;var targetSeconds:Double;var extraSeconds:Double;var bedtime:Date;var wake:Date
}
struct WellnessVital:Identifiable {
    var metric:WellnessMetric;var value:Double?;var source:String
    var baseline:Double?;var lower:Double?;var upper:Double?;var z:Double?
    var baselineDays:Int;var points:[WellnessPoint];var id:String{metric.rawValue}
    var outside:Bool?{guard let v=value,let l=lower,let u=upper else{return nil};return v<l || v>u}
}
struct WellnessActivationPoint:Identifiable {
    var date:Date;var bpm:Double;var relativePercent:Double?;var samples:Int;var context:String;var id:Date{date}
}
struct WellnessActivation {
    var points:[WellnessActivationPoint];var rest:Double?;var source:String;var restDays:Int
    var sampleCount:Int{points.reduce(0){$0+$1.samples}}
    var meanRelative:Double?{WellnessAnalysis.mean(points.compactMap(\.relativePercent))}
}
struct WellnessLoadPoint:Identifiable {
    var date:Date;var acute:Double?;var chronic:Double?;var ratio:Double?
    var acuteSegment:Int;var chronicSegment:Int;var id:Date{date}
}
struct WellnessWidgetSnapshot:Codable {
    var date:Date;var lastImport:Date?;var recovery:Double?;var hrv:Double?;var rest:Double?
    var sleepSeconds:Double?;var targetSeconds:Double;var bedtime:Date
    var load7:Double?;var load28:Double?;var coverage:Int
}
enum WellnessInsights {
    static let vitalMetrics:[WellnessMetric]=[.hrv,.rhr,.respiration,.oxygen,.temperature]
    static func vital(_ a:WellnessArchive,metric:WellnessMetric,on date:Date,calendar:Calendar = .current)->WellnessVital {
        let day=calendar.startOfDay(for:date),end=calendar.date(byAdding:.day,value:1,to:day)!,begin=calendar.date(byAdding:.day,value:-28,to:day)!
        let eligible=WellnessAnalysis.records(a,metric:metric).filter{$0.start<end && $0.start>=begin}
        let source=eligible.sorted{l,r in l.start==r.start ? l.source<r.source:l.start>r.start}.first?.source ?? ""
        var subset=a;subset.records.removeAll{$0.metric==metric && $0.source != source}
        let points=WellnessAnalysis.daily(subset,metric:metric,calendar:calendar).filter{$0.date>=begin && $0.date<end}
        let past=points.filter{$0.date<day},current=points.first{calendar.isDate($0.date,inSameDayAs:date)}?.value
        var result=WellnessVital(metric:metric,value:current,source:source,baseline:nil,lower:nil,upper:nil,z:nil,baselineDays:past.count,points:points)
        guard past.count>=14 else{return result}
        let values=past.map{metric == .hrv ? log($0.value):$0.value},center=WellnessAnalysis.median(past.map{metric == .hrv ? log($0.value):$0.value})!
        let floor:Double
        switch metric{case .hrv:floor=0.05;case .rhr:floor=2;case .respiration:floor=0.5;case .oxygen:floor=0.5;case .temperature:floor=0.1;default:floor=1}
        let scale=max(floor,1.4826*(WellnessAnalysis.median(values.map{abs($0-center)}) ?? 0))
        result.baseline=metric == .hrv ? exp(center):center
        result.lower=metric == .hrv ? exp(center-2*scale):center-2*scale
        result.upper=metric == .hrv ? exp(center+2*scale):center+2*scale
        result.z=current.map{((metric == .hrv ? log($0):$0)-center)/scale}
        return result
    }
    static func activation(_ a:WellnessArchive,on date:Date,calendar:Calendar = .current)->WellnessActivation {
        let day=calendar.startOfDay(for:date),end=calendar.date(byAdding:.day,value:1,to:day)!
        let raw=a.records.filter{$0.metric == .heart && $0.start>=day && $0.start<end}
        let source=raw.sorted{l,r in l.start==r.start ? l.source<r.source:l.start>r.start}.first?.source ?? ""
        let samples=raw.filter{$0.source==source},r=vital(a,metric:.rhr,on:date,calendar:calendar)
        let intervals=[date,calendar.date(byAdding:.day,value:1,to:date)!].flatMap{WellnessAnalysis.sleep(a,on:$0,calendar:calendar).timeline.filter{$0.phase.sleeping}}
        let workouts=a.records.filter{$0.metric == .workout && $0.start<end && $0.end>day}
        let groups=Dictionary(grouping:samples){calendar.dateInterval(of:.hour,for:$0.start)!.start.addingTimeInterval(Double(calendar.component(.minute,from:$0.start)/15)*900)}
        let points=groups.map{time,values -> WellnessActivationPoint in
            let bpm=WellnessAnalysis.median(values.map(\.value))!
            let context:String
            if values.allSatisfy({r in workouts.contains{r.start >= $0.start && r.start<$0.end.addingTimeInterval(1200)}}){context="Allenamento importato"}
            else if values.allSatisfy({r in intervals.contains{r.start >= $0.start && r.start<$0.end}}){context="Sonno importato"}
            else{context="Contesto non noto"}
            return .init(date:time,bpm:bpm,relativePercent:r.baseline.map{100*(bpm-$0)/$0},samples:values.count,context:context)
        }.sorted{$0.date<$1.date}
        return .init(points:points,rest:r.baseline,source:source,restDays:r.baselineDays)
    }
    static func night(_ a:WellnessArchive,on date:Date,calendar:Calendar = .current)->WellnessNightInsights {
        let s=WellnessAnalysis.sleep(a,on:date,calendar:calendar)
        let specific=[WellnessPhase.core,.deep,.rem].reduce(0){$0+(s.phases[$1.rawValue] ?? 0)}
        let restorative=specific>0 ? (s.phases[WellnessPhase.deep.rawValue] ?? 0)+(s.phases[WellnessPhase.rem.rawValue] ?? 0):nil
        var merged:[DateInterval]=[]
        if let start=s.start,let end=s.end {
            let spans=s.timeline.filter{$0.phase == .awake && $0.start<end && $0.end>start}.map{DateInterval(start:max(start,$0.start),end:min(end,$0.end))}.sorted{$0.start<$1.start}
            for span in spans{if let last=merged.last,span.start<=last.end{merged[merged.count-1]=DateInterval(start:last.start,end:max(last.end,span.end))}else{merged.append(span)}}
        }
        let recent=(0..<7).map{WellnessAnalysis.sleep(a,on:calendar.date(byAdding:.day,value:-$0,to:date)!,calendar:calendar)}.filter{$0.seconds>0}
        let goal=a.preferences.sleepGoal*3600,deficit=recent.reduce(0){$0+max(0,goal-$1.seconds)}
        let plan=a.preferences.sleepPlan ?? WellnessSleepPlan()
        let extra=plan.compensateDeficit && recent.count>=3 ? min(3600,ceil((deficit/Double(recent.count))/900)*900):0
        let target=min(12*3600,goal+extra),next=calendar.date(byAdding:.day,value:1,to:calendar.startOfDay(for:date))!
        let wake=calendar.date(bySettingHour:plan.wakeMinute/60,minute:plan.wakeMinute%60,second:0,of:next)!
        return .init(sleep:s,classifiedSeconds:specific,restorativeSeconds:restorative,awakeWithinSleep:merged.reduce(0){$0+$1.duration},awakenings:merged.count,availableNights:recent.count,averageSleep:WellnessAnalysis.mean(recent.map(\.seconds)),observedDeficit:deficit,targetSeconds:target,extraSeconds:max(0,target-goal),bedtime:wake.addingTimeInterval(-target-plan.latencyMinutes*60),wake:wake)
    }
    static func loadHistory(_ a:WellnessArchive,on date:Date,days:Int,calendar:Calendar = .current)->[WellnessLoadPoint]{
        let count=max(1,min(366,days)),end=calendar.startOfDay(for:date),begin=calendar.date(byAdding:.day,value:-(max(1,min(366,days))+27),to:calendar.startOfDay(for:date))!
        let sessions=Dictionary(grouping:a.records.filter{$0.metric == .workout && $0.start>=begin && $0.start<calendar.date(byAdding:.day,value:1,to:end)!}){calendar.startOfDay(for:$0.start)}
        let confirmed=Set(a.confirmedTrainingDays);var loads:[Date:Double]=[:]
        for offset in 0..<(count+28){let d=calendar.date(byAdding:.day,value:-offset,to:end)!,items=sessions[d] ?? [];if confirmed.contains(WellnessAnalysis.day(d,calendar:calendar)) && items.allSatisfy({$0.rpe != nil}){loads[d]=items.reduce(0){$0+$1.end.timeIntervalSince($1.start)/60*$1.rpe!}}}
        var rows:[WellnessLoadPoint]=[],acuteSegment=0,chronicSegment=0,lastA=false,lastC=false
        for offset in (0..<count).reversed(){let d=calendar.date(byAdding:.day,value:-offset,to:end)!
            let values=(0..<28).map{loads[calendar.date(byAdding:.day,value:-$0,to:d)!]},week=(0..<7).map{loads[calendar.date(byAdding:.day,value:-$0,to:d)!]}
            let a=week.allSatisfy{$0 != nil} ? WellnessAnalysis.mean(week.compactMap{$0}):nil,c=values.allSatisfy{$0 != nil} ? WellnessAnalysis.mean(values.compactMap{$0}):nil
            if a != nil && !lastA{acuteSegment+=1};if c != nil && !lastC{chronicSegment+=1};lastA=a != nil;lastC=c != nil
            rows.append(.init(date:d,acute:a,chronic:c,ratio:c != nil && c!>0 ? a!/c!:nil,acuteSegment:acuteSegment,chronicSegment:chronicSegment))
        }
        return rows
    }
    static func snapshot(_ a:WellnessArchive,on date:Date)->WellnessWidgetSnapshot{
        let n=night(a,on:date),l=WellnessAnalysis.load(a,on:date)
        return .init(date:date,lastImport:a.records.map(\.imported).max(),recovery:WellnessAnalysis.readiness(a,on:date).score,hrv:vital(a,metric:.hrv,on:date).value,rest:vital(a,metric:.rhr,on:date).value,sleepSeconds:n.sleep.seconds>0 ? n.sleep.seconds:nil,targetSeconds:n.targetSeconds,bedtime:n.bedtime,load7:l.acute,load28:l.chronic,coverage:l.covered)
    }
}
