import XCTest

final class HabitFlowTests: XCTestCase {
    func testHabitCompletionAndRuleDraft() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]; app.launch()
        XCTAssertTrue(app.buttons["Esplora un esempio"].waitForExistence(timeout: 15)); app.buttons["Esplora un esempio"].tap()
        XCTAssertTrue(app.navigationBars["blocchi"].waitForExistence(timeout: 8)); capture("01-Blocchi", app)
        app.tabBars.buttons["Statistiche"].tap(); app.buttons["Nuova abitudine"].tap()
        let field = app.textFields["Nome abitudine"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Test habit")
        app.buttons["Salva"].tap()
        let complete = app.buttons["Completa Test habit"]; if !complete.isHittable { app.swipeUp() }
        XCTAssertTrue(complete.waitForExistence(timeout: 5)); complete.tap(); capture("02-Abitudini", app)
        XCTAssertFalse(complete.isEnabled)
        app.tabBars.buttons["Blocchi"].tap(); app.buttons["newBlock"].tap()
        let title = app.textFields["Nome blocco"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Distrazioni\n")
        let selected = app.switches["Test habit"]; XCTAssertTrue(selected.waitForExistence(timeout: 5))
        let nativeSwitch = selected.switches.firstMatch
        if nativeSwitch.exists { nativeSwitch.tap() } else { selected.tap() }
        XCTAssertEqual(selected.value as? String, "1")
        capture("03-Regola", app); XCTAssertTrue(app.buttons["Salva"].isEnabled); app.buttons["Salva"].tap()
        XCTAssertTrue(app.buttons["Distrazioni"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Impostazioni"].tap(); capture("04-Impostazioni", app)
        XCTAssertTrue(app.buttons["Autorizza Tempo di utilizzo"].exists)
    }
    func capture(_ name: String, _ app: XCUIApplication) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
}
