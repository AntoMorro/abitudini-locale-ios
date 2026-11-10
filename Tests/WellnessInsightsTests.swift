import XCTest
@testable import HabitCore
final class WellnessInsightsTests:XCTestCase {
    var cal:Calendar{var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(secondsFromGMT:0)!;return c}
    let day=Date(timeIntervalSince1970:1_760_000_000)
    func date(_ offset:Int)->Date{cal.date(byAdding:.day,value:offset,to:cal.startOfDay(for:day))!}
    func record(_ metric:WellnessMetric,_ value:Double,_ offset:Int,source:String="Watch")->WellnessRecord{let d=date(offset).addingTimeInterval(3600);return .init(metric:metric,value:value,start:d,end:d,source:source)}
    func testLegacyPreferencesDecodeAndNewPlanRoundTrip()throws{
        let data=try JSONEncoder().encode(WellnessPreferences());let old=try JSONDecoder().decode(WellnessPreferences.self,from:data)
        XCTAssertNil(old.sleepPlan);XCTAssertNil(old.widgetsEnabled)
        var a=WellnessArchive();a.preferences.sleepPlan=WellnessSleepPlan();a.preferences.widgetsEnabled=true
        let b=try JSONDecoder().decode(WellnessArchive.self,from:JSONEncoder().encode(a))
        XCTAssertEqual(b.preferences.sleepPlan,a.preferences.sleepPlan);XCTAssertEqual(b.preferences.widgetsEnabled,true)
        a.preferences.sleepPlan=WellnessSleepPlan(wakeMinute:1440);XCTAssertThrowsError(try a.validated())
    }
    func testVitalExcludesTodayAndDoesNotMixSources(){
        var a=WellnessArchive();a.records=(-20..<0).flatMap{[record(.rhr,60,$0),record(.rhr,120,$0,source:"Other")]};a.records.append(record(.rhr,70,0))
        let r=WellnessInsights.vital(a,metric:.rhr,on:day,calendar:cal)
        XCTAssertEqual(r.baseline,60);XCTAssertEqual(r.baselineDays,20);XCTAssertEqual(r.source,"Watch");XCTAssertEqual(r.value,70);XCTAssertEqual(r.outside,true)
    }
    func testInsufficientBaselineAndMissingDayRemainMissing(){
        var a=WellnessArchive();a.records=(-5..<0).map{record(.oxygen,97,$0)}
        let r=WellnessInsights.vital(a,metric:.oxygen,on:day,calendar:cal)
        XCTAssertNil(r.baseline);XCTAssertNil(r.value);XCTAssertNil(r.outside)
    }
    func testActivationHasGapsAndPreservesCounts(){
        var a=WellnessArchive();a.records=(-20..<0).map{record(.rhr,60,$0)};let t=date(0)
        a.records += [.init(metric:.heart,value:90,start:t,end:t,source:"Watch"),.init(metric:.heart,value:100,start:t.addingTimeInterval(120),end:t.addingTimeInterval(120),source:"Watch"),.init(metric:.heart,value:60,start:t.addingTimeInterval(3600),end:t.addingTimeInterval(3600),source:"Watch")]
        let r=WellnessInsights.activation(a,on:day,calendar:cal)
        XCTAssertEqual(r.points.count,2);XCTAssertEqual(r.sampleCount,3);XCTAssertEqual(r.points[0].bpm,95);XCTAssertEqual(r.points[0].relativePercent!,100*35/60,accuracy:0.001)
        XCTAssertEqual(r.points[0].context,"Contesto non noto")
    }
    func testPartialBinIsNotClassifiedEntirelyAsTraining(){
        var a=WellnessArchive();let t=date(0)
        a.records=[.init(metric:.heart,value:80,start:t,end:t,source:"Watch"),.init(metric:.heart,value:85,start:t.addingTimeInterval(600),end:t.addingTimeInterval(600),source:"Watch"),.init(metric:.workout,value:10,start:t.addingTimeInterval(300),end:t.addingTimeInterval(900),source:"Manuale",rpe:5)]
        XCTAssertEqual(WellnessInsights.activation(a,on:day,calendar:cal).points.first?.context,"Contesto non noto")
    }
    func testLoadHistoryAndCoverageGaps(){
        var a=WellnessArchive()
        for i in -65...0{let d=date(i);a.confirmedTrainingDays.append(WellnessAnalysis.day(d,calendar:cal));a.records.append(.init(metric:.workout,value:30,start:d,end:d.addingTimeInterval(1800),source:"Manuale",rpe:5))}
        var h=WellnessInsights.loadHistory(a,on:day,days:30,calendar:cal)
        XCTAssertEqual(h.last?.acute,150);XCTAssertEqual(h.last?.chronic,150);XCTAssertEqual(h.last?.ratio,1)
        a.confirmedTrainingDays.removeAll{$0==WellnessAnalysis.day(date(-10),calendar:cal)}
        h=WellnessInsights.loadHistory(a,on:day,days:30,calendar:cal)
        XCTAssertNil(h.last?.chronic);XCTAssertEqual(h.last?.acute,150);XCTAssertNil(h.first{$0.date==date(-9)}?.acute)
        XCTAssertGreaterThan(h.last!.acuteSegment,h.first!.acuteSegment)
    }
    func testMissingRPEIsNotZero(){
        var a=WellnessArchive();for i in -30...0{a.confirmedTrainingDays.append(WellnessAnalysis.day(date(i),calendar:cal))}
        let d=date(0);a.records=[.init(metric:.workout,value:30,start:d,end:d.addingTimeInterval(1800),source:"Manuale")]
        XCTAssertNil(WellnessInsights.loadHistory(a,on:day,days:1,calendar:cal).first?.acute)
    }
    func testUnspecifiedSleepDoesNotBecomeRestorative(){
        var a=WellnessArchive();let t=date(0);a.records=[.init(metric:.sleep,value:60,start:t,end:t.addingTimeInterval(3600),source:"Watch",phase:.asleep)]
        let r=WellnessInsights.night(a,on:day,calendar:cal)
        XCTAssertNil(r.restorativeSeconds);XCTAssertEqual(r.classifiedSeconds,0);XCTAssertNil(r.sleep.efficiency)
    }
    func testAwakeWindowsAndPlanningCap(){
        var a=WellnessArchive();a.preferences.sleepGoal=8
        for i in -6...0{let t=date(i);a.records.append(.init(metric:.sleep,value:360,start:t,end:t.addingTimeInterval(6*3600),source:"Watch",phase:.core))}
        let t=date(0);a.records.append(.init(metric:.sleep,value:15,start:t.addingTimeInterval(3600),end:t.addingTimeInterval(4500),source:"Watch",phase:.awake))
        let r=WellnessInsights.night(a,on:day,calendar:cal)
        XCTAssertEqual(r.awakenings,1);XCTAssertEqual(r.awakeWithinSleep,900);XCTAssertEqual(r.extraSeconds,3600);XCTAssertEqual(r.targetSeconds,9*3600)
        XCTAssertEqual(r.wake.timeIntervalSince(r.bedtime),9*3600+1200)
    }
    func testPlanningKeepsElapsedDurationAcrossDST(){
        var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(identifier:"Europe/Rome")!
        let d=c.date(from:DateComponents(year:2026,month:3,day:28,hour:12))!
        var a=WellnessArchive();a.preferences.sleepPlan=WellnessSleepPlan(wakeMinute:420,latencyMinutes:20,compensateDeficit:false)
        let r=WellnessInsights.night(a,on:d,calendar:c)
        XCTAssertEqual(c.component(.hour,from:r.wake),7);XCTAssertEqual(r.wake.timeIntervalSince(r.bedtime),8*3600+1200)
    }
    func testMonitorUnitsAndAbsoluteTemperature()throws{
        let b64:(String)->String={Data($0.utf8).base64EncodedString()}
        let r=try WellnessImport.record(WellnessWire(type:.respiration,start:"2026-01-01T01:00:00Z",value64:b64("15 count/min"),unit64:b64("count/min")))
        XCTAssertEqual(r.value,15)
        let t=try WellnessImport.record(WellnessWire(type:.temperature,value:98.6,unit:"°F",start:"2026-01-01T01:00:00Z"))
        XCTAssertEqual(t.value,37,accuracy:0.001)
        XCTAssertThrowsError(try WellnessImport.record(WellnessWire(type:.temperature,value:0.3,unit:"°C",start:"2026-01-01T01:00:00Z")))
        let o=try WellnessImport.record(WellnessWire(type:.oxygen,value:0.97,unit:"fraction",start:"2026-01-01T01:00:00Z"))
        XCTAssertEqual(o.value,97);XCTAssertThrowsError(try WellnessImport.record(WellnessWire(type:.oxygen,value:0.97,unit:"%",start:"2026-01-01T01:00:00Z")))
    }
}
