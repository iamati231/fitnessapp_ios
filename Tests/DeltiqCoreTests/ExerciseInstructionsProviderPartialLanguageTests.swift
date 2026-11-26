import XCTest
@testable import DeltiqCore

/// Audit-Fund Modul 18: ein fehlender Sprach-Key im JSON (nicht nur ein
/// leeres Array) verwarf bisher den gesamten Eintrag inklusive der beiden
/// anderen, vollstaendig vorhandenen Sprachen.
final class ExerciseInstructionsProviderPartialLanguageTests: XCTestCase {

    func testEntryWithMissingLanguageKeyKeepsTheOtherTwoLanguages() {
        let steps = ExerciseInstructionsProvider.parseSteps(from: ["de": ["Schritt 1"], "en": ["Step 1"]])
        XCTAssertEqual(steps?.de, ["Schritt 1"])
        XCTAssertEqual(steps?.en, ["Step 1"])
        XCTAssertEqual(steps?.tr, [])
    }

    func testEntryWithAllLanguagesEmptyOrMissingIsDropped() {
        XCTAssertNil(ExerciseInstructionsProvider.parseSteps(from: [:]))
    }
}
