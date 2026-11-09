import XCTest
@testable import HabitCore

final class WellnessShortcutTests:XCTestCase {
    func base64(_ s:String)->String{Data(s.utf8).base64EncodedString()}
    func testEncodedHRVPreservesDecimalCommaAndUnits()throws{
        let w=WellnessWire(type:.hrv,start:"2026-01-01T07:30:00+01:00",value64:base64("42,5 ms"),unit64:base64("millisecondi"),source64:base64("Watch \"personale\""))
        let r=try WellnessImport.record(w);XCTAssertEqual(r.value,42.5);XCTAssertEqual(r.source,"Watch \"personale\"")
    }
    func testSecondsAreConvertedOnce()throws{
        let w=WellnessWire(type:.hrv,start:"2026-01-01T07:30:00+01:00",value64:base64("0,042 s"),unit64:base64("s"))
        XCTAssertEqual(try WellnessImport.record(w).value,42,accuracy:0.00001)
    }
    func testEncodedSleepRecognizesVegliaAndRetainsDates()throws{
        let w=WellnessWire(type:.sleep,start:"2026-01-01T01:00:00+01:00",end:"2026-01-01T01:10:00+01:00",stage64:base64("Veglia"))
        let r=try WellnessImport.record(w);XCTAssertEqual(r.phase,.awake);XCTAssertEqual(r.end.timeIntervalSince(r.start),600)
    }
    func testConflictingUnitsAreRejected()throws{
        let w=WellnessWire(type:.hrv,start:"2026-01-01T07:30:00+01:00",value64:base64("42 ms"),unit64:base64("s"))
        XCTAssertThrowsError(try WellnessImport.record(w))
    }
    func testInvalidUTF8AndMalformedJSONHaveReadableErrors()throws{
        XCTAssertThrowsError(try WellnessImport.text(Data([0xff,0xfe]).base64EncodedString()))
        XCTAssertThrowsError(try WellnessImport.decode(Data("not a JSON".utf8))){error in XCTAssertTrue(error.localizedDescription.contains("JSON"))}
    }
    func testEncodedJSONBatchIsIdempotent()throws{
        let e=WellnessEnvelope(version:1,records:[WellnessWire(type:.rhr,start:"2026-01-01T07:30:00+01:00",value64:base64("60 bpm"),unit64:base64("bpm"))])
        let records=try WellnessImport.decode(JSONEncoder().encode(e));var a=WellnessArchive();try a.merge(records);try a.merge(records);XCTAssertEqual(a.records.count,1);XCTAssertEqual(a.records[0].value,60)
    }
}
