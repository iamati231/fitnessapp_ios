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

    // MARK: - confirmRemainingAsUnavailable (Phase 3: vollstaendige Bestaetigung)

    func testConfirmRemainingAsUnavailableLeavesAlreadyAvailableItemsUntouched() {
        var profile = UserEquipmentProfile(availability: [.kettlebell: .available], counts: [.kettlebell: 1])
        profile.confirmRemainingAsUnavailable()
        XCTAssertEqual(profile.availability(for: .kettlebell), .available)
        XCTAssertEqual(profile.count(for: .kettlebell), 1, "Stueckzahl bleibt beim Bestaetigen unangetastet")
    }

    func testConfirmRemainingAsUnavailableLeavesAlreadyUnavailableItemsUntouched() {
        var profile = UserEquipmentProfile(availability: [.rack: .unavailable])
        profile.confirmRemainingAsUnavailable()
        XCTAssertEqual(profile.availability(for: .rack), .unavailable)
    }

    func testConfirmRemainingAsUnavailableConvertsEveryUnknownItem() {
        var profile = UserEquipmentProfile(availability: [.kettlebell: .available])
        profile.confirmRemainingAsUnavailable()
        for item in EquipmentItem.allCases where item != .kettlebell {
            XCTAssertEqual(profile.availability(for: item), .unavailable,
                           "\(item) war nicht ausgewaehlt und muss nach der Bestaetigung als nicht verfuegbar gelten")
        }
        XCTAssertEqual(profile.availability(for: .kettlebell), .available)
    }

    func testConfirmRemainingAsUnavailableOnEmptyProfileMatchesBodyweightOnly() {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        for item in EquipmentItem.allCases {
            XCTAssertEqual(profile.availability(for: item), .unavailable)
        }
    }

    func testConfirmRemainingAsUnavailableIsIdempotent() {
        var profile = UserEquipmentProfile(availability: [.barbell: .available])
        profile.confirmRemainingAsUnavailable()
        let afterFirstCall = profile
        profile.confirmRemainingAsUnavailable()
        XCTAssertEqual(profile, afterFirstCall, "Ein zweiter Aufruf (z.B. nach einem App-Update mit neuen Items) aendert nichts an bereits entschiedenen Items")
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// Pflicht-Test 6): ein EXPLIZIT auf `.unknown` gesetztes Item (z.B.
    /// "Weiß ich noch nicht" bei Bank/Klimmzugstange) unterscheidet sich jetzt
    /// bewusst von einem nie angefassten Item (kein Dictionary-Eintrag) — nur
    /// Letzteres wird bei der vollstaendigen Bestaetigung zu `.unavailable`.
    /// Vor diesem Fix haetten beide Faelle identisch zu `.unavailable`
    /// gekippt, weil `availability(for:)` ueber `?? .unknown` beide Faelle
    /// ununterscheidbar macht — der Fix muss direkt am Dictionary pruefen.
    func testConfirmRemainingAsUnavailableNeverOverridesAnExplicitlyUnknownItem() {
        var explicit = UserEquipmentProfile()
        explicit.availability[.adjustableBench] = .unknown
        explicit.confirmRemainingAsUnavailable()
        XCTAssertEqual(explicit.availability(for: .adjustableBench), .unknown,
                       "Explizit 'weiss ich nicht' bleibt auch nach der vollstaendigen Bestaetigung unknown")
        XCTAssertEqual(explicit.availability(for: .barbell), .unavailable,
                       "Ein wirklich nie angefasstes Item kippt weiterhin wie gewohnt zu unavailable")

        var untouched = UserEquipmentProfile()
        untouched.confirmRemainingAsUnavailable()
        XCTAssertEqual(untouched.availability(for: .adjustableBench), .unavailable,
                       "Gegenprobe: ohne expliziten Eintrag bleibt das bisherige Verhalten (kippt zu unavailable)")
    }

    /// Vor Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md), Punkt "Stueckzahl
    /// unbekannt": ein ausgewaehltes Item OHNE erfasste Stueckzahl darf beim
    /// Bestaetigen weder (a) stillschweigend zu `.unavailable` kippen — die
    /// Bestaetigung aendert nur `.unknown`-Items, `.available` bleibt
    /// unangetastet, unabhaengig davon ob `counts` dafuer einen Eintrag hat —
    /// noch (b) danach optimistisch als "ausreichend" fuer eine Uebung mit
    /// Mindest-Stueckzahl > 1 gelten. End-to-End-Test, der beide Fakten
    /// zusammen statt nur je einzeln prueft (die bestehenden Tests oben
    /// decken sie bislang nur getrennt ab:
    /// `testConfirmRemainingAsUnavailableLeavesAlreadyAvailableItemsUntouched`
    /// nutzt eine GESETZTE Stueckzahl, `testItemAvailableWithUnrecordedCountIsUnknownNotSatisfied`
    /// ruft `confirmRemainingAsUnavailable()` gar nicht auf).
    func testSelectedItemWithUnrecordedCountSurvivesConfirmationAndStaysUnknownAgainstDoubleRequirement() {
        var profile = UserEquipmentProfile(availability: [.dumbbell: .available])
        XCTAssertNil(profile.count(for: .dumbbell), "Vorbedingung: Stueckzahl nie erfasst")

        profile.confirmRemainingAsUnavailable()

        XCTAssertEqual(profile.availability(for: .dumbbell), .available,
                       "Ausgewaehltes Item darf durch die Bestaetigung nicht zu .unavailable kippen")
        XCTAssertNil(profile.count(for: .dumbbell),
                     "Die Bestaetigung darf keine Stueckzahl erfinden")

        let result = ExerciseRequirement.item(.dumbbell, minimumCount: 2).evaluate(against: profile)
        XCTAssertEqual(result, .unknown(reasons: [
            UnmetReason(item: .dumbbell, requiredCount: 2, availability: .available, knownCount: nil)
        ]), "Vorhanden ohne bekannte Stueckzahl bleibt nach der Bestaetigung weiterhin unbekannt, nie 'erfuellt'")
    }

    // MARK: - legacyEquipmentPreferences (Rueckwaerts-Kompatibilitaet DEL-170)

    func testLegacyEquipmentPreferencesAlwaysIncludesBodyweight() {
        XCTAssertEqual(UserEquipmentProfile().legacyEquipmentPreferences, [.bodyweight])
    }

    func testLegacyEquipmentPreferencesOnlyCountsConfirmedAvailableItems() {
        let profile = UserEquipmentProfile(availability: [
            .kettlebell: .available,
            .barbell: .unknown,     // nicht bestaetigt -> zaehlt nicht
            .dumbbell: .unavailable // explizit nicht vorhanden -> zaehlt nicht
        ])
        XCTAssertEqual(profile.legacyEquipmentPreferences, [.bodyweight, .kettlebell])
    }

    func testLegacyEquipmentPreferencesMapsAllSixOverlappingItems() {
        let profile = UserEquipmentProfile(availability: [
            .dumbbell: .available, .kettlebell: .available, .barbell: .available,
            .resistanceBand: .available, .cableStation: .available, .machineStation: .available
        ])
        XCTAssertEqual(profile.legacyEquipmentPreferences, [
            .bodyweight, .dumbbell, .kettlebell, .barbell, .band, .cable, .machine
        ])
    }

    func testLegacyEquipmentPreferencesIgnoresAccessoriesWithoutOldModelEquivalent() {
        // Audit Abschnitt 3: Bank/Rack/Klimmzugstange existieren im alten
        // Equipment-Enum schlicht nicht - duerfen also auch in der Projektion
        // nichts beitragen.
        let profile = UserEquipmentProfile(availability: [
            .pullUpBar: .available, .flatBench: .available,
            .adjustableBench: .available, .rack: .available
        ])
        XCTAssertEqual(profile.legacyEquipmentPreferences, [.bodyweight])
    }
}
