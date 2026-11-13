import XCTest
@testable import WeddingCore
final class DraftTests:XCTestCase {
    func testOpenEditorPreservesRemoteFieldNotEditedByUser() throws {let base = Guest(name:"Anna");var draft = base;draft.notes = "Locale";var current = base;current.diet = "Vegetariana";let merged = try DraftMerge.merge(base,edited:draft,current:current);XCTAssertEqual(merged.diet,"Vegetariana");XCTAssertEqual(merged.notes,"Locale")}
    func testOpenEditorSameFieldConflictRejected() {let base = Guest(name:"Anna");var draft = base;draft.notes = "Locale";var current = base;current.notes = "Partner";XCTAssertThrowsError(try DraftMerge.merge(base,edited:draft,current:current))}
    func testPaymentsAddedFromTwoOpenEditorsAreMergedByUUID() throws {let base = Expense(title:"Fiori");var draft = base;draft.payments = [Payment(amount:100)];var current = base;current.payments = [Payment(amount:200)];let merged = try DraftMerge.merge(base,edited:draft,current:current);XCTAssertEqual(merged.payments.count,2);XCTAssertEqual(merged.paid,300)}
    func testDeletedWhileEditingIsNotSilentlyRecreated() {let guest = Guest(name:"Anna");var current:[Guest] = [];XCTAssertThrowsError(try DraftMerge.upsert(guest,original:guest,in:&current));XCTAssertTrue(current.isEmpty)}
}
