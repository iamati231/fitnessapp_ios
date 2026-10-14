import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 2 (PLAN_EQUIPMENT_MATCHING_AUDIT.md):
/// Wahrheitstabellen-Tests fuer `ExerciseRequirement.evaluate` — die
/// dreistufige (verfuegbar/nicht verfuegbar/unbekannt) Pruefung von UND/
/// ODER-Anforderungsbaeumen.
final class EquipmentRequirementTests: XCTestCase {

    // MARK: - UserEquipmentProfile Defaults

    func testUnrecordedItemIsUnknownNotUnavailable() {
        let profile = UserEquipmentProfile()
        XCTAssertEqual(profile.availability(for: .kettlebell), .unknown,
                       "Eine leere (z.B. alte) Auswahl bleibt unbekannt, nicht automatisch nicht-vorhanden")
    }

    func testUnrecordedCountIsNilNotZero() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .available])
        XCTAssertNil(profile.count(for: .kettlebell), "Vorhanden ohne erfasste Stueckzahl ist nil, nicht 0")
    }

    // MARK: - .item — einzelnes Requirement ohne Stueckzahl

    func testItemAvailableIsSatisfied() {
        let profile = UserEquipmentProfile(availability: [.pullUpBar: .available])
        XCTAssertEqual(ExerciseRequirement.item(.pullUpBar).evaluate(against: profile), .satisfied)
    }

    func testItemUnavailableIsUnmetWithReason() {
        let profile = UserEquipmentProfile(availability: [.pullUpBar: .unavailable])
        let result = ExerciseRequirement.item(.pullUpBar).evaluate(against: profile)
        XCTAssertEqual(result, .unmet(reasons: [
            UnmetReason(item: .pullUpBar, requiredCount: 1, availability: .unavailable, knownCount: nil)
        ]))
    }

    func testItemUnknownIsUnknownWithReason() {
        let profile = UserEquipmentProfile()
        let result = ExerciseRequirement.item(.adjustableBench).evaluate(against: profile)
        XCTAssertEqual(result, .unknown(reasons: [
            UnmetReason(item: .adjustableBench, requiredCount: 1, availability: .unknown, knownCount: nil)
        ]))
    }

    // MARK: - .item mit Mindest-Stueckzahl

    func testItemWithSufficientCountIsSatisfied() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .available], counts: [.kettlebell: 2])
        XCTAssertTrue(ExerciseRequirement.item(.kettlebell, minimumCount: 2).evaluate(against: profile).isSatisfied)
    }

    func testItemWithInsufficientCountIsUnmet() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .available], counts: [.kettlebell: 1])
        let result = ExerciseRequirement.item(.kettlebell, minimumCount: 2).evaluate(against: profile)
        XCTAssertEqual(result, .unmet(reasons: [
            UnmetReason(item: .kettlebell, requiredCount: 2, availability: .available, knownCount: 1)
        ]), "1 Kettlebell reicht nicht fuer eine Doppel-Kettlebell-Uebung")
    }

    func testItemAvailableWithUnrecordedCountIsUnknownNotSatisfied() {
        let profile = UserEquipmentProfile(availability: [.dumbbell: .available])
        let result = ExerciseRequirement.item(.dumbbell, minimumCount: 2).evaluate(against: profile)
        XCTAssertEqual(result, .unknown(reasons: [
            UnmetReason(item: .dumbbell, requiredCount: 2, availability: .available, knownCount: nil)
        ]), "Vorhanden, aber Stueckzahl nie erfasst -> unbekannt, nie optimistisch 'erfuellt'")
    }

    func testMinimumCountIsIgnoredForItemsThatDontSupportCount() {
        // Rack unterstuetzt keine Stueckzahl (supportsCount == false) -> ein
        // versehentliches minimumCount:2 blockiert nicht kuenstlich.
        let profile = UserEquipmentProfile(availability: [.rack: .available])
        XCTAssertTrue(ExerciseRequirement.item(.rack, minimumCount: 2).evaluate(against: profile).isSatisfied)
    }

    // MARK: - .all (UND)

    func testAllEmptyIsVacuouslySatisfied() {
        XCTAssertTrue(ExerciseRequirement.all([]).evaluate(against: UserEquipmentProfile()).isSatisfied)
    }

    func testAllSatisfiedWhenEveryChildSatisfied() {
        let profile = UserEquipmentProfile(availability: [.dumbbell: .available, .adjustableBench: .available])
        let requirement = ExerciseRequirement.all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])
        let profileWithCount = UserEquipmentProfile(
            availability: profile.availability, counts: [.dumbbell: 2]
        )
        XCTAssertTrue(requirement.evaluate(against: profileWithCount).isSatisfied, "Incline DB Press Beispiel aus dem Audit")
    }

    func testAllIsDefinitelyUnmetWhenOneChildDefinitelyUnmetEvenIfAnotherIsUnknown() {
        let profile = UserEquipmentProfile(availability: [.dumbbell: .unavailable]) // .adjustableBench: unknown
        let requirement = ExerciseRequirement.all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])
        guard case let .unmet(reasons) = requirement.evaluate(against: profile) else {
            return XCTFail("Ein definitiv unerfuelltes Kind macht das gesamte UND definitiv unerfuellt")
        }
        XCTAssertEqual(reasons, [UnmetReason(item: .dumbbell, requiredCount: 2, availability: .unavailable, knownCount: nil)])
    }

    func testAllIsUnknownWhenNoChildUnmetButOneUnknown() {
        let profile = UserEquipmentProfile(availability: [.dumbbell: .available], counts: [.dumbbell: 2])
        // .adjustableBench ist unrecorded -> unknown
        let requirement = ExerciseRequirement.all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])
        guard case let .unknown(reasons) = requirement.evaluate(against: profile) else {
            return XCTFail("Kein Kind definitiv unerfuellt, aber eines unbekannt -> das Ganze ist unbekannt")
        }
        XCTAssertEqual(reasons, [UnmetReason(item: .adjustableBench, requiredCount: 1, availability: .unknown, knownCount: nil)])
    }

    // MARK: - .any (ODER)

    func testAnyEmptyIsVacuouslyUnmet() {
        guard case .unmet = ExerciseRequirement.any([]).evaluate(against: UserEquipmentProfile()) else {
            return XCTFail("Keine Alternative kann nie erfuellt sein")
        }
    }

    func testAnySatisfiedWhenOneChildSatisfiedEvenIfOthersUnmet() {
        // Goblet Squat Beispiel aus dem Audit: Kettlebell ODER Kurzhantel.
        let profile = UserEquipmentProfile(availability: [.kettlebell: .unavailable, .dumbbell: .available])
        let requirement = ExerciseRequirement.any([.item(.kettlebell), .item(.dumbbell)])
        XCTAssertTrue(requirement.evaluate(against: profile).isSatisfied)
    }

    func testAnyIsUnmetWhenAllChildrenDefinitelyUnmet() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .unavailable, .dumbbell: .unavailable])
        let requirement = ExerciseRequirement.any([.item(.kettlebell), .item(.dumbbell)])
        guard case let .unmet(reasons) = requirement.evaluate(against: profile) else {
            return XCTFail("Beide Alternativen definitiv nicht vorhanden -> das ODER ist definitiv unerfuellt")
        }
        XCTAssertEqual(Set(reasons.map(\.item)), [.kettlebell, .dumbbell])
    }

    func testAnyIsUnknownWhenNoChildSatisfiedButOneUnknown() {
        // Eine Alternative ist ausgeschlossen, die andere noch nicht erfasst
        // -> insgesamt unbekannt (koennte noch klappen), nicht unerfuellt.
        let profile = UserEquipmentProfile(availability: [.kettlebell: .unavailable])
        let requirement = ExerciseRequirement.any([.item(.kettlebell), .item(.dumbbell)])
        guard case let .unknown(reasons) = requirement.evaluate(against: profile) else {
            return XCTFail("Eine unbekannte Alternative macht das ODER unbekannt, nicht unerfuellt")
        }
        XCTAssertEqual(Set(reasons.map(\.item)), [.kettlebell, .dumbbell],
                       "Sowohl die ausgeschlossene als auch die noch unklare Alternative gehoeren in die Begruendung")
    }

    // MARK: - Realistische, zusammengesetzte Beispiele aus dem Audit

    /// Chest-supported DB Row: passende Kurzhanteln UND eine passende
    /// Schraegbank fuer genau diese Variante.
    func testChestSupportedRowRequiresDumbbellsAndInclineBench() {
        let requirement = ExerciseRequirement.all([
            .item(.dumbbell, minimumCount: 2),
            .item(.adjustableBench)
        ])
        let missingBench = UserEquipmentProfile(availability: [.dumbbell: .available], counts: [.dumbbell: 2])
        guard case let .unknown(reasons) = requirement.evaluate(against: missingBench) else {
            return XCTFail("Bank nie erfasst -> unbekannt")
        }
        XCTAssertEqual(reasons.first?.item, .adjustableBench)

        let fullyEquipped = UserEquipmentProfile(
            availability: [.dumbbell: .available, .adjustableBench: .available],
            counts: [.dumbbell: 2]
        )
        XCTAssertTrue(requirement.evaluate(against: fullyEquipped).isSatisfied)
    }

    /// Floor Press DB: nur Kurzhanteln, explizit KEINE Bank noetig.
    func testFloorPressRequiresOnlyDumbbellsNoBench() {
        let requirement = ExerciseRequirement.item(.dumbbell, minimumCount: 2)
        let profile = UserEquipmentProfile(availability: [.dumbbell: .available], counts: [.dumbbell: 2])
        XCTAssertTrue(requirement.evaluate(against: profile).isSatisfied)
    }
}
