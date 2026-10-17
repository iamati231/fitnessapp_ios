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
        sessionDurationMinutes: Int = 60,
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
            sessionDurationMinutes: sessionDurationMinutes,
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

    // MARK: - daysPerWeek: 1...7 unterschiedliche Kalendertage, keine impliziten Mehrfacheinheiten

    func testZeroDaysPerWeekIsInvalid() {
        let context = makeValidContext(daysPerWeek: 0)
        XCTAssertTrue(context.issues.contains(.daysPerWeekOutOfRange(0)))
    }

    func testNegativeDaysPerWeekIsInvalid() {
        let context = makeValidContext(daysPerWeek: -1)
        XCTAssertTrue(context.issues.contains(.daysPerWeekOutOfRange(-1)))
    }

    func testMoreThanSevenDaysPerWeekIsInvalid() {
        // Eine Woche hat nur sieben Kalendertage - 8 "unterschiedliche
        // Trainingstage" sind kein gueltiger Wert, auch nicht als stillschweigende
        // Ankuendigung mehrerer Einheiten an einem Tag.
        let context = makeValidContext(daysPerWeek: 8, scheduling: .flexibleOrder)
        XCTAssertTrue(context.issues.contains(.daysPerWeekOutOfRange(8)))
    }

    func testOneDayPerWeekIsValid() {
        let context = makeValidContext(daysPerWeek: 1, scheduling: .flexibleOrder)
        XCTAssertTrue(context.issues.isEmpty)
    }

    func testSevenDaysPerWeekIsValid() {
        // Obere Grenze: genau sieben ist noch gueltig (ein Trainingstag pro
        // Kalendertag), erst acht ueberschreitet die Woche.
        let context = makeValidContext(daysPerWeek: 7, scheduling: .flexibleOrder)
        XCTAssertTrue(context.issues.isEmpty)
    }

    // MARK: - sessionDurationMinutes muss positiv sein

    func testZeroSessionDurationIsInvalid() {
        let context = makeValidContext(sessionDurationMinutes: 0)
        XCTAssertTrue(context.issues.contains(.sessionDurationMinutesNotPositive(0)))
    }

    func testNegativeSessionDurationIsInvalid() {
        let context = makeValidContext(sessionDurationMinutes: -15)
        XCTAssertTrue(context.issues.contains(.sessionDurationMinutesNotPositive(-15)))
    }

    func testPositiveSessionDurationIsValid() {
        let context = makeValidContext(sessionDurationMinutes: 1)
        XCTAssertTrue(context.issues.isEmpty)
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

    /// P2.5: `supportsRunCoach` muss exakt dieselbe Regel abbilden wie
    /// `PlanningContextIssue.runCoachRequiresRunningOrBothModality` oben —
    /// wiederverwendet von `UserBodyProfile.setEnduranceModality`, das keinen
    /// vollstaendigen `PlanningContext` zur Hand hat (Tage/Dauer/Scheduling
    /// sind Plan-, nicht Profil-Eigenschaften).
    func testSupportsRunCoachMatchesPlanningContextInvariant() {
        XCTAssertTrue(EnduranceModality.running.supportsRunCoach)
        XCTAssertTrue(EnduranceModality.both.supportsRunCoach)
        XCTAssertFalse(EnduranceModality.cycling.supportsRunCoach)
    }

    /// RawValue-Stabilitaet (P2.5): `enduranceModalityRaw` auf
    /// `UserBodyProfile` persistiert exakt diese drei Strings — eine
    /// zukuenftige Umbenennung eines Cases wuerde Bestandsdaten brechen.
    func testEnduranceModalityRawValuesAreStable() {
        XCTAssertEqual(EnduranceModality.running.rawValue, "running")
        XCTAssertEqual(EnduranceModality.cycling.rawValue, "cycling")
        XCTAssertEqual(EnduranceModality.both.rawValue, "both")
    }

    /// P4.1: jede Modalitaet braucht ein eigenes, nicht-leeres Symbol fuer
    /// Auswahl-Karten (Onboarding-Ausdauerform-Schritt).
    func testEveryEnduranceModalityHasANonEmptySymbol() {
        for modality in EnduranceModality.allCases {
            XCTAssertFalse(modality.symbol.isEmpty)
        }
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
