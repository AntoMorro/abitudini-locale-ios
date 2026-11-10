import XCTest
@testable import HabitCore

final class WellnessSleepDatesTests:XCTestCase {
    let now=Date(timeIntervalSince1970:1_767_268_800)
    func iso(_ d:Date)->String{let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime];return f.string(from:d)}
    func sleep(_ start:Double,_ end:Double,source:String="Watch")->WellnessWire{
        .init(type:.sleep,start:iso(now.addingTimeInterval(start)),end:iso(now.addingTimeInterval(end)),source:source,stage:"principale")
    }
    func data(_ records:[WellnessWire])throws->Data{try JSONEncoder().encode(WellnessEnvelope(version:1,records:records))}
    func testShortcutSkipsFutureSleepAndPreservesValidDatesAndDeduplication()throws{
        let valid=sleep(-3600,-1800),future=sleep(3600,7200),bytes=try data([valid,future])
        let result=try WellnessImport.shortcutBatch(bytes,now:now)
        XCTAssertEqual(result.futureSleepExcluded,1);XCTAssertEqual(result.records.count,1)
        XCTAssertEqual(result.records[0].start,now.addingTimeInterval(-3600));XCTAssertEqual(result.records[0].end,now.addingTimeInterval(-1800));XCTAssertEqual(result.records[0].phase,.core)
        var archive=WellnessArchive();try archive.merge(result.records,now:now);let id=archive.records[0].id
        try archive.merge(WellnessImport.shortcutBatch(bytes,now:now).records,now:now)
        XCTAssertEqual(archive.records.count,1);XCTAssertEqual(archive.records[0].id,id)
        XCTAssertThrowsError(try WellnessImport.decode(bytes,now:now))
    }
    func testAllFutureSleepReportsNoValidSamplesWithoutSaving()throws{
        var archive=WellnessArchive()
        XCTAssertThrowsError(try archive.merge(WellnessImport.shortcutBatch(data([sleep(3600,7200)]),now:now).records,now:now)){XCTAssertTrue($0.localizedDescription.contains("SONNO-FUTURO"))}
        XCTAssertTrue(archive.records.isEmpty)
    }
    func testFutureNonSleepIsStillRejected()throws{
        let future=WellnessWire(type:.rhr,value:60,unit:"bpm",start:iso(now.addingTimeInterval(7200)),source:"Watch")
        XCTAssertThrowsError(try WellnessImport.shortcutBatch(data([sleep(-3600,-1800),future]),now:now)){e in
            XCTAssertTrue(e.localizedDescription.contains("DATA-FUTURA"));XCTAssertTrue(e.localizedDescription.contains("2/2"))
        }
    }
    func testReversedEndAndBlankSourceHaveDistinctDiagnostics()throws{
        XCTAssertThrowsError(try WellnessImport.shortcutBatch(data([sleep(-1800,-3600)]),now:now)){XCTAssertTrue($0.localizedDescription.contains("ORDINE-DATE"))}
        XCTAssertThrowsError(try WellnessImport.shortcutBatch(data([sleep(-3600,-1800,source:" ")]),now:now)){XCTAssertTrue($0.localizedDescription.contains("FONTE-VUOTA"))}
    }
    func testMalformedDateAndLongSourceDoNotEchoPrivateValues()throws{
        var malformed=sleep(-3600,-1800);malformed.start="private-invalid-date"
        XCTAssertThrowsError(try WellnessImport.shortcutBatch(data([malformed]),now:now)){XCTAssertFalse($0.localizedDescription.contains("private-invalid-date"))}
        let source=String(repeating:"PrivateName",count:20)
        XCTAssertThrowsError(try WellnessImport.shortcutBatch(data([sleep(-3600,-1800,source:source)]),now:now)){e in
            XCTAssertTrue(e.localizedDescription.contains("FONTE-LUNGA"));XCTAssertFalse(e.localizedDescription.contains("PrivateName"))
        }
    }
    func testExistingClockToleranceBoundaryIsPreserved()throws{
        let accepted=try WellnessImport.shortcutBatch(data([sleep(-1200,300)]),now:now)
        XCTAssertEqual(accepted.records.count,1);XCTAssertEqual(accepted.futureSleepExcluded,0)
        XCTAssertThrowsError(try WellnessImport.shortcutBatch(data([sleep(-1200,301)]),now:now)){XCTAssertTrue($0.localizedDescription.contains("SONNO-FUTURO"))}
    }
}
