import XCTest
final class FlowTests:XCTestCase {
    var app:XCUIApplication!
    override func setUpWithError() throws {continueAfterFailure = false;app = XCUIApplication();app.launchArguments = ["--ui-testing"];app.launch()}
    func shot(_ name:String) {let a = XCTAttachment(screenshot:app.screenshot());a.name = name;a.lifetime = .keepAlways;add(a)}
    func openTab(_ name:String) {app.tabBars.buttons[name].tap()}
    func save(_ title:String) {let field = app.textFields["entityTitle"];XCTAssertTrue(field.waitForExistence(timeout:5));field.tap();field.typeText(title);app.buttons["saveEntity"].tap();XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout:5))}
    func testRealEntryFlowsAndSeating() {
        shot("01-riepilogo-vuoto")
        openTab("Attività");app.buttons["addTask"].tap();save("Confermare cerimonia");shot("02-checklist")
        openTab("Invitati");app.buttons["addGuest"].tap();save("Anna Prova");shot("03-invitati")
        openTab("Budget");app.buttons["addExpense"].tap();save("Fiori cerimonia");shot("04-budget")
        openTab("Organizza");app.buttons["Sala e tavoli"].tap();app.buttons["addTable"].tap();save("Rosa");shot("05-pianta")
        app.buttons.containing(.staticText,identifier:"Rosa").firstMatch.tap()
        XCTAssertTrue(app.buttons.containing(.staticText,identifier:"Anna Prova").firstMatch.waitForExistence(timeout:5));app.buttons.containing(.staticText,identifier:"Anna Prova").firstMatch.tap();shot("06-assegnazione")
        XCTAssertTrue(app.staticTexts["1 di 8 posti"].exists);app.buttons["Fine"].tap()
        openTab("Oggi");shot("07-riepilogo-con-dati")
        app.terminate();app.launchArguments = [];app.launch()
        // UI storage is isolated, production must still be empty.
        XCTAssertTrue(app.staticTexts["Il nostro matrimonio"].waitForExistence(timeout:5))
    }
    func testVendorsNotesScheduleAndAccessibility() {
        openTab("Organizza");app.buttons["Fornitori"].tap();app.buttons["addCollection"].tap();save("Fotografo Prova");shot("08-fornitori")
        openTab("Oggi");openTab("Organizza");app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Programma"].tap();app.buttons["addSchedule"].tap();save("Cerimonia");shot("09-programma")
        app.navigationBars.buttons.element(boundBy:0).tap();app.buttons["Note e idee"].tap();app.buttons["addCollection"].tap();save("Idee per i fiori");shot("10-note")
    }
}
