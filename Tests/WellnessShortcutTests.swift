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
    func testGenericSleepLabelsRemainUnspecified()throws{
        for label in ["In sonno","Sonno (non specificato)","Asleep (Unspecified)","ADDORMENTATO NON SPECIFICATO"]{
            let w=WellnessWire(type:.sleep,start:"2026-01-01T01:00:00+01:00",end:"2026-01-01T01:10:00+01:00",stage64:base64(label))
            XCTAssertEqual(try WellnessImport.record(w).phase,.asleep)
        }
    }
    func testShortcutsSpecificSleepLabelsPreservePhase()throws{
        for (label,phase) in [("rem",WellnessPhase.rem),("veglia",.awake),("Essenziale",.core),("Profondo",.deep),("A letto",.inBed)]{
            XCTAssertEqual(try WellnessPhase.parse(label),phase)
        }
    }
    func testUnknownPhaseDiagnosticDoesNotExposeQuantitiesOrSavePartialBatch()throws{
        XCTAssertThrowsError(try WellnessPhase.parse("fase nuova")){XCTAssertTrue($0.localizedDescription.contains("fase nuova"))}
        XCTAssertThrowsError(try WellnessPhase.parse("12345 min")){XCTAssertFalse($0.localizedDescription.contains("12345"))}
        let records=[WellnessWire(type:.sleep,start:"2026-01-01T01:00:00+01:00",end:"2026-01-01T01:10:00+01:00",stage:"rem"),WellnessWire(type:.sleep,start:"2026-01-01T01:10:00+01:00",end:"2026-01-01T01:20:00+01:00",stage:"fase nuova")]
        let data=try JSONEncoder().encode(WellnessEnvelope(version:1,records:records));var a=WellnessArchive()
        XCTAssertThrowsError(try a.merge(WellnessImport.decode(data)));XCTAssertTrue(a.records.isEmpty)
    }
}
