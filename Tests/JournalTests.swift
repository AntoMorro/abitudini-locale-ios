import XCTest
@testable import HabitCore

final class JournalTests:XCTestCase {
    func calendar()->Calendar{var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(identifier:"Europe/Rome")!;return c}
    func date(_ y:Int,_ m:Int,_ d:Int)->Date{calendar().date(from:DateComponents(year:y,month:m,day:d))!}
    func testLegacyBackupHasNoJournalAndPreservesHabitHistory()throws {
        var db=HabitDatabase();let h=Habit(title:"Lettura");db.habits=[h];db.samples=[ProgressSample(habitID:h.id,day:HabitEngine.day(Date()),key:"manual",amount:1,date:Date())]
        let data=try JSONEncoder().encode(db);var object=try JSONSerialization.jsonObject(with:data) as! [String:Any];object.removeValue(forKey:"journal")
        let old=try JSONDecoder().decode(HabitDatabase.self,from:JSONSerialization.data(withJSONObject:object));XCTAssertNil(old.journal);XCTAssertEqual(old.samples.count,1);XCTAssertEqual(old.habits.first?.id,h.id);_ = try old.validated()
    }
    func testPageNumbersStayStableAcrossEditsAndBooks()throws {
        var db=JournalDatabase();var page=JournalPage(title:"Prima",body:"Testo",tags:["studio","studio"]);JournalEngine.save(page,in:&db);let second=JournalPage(notebookID:JournalBook.studyID,title:"Seconda");JournalEngine.save(second,in:&db);page.title="Modificata";JournalEngine.save(page,in:&db)
        XCTAssertEqual(db.pages.map(\.number),[1,2]);XCTAssertEqual(db.pages[0].tags,["studio"]);XCTAssertEqual(db.pages[0].title,"Modificata");_ = try db.validated()
    }
    func testMigrationPreservesOriginalAndIsIdempotent()throws {
        var db=JournalDatabase();let task=JournalBullet(text:"Studiare",date:date(2026,11,1));db.bullets=[task]
        let first=try JournalEngine.migrate(task.id,to:date(2026,11,9),in:&db),second=try JournalEngine.migrate(task.id,to:date(2026,11,9),in:&db)
        XCTAssertEqual(first,second);XCTAssertEqual(db.bullets.count,2);XCTAssertEqual(db.bullets[0].status,.migrated);XCTAssertEqual(db.bullets[1].status,.open);_ = try db.validated()
    }
    func testRecurringCompletionDoesNotDuplicateNextInstance()throws {
        var db=JournalDatabase();let task=JournalBullet(text:"Rivedere",date:date(2026,11,9),recurrence:.daily);db.bullets=[task]
        try JournalEngine.complete(task.id,in:&db,calendar:calendar());try JournalEngine.complete(task.id,in:&db,calendar:calendar());XCTAssertEqual(db.bullets.count,2);XCTAssertEqual(db.bullets[1].date,date(2026,11,10));_ = try db.validated()
    }
    func testMonthlyRecurrenceRetainsThirtyFirstAnchor()throws {
        var db=JournalDatabase();let task=JournalBullet(text:"Revisione",date:date(2027,1,31),recurrence:.monthly);db.bullets=[task]
        try JournalEngine.complete(task.id,in:&db,calendar:calendar());XCTAssertEqual(db.bullets[1].date,date(2027,2,28));try JournalEngine.complete(db.bullets[1].id,in:&db,calendar:calendar());XCTAssertEqual(db.bullets[2].date,date(2027,3,31))
    }
    func testWeekdayRecurrenceSkipsWeekendAndDailyRespectsDST() {
        let task=JournalBullet(text:"Ritmo",date:date(2026,11,6),recurrence:.weekdays);XCTAssertEqual(JournalEngine.nextDate(task,calendar:calendar()),date(2026,11,9))
        let dst=JournalBullet(text:"Ritmo",date:date(2026,3,29),recurrence:.daily);XCTAssertEqual(JournalEngine.nextDate(dst,calendar:calendar()),date(2026,3,30))
    }
    func testWatchRetriesSaveOnlyOneNote()throws {
        var db=HabitDatabase();let command=JournalWatchCommand(action:.note,text:"Pensiero dal polso")
        try JournalEngine.receive(command,in:&db);try JournalEngine.receive(command,in:&db);XCTAssertEqual(db.journal?.bullets.count,1);XCTAssertEqual(db.journal?.bullets.first?.id,command.id);_ = try db.validated()
    }
    func testWatchHabitCommandSetsCompletionWithoutToggleOrDoubling()throws {
        var db=HabitDatabase();let h=Habit(title:"Camminare");db.habits=[h]
        let c=JournalWatchCommand(action:.completeHabit,targetID:h.id.uuidString);try JournalEngine.receive(c,in:&db);try JournalEngine.receive(c,in:&db)
        XCTAssertEqual(Tracker.total(h,db:db,date:Date()),1)
        let next=JournalWatchCommand(action:.completeHabit,targetID:h.id.uuidString);try JournalEngine.receive(next,in:&db);XCTAssertEqual(Tracker.total(h,db:db,date:Date()),1)
    }
    func testWatchRejectsStaleFutureAndAutomaticHabitCommands()throws {
        var db=HabitDatabase();let old=JournalWatchCommand(action:.note,created:Date().addingTimeInterval(-31*86400),text:"Vecchio");XCTAssertThrowsError(try JournalEngine.receive(old,in:&db));XCTAssertNil(db.journal)
        let future=JournalWatchCommand(action:.mood,created:Date().addingTimeInterval(10000),mood:4);XCTAssertThrowsError(try future.validate())
        let h=Habit(title:"Passi",kind:.steps);db.habits=[h];XCTAssertThrowsError(try JournalEngine.receive(JournalWatchCommand(action:.completeHabit,targetID:h.id.uuidString),in:&db))
    }
    func testCompleteBackupRoundTripIncludesAttachmentsAndMood()throws {
        var db=HabitDatabase(),j=JournalDatabase();var p=JournalPage(title:"Ricordo",body:"È importante",mood:4,photos:[JournalPhoto(data:Data([1,2,3]))],ink:Data([4,5]),audio:Data([6,7]),audioDuration:2);p.tags=["casa"];JournalEngine.save(p,in:&j);db.journal=j
        let recovered=try JSONDecoder().decode(HabitDatabase.self,from:JSONEncoder().encode(db)).validated();let page=try XCTUnwrap(recovered.journal?.pages.first);XCTAssertEqual(page.photos[0].data,Data([1,2,3]));XCTAssertEqual(page.audio,Data([6,7]));XCTAssertEqual(page.mood,4)
    }
    func testInvalidJournalCannotOverwriteStoredData()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)};let repo=HabitRepository(directory:root)
        try repo.update{db in var j=JournalDatabase();JournalEngine.save(JournalPage(title:"Da conservare"),in:&j);db.journal=j}
        XCTAssertThrowsError(try repo.update{db in db.journal?.pages[0].mood=9});XCTAssertEqual(try repo.read().journal?.pages[0].title,"Da conservare");XCTAssertNil(try repo.read().journal?.pages[0].mood)
    }
    func testDeletionClearsReferencesAndSearchFindsTagsAndText()throws {
        var j=JournalDatabase();let p=JournalPage(title:"Studio",body:"Un concetto prezioso",tags:["lettura"]);JournalEngine.save(p,in:&j);j.bullets=[JournalBullet(text:"Fare",pageID:p.id)]
        XCTAssertEqual(JournalEngine.search("prezioso",in:j).count,1);XCTAssertEqual(JournalEngine.search("lettura",in:j).count,1);JournalEngine.removePage(p.id,in:&j);XCTAssertNil(j.bullets[0].pageID);_ = try j.validated()
    }
    func testMemoriesOnlyMatchSameDayInEarlierYears() {
        var j=JournalDatabase();JournalEngine.save(JournalPage(title:"Ricordo",date:date(2025,11,9)),in:&j);JournalEngine.save(JournalPage(title:"Oggi",date:date(2026,11,9)),in:&j);JournalEngine.save(JournalPage(title:"Altro",date:date(2025,11,8)),in:&j)
        XCTAssertEqual(JournalEngine.onThisDay(j,now:date(2026,11,9),calendar:calendar()).map(\.title),["Ricordo"])
    }
}
