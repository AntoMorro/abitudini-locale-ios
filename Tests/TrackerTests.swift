import XCTest
@testable import HabitCore

final class TrackerTests: XCTestCase {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; return c }
    func date(_ v: String) -> Date { ISO8601DateFormatter().date(from: v + "T12:00:00Z")! }
    func testOldBackupDecodes() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(HabitDatabase())) as! [String:Any]
        json.removeValue(forKey:"plans");json.removeValue(forKey:"notes")
        let decoded = try JSONDecoder().decode(HabitDatabase.self,from:JSONSerialization.data(withJSONObject:json)).validated()
        XCTAssertNil(decoded.plans);XCTAssertNil(decoded.notes)
    }
    func testHistoricalEditAndNotes() throws {
        var db=HabitDatabase();let h=Habit(title:"Lettura",kind:.counter,goal:20,created:date("2026-10-01"));db.habits=[h]
        let day=date("2026-10-15"),now=date("2026-11-02")
        try Tracker.record(h,db:&db,date:day,amount:30,note:"Nota, con virgola",now:now,calendar:cal)
        try Tracker.record(h,db:&db,date:day,amount:40,now:now,calendar:cal)
        XCTAssertEqual(Tracker.total(h,db:db,date:day,calendar:cal),40);XCTAssertEqual(db.samples.count,1)
        XCTAssertTrue(Tracker.csv(db).contains("Nota, con virgola"))
        try Tracker.record(h,db:&db,date:day,amount:nil,now:now,calendar:cal)
        XCTAssertFalse(Tracker.complete(h,db:db,date:day,calendar:cal))
        XCTAssertThrowsError(try Tracker.record(h,db:&db,date:date("2026-11-03"),amount:1,now:now,calendar:cal))
    }
    func testQuitRequiresEntryAndStrictLimit() throws {
        var db=HabitDatabase();let h=Habit(title:"Caffe",kind:.counter,goal:2,created:date("2026-10-01"));db.habits=[h];var p=HabitPlan();p.quit=true;db.plans=[h.id.uuidString:p]
        let now=date("2026-11-02")
        XCTAssertFalse(Tracker.complete(h,db:db,date:now,calendar:cal))
        try Tracker.record(h,db:&db,date:now,amount:0,now:now,calendar:cal);XCTAssertTrue(Tracker.complete(h,db:db,date:now,calendar:cal))
        try Tracker.record(h,db:&db,date:now,amount:2,now:now,calendar:cal);XCTAssertFalse(Tracker.complete(h,db:db,date:now,calendar:cal))
    }
    func testOffDaysAndOpenTodayPreserveStreak() throws {
        var db=HabitDatabase();let h=Habit(title:"Studio",created:date("2026-10-29"));db.habits=[h];var p=HabitPlan();p.weekdays=[2,3,4,5,6];db.plans=[h.id.uuidString:p]
        for key in ["2026-10-29","2026-10-30"] { try Tracker.record(h,db:&db,date:date(key),amount:1,now:date("2026-11-02"),calendar:cal) }
        let stats=Tracker.stats(h,db:db,now:date("2026-11-02"),calendar:cal)
        XCTAssertEqual(stats.current,2);XCTAssertEqual(stats.longest,2);XCTAssertEqual(stats.rate,1)
        XCTAssertEqual(Tracker.stats(h,db:db,now:date("2026-11-03"),calendar:cal).current,0)
    }
    func testWeeklyGoalCountsDaysOnce() throws {
        var db=HabitDatabase();let h=Habit(title:"Sport",created:date("2026-10-19"));db.habits=[h];var p=HabitPlan();p.period = .weekly;p.target=2;db.plans=[h.id.uuidString:p]
        for key in ["2026-10-19","2026-10-21","2026-10-26","2026-10-27"] { try Tracker.record(h,db:&db,date:date(key),amount:5,now:date("2026-11-02"),calendar:cal) }
        XCTAssertEqual(Tracker.periodProgress(h,db:db,date:date("2026-10-28"),calendar:cal).0,2)
        XCTAssertEqual(Tracker.stats(h,db:db,now:date("2026-11-02"),calendar:cal).current,2)
    }
    func testValidationRejectsBadPlanAndNotes() throws {
        var db=HabitDatabase();let h=Habit(title:"A");db.habits=[h];var p=HabitPlan();p.weekdays=[];db.plans=[h.id.uuidString:p]
        XCTAssertThrowsError(try db.validated());p.weekdays=[2];p.reminders=[1440];db.plans=[h.id.uuidString:p];XCTAssertThrowsError(try db.validated())
        p.reminders=[];db.plans=[h.id.uuidString:p];db.notes=["invalid":"test"];XCTAssertThrowsError(try db.validated())
    }
    func testMonthlyGoalAndThreeDecimalAmounts() throws {
        var db=HabitDatabase();let h=Habit(title:"Acqua",kind:.counter,goal:1500,created:date("2026-09-01"));db.habits=[h];var p=HabitPlan();p.scale=1000;p.unit="litri";p.period = .monthly;p.target=2;db.plans=[h.id.uuidString:p]
        for key in ["2026-09-01","2026-09-30","2026-10-01","2026-10-31"] { try Tracker.record(h,db:&db,date:date(key),amount:1625,now:date("2026-11-02"),calendar:cal) }
        XCTAssertEqual(Tracker.stats(h,db:db,now:date("2026-11-02"),calendar:cal).current,2)
        XCTAssertTrue(Tracker.csv(db).contains("1.625"));XCTAssertEqual(Tracker.periodProgress(h,db:db,date:date("2026-11-02"),calendar:cal).0,0)
    }
    func testEverydayRemindersUseOneRequestPerTimeAndCheckInIsIncluded() throws {
        var db = HabitDatabase(); let h = Habit(title: "A"); db.habits = [h]
        var p = HabitPlan(); p.reminders = [540,720,1200]; db.plans = [h.id.uuidString:p]
        XCTAssertEqual(Tracker.reminderRequestCount(db),3)
        db.checkInMinute = 1200; XCTAssertEqual(Tracker.reminderRequestCount(db),4)
        p.weekdays = [2,4,6]; db.plans = [h.id.uuidString:p]; XCTAssertEqual(Tracker.reminderRequestCount(db),10)
        db.checkInMinute = 1440; XCTAssertThrowsError(try db.validated())
    }
}
