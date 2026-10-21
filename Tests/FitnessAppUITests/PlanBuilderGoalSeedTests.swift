#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import FitnessAppCore
@testable import FitnessAppUI

/// Deltiq-Geraeteabnahme (Runde 7, `docs/DELTIQ_DEVICE_ACCEPTANCE.md`, A01):
/// `PlanBuilderView`s eingebetteter Ziel-Schritt fragte `trainingGoal`
/// nochmal komplett von Null ab, obwohl `OnboardingView`s eigener,
/// frueherer Coaching-Step die Antwort bereits kennt - derselbe doppelte-
/// Abfrage-Fehler, den das P0-Audit fuer Equipment bereits behoben hatte
/// (siehe `init(initialInput:)`-Doku), hier aber fuer Ziel/Tage noch offen
/// war. `GoalCard.seeded(from:)` ist die reine Zuordnungslogik dahinter -
/// unabhaengig von SwiftUI-State testbar.
@available(iOS 17.0, macOS 14.0, *)
final class PlanBuilderGoalSeedTests: XCTestCase {

    func testSeedsMatchingCardForEachMappableGoal() {
        XCTAssertEqual(PlanBuilderView.GoalCard.seeded(from: .hypertrophy), .strengthFocus)
        XCTAssertEqual(PlanBuilderView.GoalCard.seeded(from: .strength), .strengthFocus)
        XCTAssertEqual(PlanBuilderView.GoalCard.seeded(from: .hybrid), .hybrid)
        XCTAssertEqual(PlanBuilderView.GoalCard.seeded(from: .endurance), .endurance)
        XCTAssertEqual(PlanBuilderView.GoalCard.seeded(from: .functional), .generalFitness)
    }

    /// `.weightLoss` hat keine eigene Zielkarte im Builder (siehe Typ-Doku) -
    /// bleibt bewusst unausgewaehlt statt einer falschen/stillen Zuordnung.
    func testWeightLossHasNoMappableCard() {
        XCTAssertNil(PlanBuilderView.GoalCard.seeded(from: .weightLoss))
    }
}
#endif
