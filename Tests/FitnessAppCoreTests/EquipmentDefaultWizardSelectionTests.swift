import XCTest
@testable import FitnessAppCore

/// Ticket "Gym: Alle Gewichte und Geraete standardmaessig beruecksichtigen":
/// deckt `Equipment.defaultWizardSelection`, das `PlanBuilderView`s
/// Equipment-Wizard einmalig vorbefuellt (siehe dortige `.onAppear`-Doku).
final class EquipmentDefaultWizardSelectionTests: XCTestCase {

    func testGymWithoutExplicitInputSelectsEveryEquipmentItem() {
        let result = Equipment.defaultWizardSelection(forEnvironment: .gym, hasExplicitInput: false)
        XCTAssertEqual(result, Set(Equipment.allCases))
    }

    func testGymWithExplicitInputAppliesNoDefault() {
        // Cardio-Handoff/"Plan anpassen"/Onboarding geben die Auswahl schon
        // vor - der Gym-Default darf sie nie ueberschreiben.
        let result = Equipment.defaultWizardSelection(forEnvironment: .gym, hasExplicitInput: true)
        XCTAssertNil(result)
    }

    func testNonGymEnvironmentsApplyNoDefault() {
        for environment: EnvironmentType in [.homeGym, .noEquipment] {
            XCTAssertNil(
                Equipment.defaultWizardSelection(forEnvironment: environment, hasExplicitInput: false),
                "\(environment) soll den bestehenden (leeren) Default behalten"
            )
        }
    }
}
