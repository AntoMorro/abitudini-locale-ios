import XCTest
@testable import HabitCore
final class WellnessHealthXMLTests:XCTestCase {
    let since=Date(timeIntervalSince1970:0)
    func xml(_ body:String)->Data{Data(("<HealthData>"+body+"</HealthData>").utf8)}
    func record(_ type:String,_ unit:String,_ value:String,_ start:String="2026-01-01 01:00:00 +0100",end:String?=nil)->String{
        "<Record type=\"\(type)\" sourceName=\"Synthetic Watch\" unit=\"\(unit)\" value=\"\(value)\" startDate=\"\(start)\" endDate=\"\(end ?? start)\"/>"
    }
    func testHealthKitOxygenFractionsAndDateZone()throws{
        let data=xml(record("HKQuantityTypeIdentifierOxygenSaturation","%","0.97"))
        let r=try WellnessHealthXML.read(data:data,since:since,metrics:[.oxygen])
        XCTAssertEqual(r.first?.value,97);XCTAssertEqual(r.first?.start,Date(timeIntervalSince1970:1_767_225_600))
    }
    func testSelectionAndCutoffSkipUnrelatedAndOldMalformedValues()throws{
        let data=xml(record("HKQuantityTypeIdentifierHeartRate","count/min","bad","2020-01-01 00:00:00 +0000")+record("HKQuantityTypeIdentifierRespiratoryRate","count/min","bad")+record("HKQuantityTypeIdentifierHeartRate","count/min","65"))
        let r=try WellnessHealthXML.read(data:data,since:Date(timeIntervalSince1970:1_735_689_600),metrics:[.heart])
        XCTAssertEqual(r.count,1);XCTAssertEqual(r[0].value,65)
    }
    func testSleepCoreAndWorkoutRPENotInvented()throws{
        let sleep=record("HKCategoryTypeIdentifierSleepAnalysis","","HKCategoryValueSleepAnalysisAsleepCore",end:"2026-01-01 02:00:00 +0100")
        let workout="<Workout workoutActivityType=\"HKWorkoutActivityTypeWalking\" sourceName=\"Synthetic Watch\" startDate=\"2026-01-01 08:00:00 +0100\" endDate=\"2026-01-01 08:30:00 +0100\"/>"
        let records=try WellnessHealthXML.read(data:xml(sleep+workout),since:since,metrics:[.sleep,.workout])
        XCTAssertEqual(records.count,2);XCTAssertEqual(records[0].phase,.core);XCTAssertNil(records[1].rpe);XCTAssertEqual(records[1].value,30)
    }
    func testSelectedBadUnitOrUnknownSleepPhaseAbortsWholePreview(){
        let good=record("HKQuantityTypeIdentifierHeartRate","count/min","65")
        XCTAssertThrowsError(try WellnessHealthXML.read(data:xml(good+record("HKCategoryTypeIdentifierSleepAnalysis","","unknown",end:"2026-01-01 02:00:00 +0100")),since:since,metrics:[.heart,.sleep]))
        XCTAssertThrowsError(try WellnessHealthXML.read(data:xml(record("HKQuantityTypeIdentifierOxygenSaturation","%","97")),since:since,metrics:[.oxygen]))
        XCTAssertThrowsError(try WellnessHealthXML.read(data:xml(record("HKQuantityTypeIdentifierAppleSleepingWristTemperature","degC","0.3")),since:since,metrics:[.temperature]))
    }
    func testMalformedXMLAndSelectedBatchLimit(){
        XCTAssertThrowsError(try WellnessHealthXML.read(data:Data("<HealthData>".utf8),since:since,metrics:[.heart]))
        let body=String(repeating:record("HKQuantityTypeIdentifierHeartRate","count/min","65"),count:10_001)
        XCTAssertThrowsError(try WellnessHealthXML.read(data:xml(body),since:since,metrics:[.heart]))
    }
    func testXMLReplayIsIdempotent()throws{
        let r=try WellnessHealthXML.read(data:xml(record("HKQuantityTypeIdentifierHeartRate","count/min","65")),since:since,metrics:[.heart])
        var a=WellnessArchive();try a.merge(r);try a.merge(r);XCTAssertEqual(a.records.count,1)
    }
}
