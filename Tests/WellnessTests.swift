import XCTest
@testable import HabitCore

final class WellnessTests:XCTestCase {
    var cal:Calendar {var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(identifier:"Europe/Rome")!;return c}
    func date(_ day:Int,_ hour:Int=8)->Date{cal.date(from:DateComponents(year:2026,month:1,day:day,hour:hour))!}
    func record(_ metric:WellnessMetric,_ value:Double,_ d:Date,source:String="Watch")->WellnessRecord{WellnessRecord(metric:metric,value:value,start:d,end:d,source:source)}
    func segment(_ a:Date,_ b:Date,_ phase:WellnessPhase,source:String="Watch")->WellnessRecord{WellnessRecord(metric:.sleep,value:b.timeIntervalSince(a)/60,start:a,end:b,source:source,phase:phase)}
    func testLegacyBackupsDecodeWithoutWellness()throws{
        let data=try JSONEncoder().encode(HabitDatabase());let d=try JSONDecoder().decode(HabitDatabase.self,from:data);XCTAssertNil(d.wellness);_ = try d.validated()
    }
    func testRepeatedSamplesUpdateAndKeepID()throws{
        var a=WellnessArchive();let r=record(.hrv,40,date(1));try a.merge([r],now:date(30));var second=r;second.id=UUID();second.value=45;try a.merge([second],now:date(30));XCTAssertEqual(a.records.count,1);XCTAssertEqual(a.records[0].value,45);XCTAssertEqual(a.records[0].id,r.id)
    }
    func testFailedBatchIsAtomic()throws{
        var a=WellnessArchive();try a.merge([record(.hrv,40,date(1))],now:date(30));XCTAssertThrowsError(try a.merge([record(.hrv,50,date(2)),record(.rhr,Double.nan,date(2))],now:date(30)));XCTAssertEqual(a.records.count,1)
    }
    func testUnitConversionAndWrongMetricAreExplicit()throws{
        let w=WellnessWire(type:.hrv,value:0.042,unit:"s",start:"2026-01-01T08:00:00+01:00");XCTAssertEqual(try WellnessImport.record(w,now:date(30)).value,42,accuracy:0.001)
        var bad=w;bad.unit="RMSSD";XCTAssertThrowsError(try WellnessImport.record(bad,now:date(30)))
    }
    func testSleepOverlapStagesAndBedAreNotDoubled()throws{
        var a=WellnessArchive();let s=date(1,23),e=date(2,7)
        try a.merge([segment(s,e,.asleep),segment(s,e,.inBed),segment(date(2,1),date(2,3),.deep),segment(date(2,3),date(2,4),.awake)],now:date(30))
        let n=WellnessAnalysis.sleep(a,on:date(2),calendar:cal);XCTAssertEqual(n.seconds,7*3600);XCTAssertEqual(n.inBedSeconds,8*3600);XCTAssertFalse(n.timeline.isEmpty);XCTAssertEqual(n.phases["deep"],2*3600);XCTAssertEqual(n.efficiency!,87.5,accuracy:0.001);XCTAssertEqual(a.records.count,4)
    }
    func testSleepChoosesOneSourcePerNight()throws{
        var a=WellnessArchive();try a.merge([segment(date(1,23),date(2,7),.asleep),segment(date(1,22),date(2,7),.asleep,source:"Other")],now:date(30));XCTAssertEqual(WellnessAnalysis.sleep(a,on:date(2),calendar:cal).seconds,9*3600)
        a.preferences.sleepSource="Watch";XCTAssertEqual(WellnessAnalysis.sleep(a,on:date(2),calendar:cal).seconds,8*3600)
    }
    func testNocturnalHRVAssignsEveningToFollowingSleepDay()throws{
        var a=WellnessArchive();try a.merge([segment(date(1,22),date(2,7),.asleep),record(.hrv,40,date(1,23)),record(.hrv,100,date(2,10))],now:date(30));a.preferences.nocturnalHRV=true
        let points=WellnessAnalysis.daily(a,metric:.hrv,calendar:cal);XCTAssertEqual(points.count,1);XCTAssertEqual(points[0].date,cal.startOfDay(for:date(2)));XCTAssertEqual(points[0].value,40)
    }
    func baseline()throws->WellnessArchive{
        var a=WellnessArchive();for d in 1...15{try a.merge([record(.hrv,40,date(d)),record(.rhr,60,date(d))],now:date(30))};return a
    }
    func testBaselineExcludesTodayAndGatesInsufficientHistory()throws{
        var a=try baseline();XCTAssertNil(WellnessAnalysis.readiness(a,on:date(14),calendar:cal).score)
        let neutral=WellnessAnalysis.readiness(a,on:date(15),calendar:cal);XCTAssertEqual(neutral.baselineDays,14);XCTAssertEqual(neutral.score!,50,accuracy:0.001)
        try a.merge([record(.hrv,80,date(15))],now:date(30));let changed=WellnessAnalysis.readiness(a,on:date(15),calendar:cal);XCTAssertEqual(changed.baselineDays,14);XCTAssertEqual(changed.score!,80,accuracy:0.001)
    }
    func testMixedSourcesSuspendCompositeUntilSelected()throws{
        var a=try baseline();try a.merge([record(.hrv,100,date(15),source:"Other")],now:date(30));XCTAssertNil(WellnessAnalysis.readiness(a,on:date(15),calendar:cal).score);a.preferences.hrvSource="Watch";XCTAssertNotNil(WellnessAnalysis.readiness(a,on:date(15),calendar:cal).score)
    }
    func testMissingTrainingDaysAreNotZeros()throws{
        var a=WellnessArchive();let day=date(28);let r=WellnessRecord(metric:.workout,value:60,start:day,end:day.addingTimeInterval(3600),source:"Manuale",rpe:5);try a.merge([r],now:date(30))
        XCTAssertNil(WellnessAnalysis.load(a,on:day,calendar:cal).ratio)
        a.confirmedTrainingDays=(1...28).map{WellnessAnalysis.day(date($0),calendar:cal)}
        let l=WellnessAnalysis.load(a,on:day,calendar:cal);XCTAssertEqual(l.covered,28);XCTAssertEqual(l.ratio!,4,accuracy:0.001)
    }
    func testJSONRoundTripPreservesIdentityAndOriginalDate()throws{
        var a=WellnessArchive();try a.merge([record(.hrv,42,date(1)),segment(date(1,23),date(2,7),.rem)],now:date(30));let decoded=try WellnessImport.decode(WellnessImport.export(a),now:date(30));try a.merge(decoded,now:date(30));XCTAssertEqual(a.records.count,2);XCTAssertEqual(a.records[0].start,date(1))
    }
    func testInvalidSleepAndFutureAreRejected()throws{
        XCTAssertThrowsError(try segment(date(2),date(1),.asleep).validate(now:date(30)));XCTAssertThrowsError(try record(.hrv,40,date(30)).validate(now:date(1)))
        XCTAssertThrowsError(try WellnessPhase.parse("qualcosa"));XCTAssertEqual(try WellnessPhase.parse("Sonno profondo"),.deep)
    }
    func testCircularWakeTimesDoNotExplodeAtMidnight(){let x=[1430.0,10,1430,10,1430,10,0];XCTAssertLessThan(WellnessAnalysis.circularMinuteDeviation(x)!,15)}
    func testConstantSeriesHasNoCorrelation(){XCTAssertNil(WellnessAnalysis.correlation(Array(repeating:(40,60),count:15)))}
    func testHealthBackupPreservesRecordsAndPreferences()throws{
        var db=HabitDatabase();var a=try baseline();a.preferences.sleepGoal=7.5;db.wellness=a;let recovered=try JSONDecoder().decode(HabitDatabase.self,from:JSONEncoder().encode(db)).validated();XCTAssertEqual(recovered.wellness?.records.count,30);XCTAssertEqual(recovered.wellness?.preferences.sleepGoal,7.5)
    }
}
