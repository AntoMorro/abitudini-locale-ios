import XCTest
@testable import HabitCore

final class HabitCoreTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    var now: Date { date("2026-11-02T12:00:00Z") }
    func fixture() -> HabitDatabase {
        var db = HabitDatabase(); db.onboarded = true
        let a = Habit(title: "A", kind: .counter, goal: 10, capOnceDaily: false)
        let b = Habit(title: "B", kind: .counter, goal: 10, capOnceDaily: false)
        let c = Habit(title: "C", kind: .counter, goal: 10, capOnceDaily: false)
        db.habits = [a,b,c]; db.rules = [BlockRule(title: "Focus", enabled: true, habitIDs: [a.id,b.id,c.id])]
        for (h,n) in zip(db.habits,[30,20,10]) { db.samples.append(ProgressSample(habitID: h.id, day: HabitEngine.day(now, calendar: calendar), key: "fixture", amount: n, date: now)) }
        return db
    }
    func testAllAnyAndNofM() {
        var db = fixture(), rule = db.rules[0]
        XCTAssertEqual(HabitEngine.earned(rule, db: db, now: now, calendar: calendar), 1)
        rule.requirement = .any; XCTAssertEqual(HabitEngine.earned(rule, db: db, now: now, calendar: calendar), 3)
        rule.requirement = .atLeast; rule.minimum = 2; XCTAssertEqual(HabitEngine.earned(rule, db: db, now: now, calendar: calendar), 2)
        db.habits.removeLast(); XCTAssertEqual(HabitEngine.earned(rule, db: db, now: now, calendar: calendar), 0)
    }
    func testSpendIsAtomicAndCannotReuseCredit() throws {
        var db = fixture(); let id = db.rules[0].id
        try HabitEngine.spend(id, db: &db, now: now, calendar: calendar)
        XCTAssertEqual(db.spends.count, 1); XCTAssertEqual(HabitEngine.credits(db.rules[0], db: db, now: now, calendar: calendar), 0)
        XCTAssertThrowsError(try HabitEngine.spend(id, db: &db, now: now, calendar: calendar))
        XCTAssertEqual(db.spends.count, 1)
        XCTAssertFalse(HabitEngine.shouldShield(db.rules[0], db: db, now: now.addingTimeInterval(10), calendar: calendar))
        XCTAssertTrue(HabitEngine.shouldShield(db.rules[0], db: db, now: now.addingTimeInterval(901), calendar: calendar))
    }
    func testDayUnlockExpiresAtMidnight() throws {
        var db = fixture(); db.rules[0].unlockMode = .day
        try HabitEngine.spend(db.rules[0].id, db: &db, now: now, calendar: calendar)
        XCTAssertTrue(HabitEngine.sessionOpen(db.rules[0], now: date("2026-11-02T23:59:59Z"), calendar: calendar))
        XCTAssertFalse(HabitEngine.sessionOpen(db.rules[0], now: date("2026-11-03T00:00:00Z"), calendar: calendar))
    }
    func testUsageSessionRemainsOpenUntilExhausted() throws {
        var db = fixture(); db.rules[0].unlockMode = .usage
        try HabitEngine.spend(db.rules[0].id, db: &db, now: now, calendar: calendar)
        XCTAssertTrue(HabitEngine.sessionOpen(db.rules[0], now: now.addingTimeInterval(7200), calendar: calendar))
        db.rules[0].session?.exhausted = true
        XCTAssertTrue(HabitEngine.shouldShield(db.rules[0], db: db, now: now.addingTimeInterval(7200), calendar: calendar))
    }
    func testOvernightWindowBelongsToStartingWeekday() {
        var rule = fixture().rules[0]; rule.weekdays = [2]; rule.startMinute = 22 * 60; rule.endMinute = 2 * 60
        XCTAssertTrue(HabitEngine.active(rule, now: date("2026-11-02T23:00:00Z"), calendar: calendar))
        XCTAssertTrue(HabitEngine.active(rule, now: date("2026-11-03T01:59:00Z"), calendar: calendar))
        XCTAssertFalse(HabitEngine.active(rule, now: date("2026-11-03T02:00:00Z"), calendar: calendar))
        XCTAssertFalse(HabitEngine.active(rule, now: date("2026-11-01T23:00:00Z"), calendar: calendar))
    }
    func testDailyCapAndExternalUpsertsDoNotDoubleCount() throws {
        var db = fixture(); let id = db.habits[0].id; db.habits[0].capOnceDaily = true
        XCTAssertEqual(HabitEngine.progress(db.habits[0], in: db, now: now, calendar: calendar), 10)
        db.samples.removeAll()
        let sample = ProgressSample(habitID: id, day: HabitEngine.day(now), key: "shortcut.total", amount: 7, date: now)
        db.upsert(sample); db.upsert(sample)
        XCTAssertEqual(db.samples.count, 1); XCTAssertEqual(HabitEngine.progress(db.habits[0], in: db, now: now), 7)
        XCTAssertNoThrow(try db.validated())
    }
    func testTimerUsesUptimeAndSplitsAtMidnight() {
        var db = fixture(); let h = Habit(title: "Timer", kind: .timer, goal: 600, capOnceDaily: false); db.habits.append(h)
        let start = date("2026-11-02T23:59:50Z")
        db.timer = HabitTimer(habitID: h.id, started: start, uptime: 100, background: true)
        XCTAssertEqual(HabitEngine.timerSeconds(db.timer!, now: start.addingTimeInterval(3600), uptime: 120), 20)
        HabitEngine.settleTimer(&db, now: start.addingTimeInterval(20), uptime: 120, calendar: calendar)
        XCTAssertNil(db.timer)
        XCTAssertEqual(db.samples.filter { $0.habitID == h.id }.map(\.amount), [10,10])
        XCTAssertEqual(db.samples.filter { $0.habitID == h.id }.map(\.day), ["2026-11-02","2026-11-03"])
    }
    func testOverlappingHealthSessionsCountOnce() {
        let limit = DateInterval(start: now, duration: 3600)
        let intervals = [DateInterval(start: now.addingTimeInterval(-300), duration: 1500), DateInterval(start: now.addingTimeInterval(600), duration: 1800), DateInterval(start: now.addingTimeInterval(3000), duration: 1200)]
        XCTAssertEqual(HabitEngine.mergedSeconds(intervals, within: limit), 3000)
    }
    func testValidationRejectsDanglingIDsDuplicateEventsAndShortSchedules() {
        var db = fixture(); db.rules[0].habitIDs.append(UUID()); XCTAssertThrowsError(try db.validated())
        db = fixture(); var duplicate = db.samples[0]; duplicate.id = UUID(); db.samples.append(duplicate); XCTAssertThrowsError(try db.validated())
        db = fixture(); db.rules[0].startMinute = 100; db.rules[0].endMinute = 110; XCTAssertThrowsError(try db.validated())
        db = fixture(); db.rules[0].startMinute = 100; db.rules[0].endMinute = 100; XCTAssertNoThrow(try db.validated())
    }
    func testEmergencyAndCommitmentBoundaries() {
        var db = fixture(); db.rules[0].commitmentUntil = now.addingTimeInterval(60)
        XCTAssertTrue(HabitEngine.locked(db.rules[0], now: now))
        XCTAssertFalse(HabitEngine.locked(db.rules[0], now: now.addingTimeInterval(60)))
        db.emergencyUntil = now.addingTimeInterval(3600)
        XCTAssertFalse(HabitEngine.shouldShield(db.rules[0], db: db, now: now, calendar: calendar))
        XCTAssertTrue(HabitEngine.shouldShield(db.rules[0], db: db, now: now.addingTimeInterval(3600), calendar: calendar))
    }
    func testRepositoryTransactionFailurePreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HabitTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = HabitRepository(directory: directory)
        try repository.update { $0 = fixture() }
        let original = try Data(contentsOf: repository.file)
        XCTAssertThrowsError(try repository.update { $0.rules[0].habitIDs = [UUID()] })
        XCTAssertEqual(try Data(contentsOf: repository.file), original)
        XCTAssertThrowsError(try repository.restore(Data("not JSON".utf8)))
        XCTAssertEqual(try Data(contentsOf: repository.file), original)
    }
    func testConcurrentRepositoryWritersDoNotLoseEvents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HabitConcurrent-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = HabitRepository(directory: directory); let h = Habit(title: "Count", kind: .counter, goal: 100)
        try repository.update { $0.habits = [h] }
        DispatchQueue.concurrentPerform(iterations: 20) { _ in _ = try? HabitRepository(directory: directory).update { try HabitEngine.add(h.id, amount: 1, db: &$0, now: self.now) } }
        XCTAssertEqual(try repository.read().samples.count, 20)
    }
}
