import XCTest
@testable import DeltiqCore

/// Audit-Fund Modul 18: der TR-Zweig von `Steps.preferred()` fiel bei leerem
/// TR+DE nicht weiter auf EN zurueck, obwohl DE/EN bereits symmetrisch sind.
final class ExerciseInstructionsProviderFallbackTests: XCTestCase {

    func testTurkishPrefersOwnStepsWhenPresent() {
        let steps = ExerciseInstructionsProvider.Steps(de: ["DE"], en: ["EN"], tr: ["TR"])
        XCTAssertEqual(steps.preferred(languageCode: "tr"), ["TR"])
    }

    func testTurkishFallsBackToGermanWhenOnlyTurkishIsEmpty() {
        let steps = ExerciseInstructionsProvider.Steps(de: ["DE"], en: ["EN"], tr: [])
        XCTAssertEqual(steps.preferred(languageCode: "tr"), ["DE"])
    }

    func testTurkishFallsBackToEnglishWhenTurkishAndGermanAreBothEmpty() {
        let steps = ExerciseInstructionsProvider.Steps(de: [], en: ["Step 1", "Step 2"], tr: [])
        XCTAssertEqual(steps.preferred(languageCode: "tr"), ["Step 1", "Step 2"])
    }
}
