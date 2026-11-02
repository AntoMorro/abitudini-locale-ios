import XCTest
final class HabitFlowTests: XCTestCase {
    func testTrackerCreateToggleCalendarAndStatistics() {
        continueAfterFailure = false
        let app=XCUIApplication();app.launchArguments=["--ui-testing","-AppleLanguages","(it)","-AppleLocale","it_IT"];app.launch()
        XCTAssertTrue(app.buttons["Inizia"].waitForExistence(timeout:15));app.buttons["Inizia"].tap()
        app.buttons["Nuova abitudine"].tap()
        let field=app.textFields["Nome abitudine"];XCTAssertTrue(field.waitForExistence(timeout:5));field.tap();field.typeText("Lettura\n")
        app.buttons["Salva"].tap()
        let complete=app.buttons["Completa Lettura"];XCTAssertTrue(complete.waitForExistence(timeout:5));complete.tap();capture("01-Abitudini",app)
        app.buttons["detail-Lettura"].tap()
        XCTAssertTrue(app.buttons["Modifica oggi"].waitForExistence(timeout:5));app.buttons["Modifica oggi"].tap()
        let note=app.textViews["dayNote"];XCTAssertTrue(note.waitForExistence(timeout:5));note.tap();note.typeText("Capitolo uno")
        app.buttons["Salva giornata"].tap();capture("02-Dettaglio",app)
        app.navigationBars.buttons.element(boundBy:0).tap()
        complete.tap();app.buttons["detail-Lettura"].tap()
        XCTAssertTrue(app.buttons["Registra oggi"].waitForExistence(timeout:5))
        app.tabBars.buttons["Statistiche"].tap();capture("03-Statistiche",app);XCTAssertTrue(app.staticTexts["Giorni completati"].exists)
        app.tabBars.buttons["Impostazioni"].tap();capture("04-Impostazioni",app);XCTAssertTrue(app.buttons["Abilita promemoria"].exists)
        XCTAssertTrue(app.switches["Promemoria di check-in giornaliero"].exists)
    }
    func capture(_ name:String,_ app:XCUIApplication) { let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
}
