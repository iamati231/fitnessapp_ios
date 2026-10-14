import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
/// §1/§2/§4): `EquipmentPlanningContext`/`EquipmentPlanningResolver` +
/// `UserEquipmentProfile.gymDefault`. Deckt Pflicht-Tests 1, 2, 9, 10.
final class EquipmentPlanningContextTests: XCTestCase {

    // MARK: - gymDefault

    /// §4 der Vorgabe: nur die als "üblich" dokumentierten Items, Kettlebell
    /// und Widerstandsband bewusst NICHT angenommen.
    func testGymDefaultAssumesOnlyTheDocumentedStandardItems() {
        let profile = UserEquipmentProfile.gymDefault
        for item: EquipmentItem in [.dumbbell, .barbell, .adjustableBench, .rack, .cableStation, .machineStation, .pullUpBar] {
            XCTAssertEqual(profile.availability(for: item), .available, "\(item) sollte in der Gym-Annahme verfuegbar sein")
        }
        XCTAssertEqual(profile.availability(for: .kettlebell), .unknown, "Kettlebell ist nicht universell genug fuer eine Annahme")
        XCTAssertEqual(profile.availability(for: .resistanceBand), .unknown, "Widerstandsband ist nicht universell genug fuer eine Annahme")
        XCTAssertEqual(profile.availability(for: .flatBench), .unknown, "flatBench wird nie isoliert verlangt, keine zusaetzliche Behauptung noetig")
    }

    // MARK: - Pflicht-Test 1: Gym ohne Anpassung

    func testGymWithoutCustomizationUsesGymDefaultAsAssumptionNotConfirmed() {
        let context = EquipmentPlanningResolver.resolve(
            environment: .gym, individualProfile: UserEquipmentProfile(), confirmedComplete: false
        )
        XCTAssertEqual(context.source, .gymAssumption)
        XCTAssertTrue(context.isAssumption)
        XCTAssertEqual(context.effectiveProfile.availability(for: .barbell), .available)
        XCTAssertEqual(context.effectiveProfile.availability(for: .kettlebell), .unknown)
    }

    // MARK: - Pflicht-Test 2: Gym mit explizit fehlendem Gerät

    /// Ein individuell bestaetigt FEHLENDES Geraet darf die Gym-Annahme
    /// niemals ueberschreiben — auch wenn es Teil des Standard-Gym-Profils
    /// waere.
    func testGymDefaultNeverOverridesAnExplicitlyMissingItem() {
        var individual = UserEquipmentProfile()
        individual.availability[.rack] = .unavailable
        let context = EquipmentPlanningResolver.resolve(
            environment: .gym, individualProfile: individual, confirmedComplete: false
        )
        XCTAssertEqual(context.source, .gymAssumption)
        XCTAssertEqual(context.effectiveProfile.availability(for: .rack), .unavailable,
                       "Individuell bestaetigt fehlendes Rack bleibt fehlend, trotz Gym-Annahme")
        // Alles andere bleibt die Annahme — eine einzelne Korrektur loescht
        // nicht die gesamte Annahme.
        XCTAssertEqual(context.effectiveProfile.availability(for: .barbell), .available)
    }

    /// Gegenprobe: eine individuell bestaetigt VORHANDENE Kettlebell (die
    /// Gym-Annahme selbst laesst Kettlebell offen) wird uebernommen.
    func testGymDefaultIncorporatesAnIndividuallyConfirmedExtraItem() {
        var individual = UserEquipmentProfile()
        individual.availability[.kettlebell] = .available
        individual.counts[.kettlebell] = 2
        let context = EquipmentPlanningResolver.resolve(
            environment: .gym, individualProfile: individual, confirmedComplete: false
        )
        XCTAssertEqual(context.effectiveProfile.availability(for: .kettlebell), .available)
        XCTAssertEqual(context.effectiveProfile.count(for: .kettlebell), 2)
    }

    /// Eine vollstaendig ABGESCHLOSSENE Erfassung (User hat im Gym
    /// "Ausstattung anpassen" durchlaufen und bestaetigt) gewinnt immer —
    /// keine Gym-Annahme mehr, jedes Item ist jetzt explizit entschieden.
    func testCompletedConfirmationWinsOverGymAssumptionEvenInGym() {
        var individual = UserEquipmentProfile()
        individual.confirmRemainingAsUnavailable() // alles .unavailable
        let context = EquipmentPlanningResolver.resolve(
            environment: .gym, individualProfile: individual, confirmedComplete: true
        )
        XCTAssertEqual(context.source, .confirmed)
        XCTAssertFalse(context.isAssumption)
        XCTAssertEqual(context.effectiveProfile.availability(for: .barbell), .unavailable,
                       "Eine abgeschlossene Bestaetigung ersetzt die Gym-Annahme vollstaendig, auch fuer Standard-Items")
    }

    // MARK: - Pflicht-Test 9/10: Home-Gym/Kein Equipment ohne Gym-Annahme

    /// Home-Gym und Kein-Equipment bekommen NIE die Gym-Annahme — nur der
    /// reale, bisher erfasste Stand (unveraendertes Phase-3-Verhalten).
    func testHomeGymAndNoEquipmentNeverGetTheGymAssumption() {
        for env: EnvironmentType in [.homeGym, .noEquipment] {
            let context = EquipmentPlanningResolver.resolve(
                environment: env, individualProfile: UserEquipmentProfile(), confirmedComplete: false
            )
            XCTAssertEqual(context.source, .unconfirmed, "\(env) darf keine Gym-Annahme bekommen")
            XCTAssertFalse(context.isAssumption)
            XCTAssertEqual(context.effectiveProfile.availability(for: .barbell), .unknown,
                           "\(env) ohne Bestaetigung bleibt alles unknown, keine Annahme fuellt die Luecke")
        }
    }

    /// "Nein, nur Körpergewicht" (Pflicht-Test 9): vollstaendig bestaetigtes,
    /// leeres Profil bleibt `.confirmed` — kein Gym-Bezug, keine Annahme.
    func testConfirmedBodyweightOnlyIsConfirmedNotAssumption() {
        var individual = UserEquipmentProfile()
        individual.confirmRemainingAsUnavailable()
        let context = EquipmentPlanningResolver.resolve(
            environment: .noEquipment, individualProfile: individual, confirmedComplete: true
        )
        XCTAssertEqual(context.source, .confirmed)
        XCTAssertTrue(EquipmentItem.allCases.allSatisfy { context.effectiveProfile.availability(for: $0) == .unavailable })
    }

    /// "Später entscheiden" (Pflicht-Test 10): `confirmedComplete` bleibt
    /// `false`, nichts wird automatisch zu `.unavailable` — Resolver gibt
    /// exakt das unveraenderte, noch unvollstaendige Profil zurueck.
    func testLaterDecisionStaysUnconfirmedWithNoAutomaticAbsenceConfirmation() {
        var individual = UserEquipmentProfile()
        individual.availability[.dumbbell] = .available // einzelne Teil-Angabe
        let context = EquipmentPlanningResolver.resolve(
            environment: .homeGym, individualProfile: individual, confirmedComplete: false
        )
        XCTAssertEqual(context.source, .unconfirmed)
        XCTAssertEqual(context.effectiveProfile.availability(for: .dumbbell), .available)
        XCTAssertEqual(context.effectiveProfile.availability(for: .barbell), .unknown,
                       "Nicht angefasste Items bleiben unknown, werden NICHT automatisch zu unavailable")
    }
}
