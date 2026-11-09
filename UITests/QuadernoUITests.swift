import XCTest

final class QuadernoUITests:XCTestCase {
    func shot(_ name:String){let a=XCTAttachment(screenshot:XCUIApplication().screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    func testJournalAndHabitsTogether() {
        let app=XCUIApplication();app.launchArguments=["--ui-testing"];app.launch()
        if app.buttons["Inizia"].waitForExistence(timeout:8){app.buttons["Inizia"].tap()}
        XCTAssertTrue(app.textFields["rapidText"].waitForExistence(timeout:15));let quick=app.textFields["rapidText"];quick.tap();quick.typeText("Rivedere gli appunti\n")
        XCTAssertTrue(app.buttons["Completa Rivedere gli appunti"].waitForExistence(timeout:8));app.buttons["Completa Rivedere gli appunti"].tap();shot("01-Oggi")
        app.buttons["Scrivi nel diario"].tap();let title=app.textFields["journalTitle"];XCTAssertTrue(title.waitForExistence(timeout:8));title.tap();title.typeText("Una giornata da ricordare")
        let text=app.textViews["journalBody"];text.tap();text.typeText("Ho studiato con attenzione e raccolto una nuova idea.")
        app.buttons["Salva pagina"].tap();app.tabBars.buttons["Diario"].tap();XCTAssertTrue(app.staticTexts["Una giornata da ricordare"].waitForExistence(timeout:8));shot("02-Diario")
        app.staticTexts["Una giornata da ricordare"].tap();XCTAssertTrue(app.buttons["Condividi testo"].waitForExistence(timeout:8));shot("03-Pagina")
        app.tabBars.buttons["Agenda"].tap();XCTAssertTrue(app.buttons["Completa Rivedere gli appunti"].exists || app.buttons["Riapri Rivedere gli appunti"].exists);shot("04-Agenda")
        app.tabBars.buttons["Abitudini"].tap();XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout:8));shot("05-Abitudini")
        app.tabBars.buttons["Altro"].tap();app.buttons["Apple Watch e cattura rapida"].tap();XCTAssertTrue(app.staticTexts["Un pensiero, al polso."].waitForExistence(timeout:8));shot("06-AppleWatch")
        app.navigationBars.buttons.element(boundBy:0).tap();app.buttons["Modelli e raccolte"].tap();XCTAssertTrue(app.staticTexts["Gratitudine"].waitForExistence(timeout:8));shot("07-Modelli")
    }
    func testLocalHealthSection() {
        let app=XCUIApplication();app.launchArguments=["--ui-testing"];app.launch()
        if app.buttons["Inizia"].waitForExistence(timeout:8){app.buttons["Inizia"].tap()}
        XCTAssertTrue(app.buttons["Salute personale"].waitForExistence(timeout:10));app.buttons["Salute personale"].tap()
        XCTAssertTrue(app.buttons["Aggiungi"].waitForExistence(timeout:8));app.buttons["Aggiungi"].tap()
        let value=app.textFields["wellnessManualValue"];XCTAssertTrue(value.waitForExistence(timeout:8));value.tap();value.typeText("42")
        app.buttons["Salva campione"].tap();XCTAssertTrue(app.staticTexts["HRV · SDNN"].firstMatch.waitForExistence(timeout:8));shot("08-Salute")
        app.buttons["Recupero"].tap();shot("09-Recupero")
        app.buttons["Sonno"].tap();shot("10-Sonno")
        app.buttons["Trend"].tap();shot("11-Trend")
        app.swipeUp();app.swipeUp()
        app.buttons["Comandi Rapidi e sincronizzazione"].tap();XCTAssertTrue(app.buttons["Apri Comandi Rapidi"].waitForExistence(timeout:8));shot("12-ComandiSalute")
    }

}
