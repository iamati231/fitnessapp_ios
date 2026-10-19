#if canImport(SwiftUI)
import XCTest
import FitnessAppCore
@testable import FitnessAppUI

/// TestingBot-Regressionscheck (Deltiq-Abnahme): zweimal unabhängig
/// reproduziert — „Fertig" auf dem Plan-Vorschlag-Screen getippt, ohne
/// zuvor die Vorschau zu öffnen und „Diesen Plan wählen" zu bestätigen.
/// `finishOnboarding()` legte dann nur ein Profil an, nie den sichtbar
/// empfohlenen Plan — Dashboard zeigte „No active plan" ohne Hinweis.
/// Testet `OnboardingView.templateToAdopt(...)`, die reine Entscheidung
/// hinter dem Fix, direkt (keine @Environment-Abhängigkeit).
@available(iOS 17.0, macOS 14.0, *)
final class OnboardingFinishPlanSelectionTests: XCTestCase {
    private let recommended = ProgramTemplates.all[0]
    private let explicitlyChosen = ProgramTemplates.all[1]

    func testExplicitPreviewSelectionWinsOverRecommendation() {
        let result = OnboardingView.templateToAdopt(
            explicit: explicitlyChosen, hasCustomPlan: false, recommended: recommended
        )
        XCTAssertEqual(result?.id, explicitlyChosen.id)
    }

    func testCustomPlanWinsEvenWithoutExplicitTemplate() {
        let result = OnboardingView.templateToAdopt(
            explicit: nil, hasCustomPlan: true, recommended: recommended
        )
        XCTAssertNil(result, "ein gebauter Custom-Plan darf nicht durch die Empfehlung ersetzt werden")
    }

    func testFallsBackToRecommendationWhenNothingWasExplicitlyChosen() {
        let result = OnboardingView.templateToAdopt(
            explicit: nil, hasCustomPlan: false, recommended: recommended
        )
        XCTAssertEqual(result?.id, recommended.id,
                        "ohne explizite Auswahl muss die bereits gezeigte Top-Empfehlung uebernommen werden, nicht 'kein Plan'")
    }

    func testStaysWithoutPlanWhenNoRecommendationExists() {
        let result = OnboardingView.templateToAdopt(
            explicit: nil, hasCustomPlan: false, recommended: nil
        )
        XCTAssertNil(result, "ohne verfuegbare Empfehlung bleibt 'Fertig ohne Plan' weiterhin gueltig")
    }
}
#endif
