import Foundation

struct WellnessPoint: Identifiable { var date:Date; var value:Double; var count:Int; var id:Date{date} }
struct WellnessSleepSpan:Identifiable {var start:Date;var end:Date;var phase:WellnessPhase;var id:String{String(start.timeIntervalSince1970)+phase.rawValue}}
struct WellnessSleep {
    var date:Date; var source:String; var phases:[String:Double]; var start:Date?;var end:Date?;var efficiency:Double?;var inBedSeconds:Double;var timeline:[WellnessSleepSpan]
    var seconds:Double { WellnessPhase.allCases.filter(\.sleeping).reduce(0){$0+(phases[$1.rawValue] ?? 0)} }
}
struct WellnessReadiness { var score:Double?;var reason:String;var hrvZ:Double?;var rhrZ:Double?;var baselineDays:Int }
struct WellnessLoad {var acute:Double?;var chronic:Double?;var ratio:Double?;var covered:Int;var monotony:Double?;var strain:Double?}
enum WellnessAnalysis {
    static func day(_ d:Date,calendar:Calendar = .current)->String{HabitEngine.day(d,calendar:calendar)}
    static func median(_ values:[Double])->Double?{let x=values.sorted();guard !x.isEmpty else{return nil};let n=x.count;return n%2==0 ? (x[n/2-1]+x[n/2])/2:x[n/2]}
    static func mean(_ x:[Double])->Double?{x.isEmpty ? nil:x.reduce(0,+)/Double(x.count)}
    static func deviation(_ x:[Double])->Double?{guard x.count>1,let m=mean(x) else{return nil};return sqrt(x.reduce(0){$0+pow($1-m,2)}/Double(x.count-1))}
    static func records(_ a:WellnessArchive,metric:WellnessMetric)->[WellnessRecord] {
        let source=metric == .hrv ? a.preferences.hrvSource:metric == .rhr ? a.preferences.rhrSource:metric == .sleep ? a.preferences.sleepSource:""
        return a.records.filter{$0.metric==metric && (source.isEmpty || $0.source==source)}
    }
    static func daily(_ a:WellnessArchive,metric:WellnessMetric,calendar:Calendar = .current)->[WellnessPoint] {
        var list=records(a,metric:metric)
        if metric == .hrv && a.preferences.nocturnalHRV {
            // Match actual imported asleep intervals, never infer that a clock hour was sleep.
            let sleeps=records(a,metric:.sleep).filter{$0.phase?.sleeping == true}
            list=list.filter{r in sleeps.contains{s in r.start>=s.start && r.start<s.end}}
        }
        let groups=Dictionary(grouping:list){ r in
            let d=calendar.startOfDay(for:r.start)
            return metric == .hrv && a.preferences.nocturnalHRV && calendar.component(.hour,from:r.start)>=12 ? calendar.date(byAdding:.day,value:1,to:d)!:d
        }
        return groups.map{date, values in
            let x=values.map(\.value)
            let value:Double
            if [.energy,.food,.steps].contains(metric) {value=x.reduce(0,+)} else {value=median(x) ?? 0}
            return WellnessPoint(date:date,value:value,count:values.count)
        }.sorted{$0.date<$1.date}
    }
    static func sleep(_ a:WellnessArchive,on date:Date,calendar:Calendar = .current)->WellnessSleep {
        let end=calendar.date(byAdding:.hour,value:12,to:calendar.startOfDay(for:date))!
        let begin=calendar.date(byAdding:.day,value:-1,to:end)!
        let all=records(a,metric:.sleep).filter{$0.start<end && $0.end>begin}
        let grouped=Dictionary(grouping:all,by: \.source)
        // A single source per night prevents Watch + another app from doubling sleep.
        let origin=grouped.keys.sorted().max { l,r in
            let ls=unionSeconds(grouped[l]!.filter{$0.phase?.sleeping==true}.map{DateInterval(start:max(begin,$0.start),end:min(end,$0.end))})
            let rs=unionSeconds(grouped[r]!.filter{$0.phase?.sleeping==true}.map{DateInterval(start:max(begin,$0.start),end:min(end,$0.end))})
            return ls==rs ? l>r:ls<rs
        } ?? ""
        let chosen=grouped[origin] ?? []
        let bounds=Array(Set(chosen.flatMap{[max(begin,$0.start),min(end,$0.end)]})).sorted()
        var phases:[String:Double]=[:],first:Date?,last:Date?,bed=0.0,sleepInBed=0.0
        var timeline:[WellnessSleepSpan]=[]
        if bounds.count>1 {for i in 0..<(bounds.count-1) {
            let l=bounds[i],r=bounds[i+1],mid=l.addingTimeInterval(r.timeIntervalSince(l)/2)
            let active=chosen.filter{$0.start<=mid && $0.end>mid};guard let phase=active.compactMap(\.phase).max(by:{$0.rank<$1.rank}) else{continue}
            let seconds=r.timeIntervalSince(l);phases[phase.rawValue,default:0]+=seconds;timeline.append(WellnessSleepSpan(start:l,end:r,phase:phase))
            let inBed=active.contains{$0.phase == .inBed};if inBed{bed+=seconds}
            if phase.sleeping {first=first ?? l;last=r;if inBed{sleepInBed+=seconds}}
        }}
        return WellnessSleep(date:date,source:origin,phases:phases,start:first,end:last,efficiency:bed>0 ? 100*sleepInBed/bed:nil,inBedSeconds:bed,timeline:timeline)
    }
    static func unionSeconds(_ intervals:[DateInterval])->Double {
        let sorted=intervals.sorted{$0.start<$1.start};guard var current=sorted.first else{return 0};var total=0.0
        for i in sorted.dropFirst(){if i.start<=current.end{current=DateInterval(start:current.start,end:max(current.end,i.end))}else{total+=current.duration;current=i}}
        return total+current.duration
    }
    static func readiness(_ a:WellnessArchive,on date:Date,calendar:Calendar = .current)->WellnessReadiness {
        let d=calendar.startOfDay(for:date),begin=calendar.date(byAdding:.day,value:-28,to:d)!
        let h=daily(a,metric:.hrv,calendar:calendar),r=daily(a,metric:.rhr,calendar:calendar)
        let hrange=h.filter{$0.date>=begin && $0.date<d},rrange=r.filter{$0.date>=begin && $0.date<d}
        let common=Set(hrange.map(\.date)).intersection(rrange.map(\.date))
        let hp=hrange.filter{common.contains($0.date)},rp=rrange.filter{common.contains($0.date)}
        let count=common.count
        func missing(_ why:String)->WellnessReadiness{.init(score:nil,reason:why,hrvZ:nil,rhrZ:nil,baselineDays:count)}
        guard count>=14 else{return missing("Baseline in costruzione: servono almeno 14 giorni precedenti con HRV e frequenza a riposo negli ultimi 28.")}
        guard let todayH=h.first(where:{$0.date==d}),let todayR=r.first(where:{$0.date==d}) else{return missing("Mancano HRV o frequenza a riposo per la data selezionata.")}
        for metric in [WellnessMetric.hrv,.rhr] {
            let sources=Set(records(a,metric:metric).filter{$0.start>=begin && $0.start<calendar.date(byAdding:.day,value:1,to:d)!}.map(\.source))
            if sources.count != 1{return missing("Seleziona una fonte coerente per HRV e frequenza a riposo nelle preferenze Salute.")}
        }
        let logs=hp.map{log($0.value)},rest=rp.map(\.value)
        let hm=median(logs)!,rm=median(rest)!
        let hz=(log(todayH.value)-hm)/max(0.05,1.4826*(median(logs.map{abs($0-hm)}) ?? 0))
        let rz=(todayR.value-rm)/max(2,1.4826*(median(rest.map{abs($0-rm)}) ?? 0))
        let clamp:(Double)->Double={max(-2,min(2,$0))}
        let score=max(0,min(100,50+15*clamp(hz)-15*clamp(rz)))
        let message=abs(hz)>2 || abs(rz)>2 ? "Variazione insolita rispetto alla tua baseline: controlla contesto, fonte e regolarità delle misure.":"Indice personale sperimentale, descrittivo: non misura una percentuale reale di recupero."
        return .init(score:score,reason:message,hrvZ:hz,rhrZ:rz,baselineDays:count)
    }
    static func load(_ a:WellnessArchive,on date:Date,calendar:Calendar = .current)->WellnessLoad {
        let end=calendar.startOfDay(for:date),confirmed=Set(a.confirmedTrainingDays)
        var values:[Double]=[],covered=0
        for i in 0..<28 {
            let d=calendar.date(byAdding:.day,value:-i,to:end)!,key=day(d,calendar:calendar)
            let sessions=a.records.filter{$0.metric == .workout && calendar.isDate($0.start,inSameDayAs:d)}
            let complete=confirmed.contains(key) && sessions.allSatisfy{$0.rpe != nil}
            if complete{covered+=1}
            values.append(complete ? sessions.reduce(0){$0+$1.end.timeIntervalSince($1.start)/60*$1.rpe!}:Double.nan)
        }
        let week=Array(values.prefix(7));let acute=week.allSatisfy(\.isFinite) ? mean(week):nil
        let chronic=covered==28 ? mean(values):nil
        let sd=deviation(week),monotony=acute != nil && (sd ?? 0)>0 ? acute!/sd!:nil
        return .init(acute:acute,chronic:chronic,ratio:chronic != nil && chronic!>0 ? acute!/chronic!:nil,covered:covered,monotony:monotony,strain:monotony.map{$0*week.reduce(0,+)})
    }
    static func circularMinuteDeviation(_ values:[Double])->Double? {
        guard values.count>=7 else{return nil}
        let angles=values.map{$0*2*Double.pi/1440}
        let x=mean(angles.map{cos($0)})!,y=mean(angles.map{sin($0)})!
        let radius=min(1,sqrt(x*x+y*y))
        guard radius>0.000001 else{return nil}
        return sqrt(-2*log(radius))*1440/(2*Double.pi)
    }
    static func correlation(_ pairs:[(Double,Double)])->Double? {
        guard pairs.count>=10,let x=mean(pairs.map(\.0)),let y=mean(pairs.map(\.1)) else{return nil}
        let xx=pairs.reduce(0){$0+pow($1.0-x,2)},yy=pairs.reduce(0){$0+pow($1.1-y,2)}
        guard xx>0,yy>0 else{return nil};return pairs.reduce(0){$0+($1.0-x)*($1.1-y)}/sqrt(xx*yy)
    }
}
