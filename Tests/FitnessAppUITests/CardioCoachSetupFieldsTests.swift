#if canImport(SwiftUI)
import XCTest
import SwiftUI
@testable import FitnessAppUI
import FitnessAppCore

/// Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt: `fiveKReferenceErrorMessage` ist der einzige
/// Teil von `CardioCoachSetupFields` mit testbarer Logik ohne SwiftUI-Render-Harness (`public`,
/// kein SwiftData-Zugriff) - der Rest ist reines Layout, bereits ueber die drei Aufrufstellen
/// (`CardioGoalEditorPersistenceTests`, `PlanBuilderCardioProfileWiringTests`,
/// `OnboardingRunCoachGoalTests`) als korrekt eingebunden geprueft.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioCoachSetupFieldsTests: XCTestCase {

    private func fields(fiveKReferenceText: String) -> CardioCoachSetupFields {
        var draft = CardioCoachSetupDraft.empty
        draft = CardioCoachSetupDraft(
            goal: draft.goal, raceDate: draft.raceDate, weeklyBaseVolumeKm: draft.weeklyBaseVolumeKm,
            maxHeartRateBpm: draft.maxHeartRateBpm, fiveKReferenceText: fiveKReferenceText
        )
        return CardioCoachSetupFields(draft: .constant(draft))
    }

    func testNoErrorMessageWhenTextIsEmpty() {
        XCTAssertNil(fields(fiveKReferenceText: "").fiveKReferenceErrorMessage)
    }

    func testNoErrorMessageWhenTextIsValidMMSS() {
        XCTAssertNil(fields(fiveKReferenceText: "25:00").fiveKReferenceErrorMessage)
    }

    /// Fund B (uebernommen von `CardioGoalEditorView`s urspruenglicher Validierung): ein
    /// nicht-leerer, nicht parsbarer Text muss eine sichtbare Fehlermeldung ausloesen.
    func testErrorMessageWhenTextIsNonEmptyAndInvalid() {
        XCTAssertNotNil(fields(fiveKReferenceText: "not a time").fiveKReferenceErrorMessage)
    }
}
#endif
