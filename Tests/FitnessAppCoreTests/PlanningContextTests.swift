import XCTest
@testable import FitnessAppCore

/// Planung-&-Trainingsbegleitung-Epic, P2.0 (docs/PLANUNG_BEGLEITUNG_AUDIT.md,
/// Abschnitt "P2.0 Datenvertrag ... Abnahme"): deckt die drei dort benannten
/// Validierungsregeln plus die `EnduranceModality`-Bruecke zu
/// `TrainingTypeKind`.
final class PlanningContextTests: XCTestCase {

    private func makeValidContext(
        goal: TrainingGoal = .hypertrophy,
        enduranceModality: EnduranceModality? = nil,
        runCoachEnabled: Bool = false,
        daysPerWeek: Int = 3,
        scheduling: SchedulingMode = .flexibleOrder,
        environment: EnvironmentType = .gym,
        equipmentProfile: UserEquipmentProfile = UserEquipmentProfile(),
        equipmentProfileConfirmedComplete: Bool = false
    ) -> PlanningContext {
        PlanningContext(
            goal: goal,
            enduranceModality: enduranceModality,
            runCoachEnabled: runCoachEnabled,
            daysPerWeek: daysPerWeek,
            sessionDurationMinutes: 60,
            scheduling: scheduling,
            environment: environment,
            equipmentProfile: equipmentProfile,
            equipmentProfileConfirmedComplete: equipmentProfileConfirmedComplete
        )
    }

    // MARK: - Abnahme 1: runCoachEnabled erfordert .running/.both

    func testRunCoachEnabledWithoutEnduranceModalityIsInvalid() {
        let context = makeValidContext(enduranceModality: nil, runCoachEnabled: true)
        XCTAssertFalse(context.isValid)
        XCTAssertTrue(context.issues.contains(.runCoachRequiresRunningOrBothModality))
    }

    func testRunCoachEnabledWithCyclingOnlyIsInvalid() {
        // Audit §5 "kein Radcoach": reines Radfahren darf den Laufcoach nie
        // tragen — er muss fuer diesen Zustand strukturell ungueltig sein.
        let context = makeValidContext(enduranceModality: .cycling, runCoachEnabled: true)
        XCTAssertFalse(context.isValid)
        XCTAssertTrue(context.issues.contains(.runCoachRequiresRunningOrBothModality))
    }

    func testRunCoachEnabledWithRunningIsValid() {
        let context = makeValidContext(enduranceModality: .running, runCoachEnabled: true)
        XCTAssertTrue(context.issues.isEmpty)
    }

    func testRunCoachEnabledWithBothIsValid() {
        let context = makeValidContext(enduranceModality: .both, runCoachEnabled: true)
        XCTAssertTrue(context.issues.isEmpty)
    }

    func testRunCoachDisabledIsAlwaysValidRegardlessOfModality() {
        for modality: EnduranceModality? in [nil, .running, .cycling, .both] {
            let context = makeValidContext(enduranceModality: modality, runCoachEnabled: false)
            XCTAssertTrue(context.issues.isEmpty, "runCoachEnabled=false darf nie an der Modalitaet scheitern (\(String(describing: modality)))")
        }
    }

    // MARK: - daysPerWeek

    func testNonPositiveDaysPerWeekIsInvalid() {
        let context = makeValidContext(daysPerWeek: 0)
        XCTAssertTrue(context.issues.contains(.daysPerWeekNotPositive(0)))
    }

    // MARK: - Abnahme 2: fixedWeekdays.count == daysPerWeek

    func testFixedWeekdaysCountMismatchIsInvalid() {
        let context = makeValidContext(daysPerWeek: 3, scheduling: .fixedWeekdays([2, 4]))
        XCTAssertTrue(context.issues.contains(.fixedWeekdaysCountMismatch(expected: 3, actual: 2)))
    }

    func testFixedWeekdaysMatchingCountIsValid() {
        let context = makeValidContext(daysPerWeek: 3, scheduling: .fixedWeekdays([2, 4, 6]))
        XCTAssertTrue(context.issues.isEmpty)
    }

    func testFixedWeekdaysOutOfRangeIsInvalid() {
        let context = makeValidContext(daysPerWeek: 2, scheduling: .fixedWeekdays([0, 8]))
        XCTAssertTrue(context.issues.contains(.fixedWeekdaysOutOfRange([0, 8])))
    }

    func testFixedWeekdaysDuplicateIsInvalid() {
        let context = makeValidContext(daysPerWeek: 2, scheduling: .fixedWeekdays([3, 3]))
        XCTAssertTrue(context.issues.contains(.fixedWeekdaysNotUnique([3, 3])))
    }

    func testFlexibleOrderNeverProducesSchedulingIssues() {
        let context = makeValidContext(daysPerWeek: 5, scheduling: .flexibleOrder)
        XCTAssertTrue(context.issues.isEmpty)
    }

    // MARK: - Abnahme 3: Equipment-Aufloesung nutzt den bestehenden Resolver

    func testGymEnvironmentWithoutConfirmationUsesExistingGymAssumptionNotASilentGap() {
        let context = makeValidContext(
            environment: .gym,
            equipmentProfile: UserEquipmentProfile(),
            equipmentProfileConfirmedComplete: false
        )
        let effective = context.effectiveEquipment
        XCTAssertEqual(effective.source, .gymAssumption)
        XCTAssertTrue(effective.isAssumption)
        XCTAssertEqual(effective.effectiveProfile.availability(for: .barbell), .available,
                       "Leeres Profil + Gym + nicht bestaetigt darf keine stille Luecke sein")
    }

    func testConfirmedCompleteProfileIsUsedAsIsEvenWhenEmpty() {
        let context = makeValidContext(
            environment: .gym,
            equipmentProfile: UserEquipmentProfile(),
            equipmentProfileConfirmedComplete: true
        )
        let effective = context.effectiveEquipment
        XCTAssertEqual(effective.source, .confirmed)
        XCTAssertEqual(effective.effectiveProfile.availability(for: .barbell), .unknown,
                       "Eine abgeschlossene, aber leere Erfassung ist eine echte Aussage - keine Gym-Annahme ueberschreibt sie")
    }

    func testHomeGymNeverGetsTheGymAssumption() {
        let context = makeValidContext(environment: .homeGym, equipmentProfileConfirmedComplete: false)
        XCTAssertEqual(context.effectiveEquipment.source, .unconfirmed)
    }

    // MARK: - EnduranceModality <-> TrainingTypeKind-Bruecke

    func testEnduranceModalityMapsOntoExistingTrainingTypeKinds() {
        XCTAssertEqual(EnduranceModality.running.trainingTypeKinds, [.running])
        XCTAssertEqual(EnduranceModality.cycling.trainingTypeKinds, [.cycling])
        XCTAssertEqual(EnduranceModality.both.trainingTypeKinds, [.running, .cycling])
    }

    // MARK: - Ein vollstaendig gueltiger Kontext

    func testFullyValidContextHasNoIssues() {
        let context = makeValidContext(
            goal: .hybrid,
            enduranceModality: .running,
            runCoachEnabled: true,
            daysPerWeek: 4,
            scheduling: .fixedWeekdays([2, 3, 5, 7]),
            environment: .homeGym,
            equipmentProfileConfirmedComplete: true
        )
        XCTAssertTrue(context.isValid)
        XCTAssertTrue(context.issues.isEmpty)
    }
}
