import XCTest
@testable import HabitCore
final class WellnessSleepSourceTests:XCTestCase {
    let now=Date(timeIntervalSince1970:1_767_268_800)
    func iso(_ d:Date)->String{ISO8601DateFormatter().string(from:d)}
    func wire()->WellnessWire{.init(type:.sleep,start:iso(now.addingTimeInterval(-7200)),end:iso(now.addingTimeInterval(-3600)),stage:"principale")}
    func testNilEmptyAndWhitespaceSleepSourceUseExplicitUnknownLabel()throws{
        var missing=wire(),empty=wire(),encoded=wire()
        missing.source=nil;empty.source="";encoded.source="ignored known value";encoded.source64=Data(" \n\t ".utf8).base64EncodedString()
        for value in [missing,empty,encoded]{
            let r=try WellnessImport.record(value,now:now)
            XCTAssertEqual(r.source,WellnessImport.unknownSleepSource);XCTAssertEqual(r.phase,.core)
            try r.validate(now:now)
        }
    }
    func testKnownSourceAndOriginalDatesRemainUnchanged()throws{
        var w=wire();w.source="Fallback";w.source64=Data("Apple Watch personale".utf8).base64EncodedString()
        let r=try WellnessImport.record(w,now:now)
        XCTAssertEqual(r.source,"Apple Watch personale");XCTAssertEqual(r.start,now.addingTimeInterval(-7200));XCTAssertEqual(r.end,now.addingTimeInterval(-3600))
    }
    func testUnattributedSleepDeduplicatesAndStillExcludesFuture()throws{
        let current=wire();var future=wire();future.start=iso(now.addingTimeInterval(3600));future.end=iso(now.addingTimeInterval(7200))
        let data=try JSONEncoder().encode(WellnessEnvelope(version:1,records:[current,future]))
        let batch=try WellnessImport.shortcutBatch(data,now:now)
        XCTAssertEqual(batch.records.count,1);XCTAssertEqual(batch.unknownSleepSourceCount,1);XCTAssertEqual(batch.futureSleepExcluded,1)
        var a=WellnessArchive();try a.merge(batch.records,now:now);let id=a.records[0].id;try a.merge(WellnessImport.shortcutBatch(data,now:now).records,now:now)
        XCTAssertEqual(a.records.count,1);XCTAssertEqual(a.records[0].id,id)
    }
    func testNightPrefersIdentifiedSourceAndRespectsExplicitUnknownSelection(){
        var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(secondsFromGMT:0)!
        let day=cal.startOfDay(for:now),start=day.addingTimeInterval(3600)
        var a=WellnessArchive()
        a.records=[.init(metric:.sleep,value:30,start:start,end:start.addingTimeInterval(1800),source:"Known Watch",phase:.core),.init(metric:.sleep,value:120,start:start,end:start.addingTimeInterval(7200),source:WellnessImport.unknownSleepSource,phase:.core)]
        let automatic=WellnessAnalysis.sleep(a,on:day,calendar:cal)
        XCTAssertEqual(automatic.source,"Known Watch");XCTAssertEqual(automatic.seconds,1800)
        a.preferences.sleepSource=WellnessImport.unknownSleepSource
        let selected=WellnessAnalysis.sleep(a,on:day,calendar:cal)
        XCTAssertEqual(selected.source,WellnessImport.unknownSleepSource);XCTAssertEqual(selected.seconds,7200)
    }
}
