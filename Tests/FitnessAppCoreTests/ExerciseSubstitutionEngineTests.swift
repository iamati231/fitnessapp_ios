import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 5 (PLAN_SUBSTITUTION_ENGINE.md): Core-Tests
/// 1-14 + 17 der Testvorgabe. Tests 15-16 (Varianten-uebergreifende Auswahl)
/// leben bei der Phase-5.3-Integration (PlanMatchmaker-Erweiterung).
final class ExerciseSubstitutionEngineTests: XCTestCase {

    private func spec(
        _ name: String, sets: Int = 3, repsMin: Int = 8, repsMax: Int = 12,
        rest: Int = 90, rir: Float = 2.0, isCardio: Bool = false, role: ExerciseRole = .workingSet
    ) -> ExerciseSpec {
        ExerciseSpec(name: name, sets: sets, repsMin: repsMin, repsMax: repsMax, restSeconds: rest, targetRir: rir, isCardio: isCardio, role: role)
    }

    private func day(
        _ exercises: [ExerciseSpec], sequenceIndex: Int = 1, timeFormat: WorkoutTimeFormat? = nil,
        timeCapMinutes: Int? = nil, circuitRounds: Int? = nil, circuitRestSeconds: Int? = nil, circuitMode: CircuitRoundMode? = nil
    ) -> DaySpec {
        DaySpec(
            name: "Tag \(sequenceIndex)", type: .fullBody, sequenceIndex: sequenceIndex, exercises: exercises,
            timeFormat: timeFormat, timeCapMinutes: timeCapMinutes,
            circuitRounds: circuitRounds, circuitRestSeconds: circuitRestSeconds, circuitMode: circuitMode
        )
    }

    private func variant(_ days: [DaySpec], against profile: UserEquipmentProfile) -> CheckedPlanVariant {
        CheckedPlanVariant(profile: nil, days: days, equipmentStatus: PlanEquipmentChecker.check(days: days, against: profile))
    }

    private var strengthContext: SubstitutionContext { SubstitutionContext(goal: .strength, experienceTrack: .experienced) }
    private var hypertrophyContext: SubstitutionContext { SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced) }
    private var starterHypertrophyContext: SubstitutionContext { SubstitutionContext(goal: .hypertrophy, experienceTrack: .starter) }

    private func fullyConfirmedProfile(available: [EquipmentItem: Int?] = [:]) -> UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        for (item, count) in available {
            profile.availability[item] = .available
            if let count { profile.counts[item] = count }
        }
        profile.confirmRemainingAsUnavailable()
        return profile
    }

    // MARK: - 1. Vollstaendig kompatible Variante -> keine Aenderung

    func testFullyCompatibleVariantProducesNoChangesAndPreservesExactOriginalValues() {
        let original = day([spec("Kettlebell Swing", sets: 3, repsMin: 12, repsMax: 15)])
        let profile = fullyConfirmedProfile(available: [.kettlebell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty)
        XCTAssertTrue(draft.unresolved.isEmpty)
        XCTAssertEqual(draft.adaptedDays, [original], "Exakt die Original-Werte, keine Transformation")
        XCTAssertEqual(draft.finalEquipmentStatus, .available)
        XCTAssertTrue(draft.isFullyResolved)
    }

    // MARK: - 2. Unbekannte Original-Anforderung -> kein spekulativer Tausch

    func testUnknownOriginalRequirementNeverTriggersSpeculativeSubstitution() {
        // "Kniebeuge" hat eine freigegebene Regel (R2) - aber mit komplett
        // unbestaetigtem Profil (alles .unknown) ist die Anforderung
        // UNBEKANNT, nicht definitiv fehlend. Der Engine darf trotz
        // vorhandener Regel NICHT raten.
        let original = day([spec("Kniebeuge", repsMax: 12)])
        let profile = UserEquipmentProfile() // alles .unknown
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Unbekannt darf nie automatisch ersetzt werden, auch wenn eine Regel existiert")
        XCTAssertEqual(draft.unresolved.count, 1)
        guard case .needsClarification = draft.unresolved.first?.reason else {
            return XCTFail("Erwartet .needsClarification, nicht .noApprovedSubstitute — die Uebung ist unbekannt, nicht 'keine Regel gefunden'")
        }
        XCTAssertEqual(draft.adaptedDays, [original])
    }

    // MARK: - 3. Nicht annotierte Quelle/Ziel -> nie automatisch verfuegbar

    func testUnannotatedSourceWithoutRegisteredRuleNeedsClarificationNotSubstitution() {
        // "Box Jump" ist bewusst nicht annotiert (siehe PLAN_EQUIPMENT_
        // MATCHING_AUDIT.md Abschnitt 13.1) und hat keine Regel.
        let original = day([spec("Box Jump")])
        let profile = fullyConfirmedProfile()
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty)
        guard case .needsClarification(.notAnnotated) = draft.unresolved.first?.reason else {
            return XCTFail("Erwartet .needsClarification(.notAnnotated)")
        }
    }

    func testUnannotatedTargetIsNeverAcceptedEvenIfARuleProposesIt() {
        // Synthetische Test-Regel (NICHT Teil des Produktiv-Katalogs):
        // mapped auf ein Ziel ohne equipmentRequirement ("Box Jump").
        let fakeRule = ReviewedSubstitutionRule(
            id: "test_unannotated_target", sourceExerciseName: "Front Squat", targetExerciseName: "Box Jump",
            reasonKey: "test.reason"
        ) { original, _ in
            ExerciseSpec(name: "Box Jump", sets: original.sets, repsMin: original.repsMin, repsMax: original.repsMax, restSeconds: original.restSeconds, targetRir: original.targetRir, role: original.role)
        }
        let original = day([spec("Front Squat")])
        let profile = fullyConfirmedProfile()
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), rules: [fakeRule], context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Ein nicht annotiertes Ziel darf nie akzeptiert werden, auch wenn eine Regel es vorschlaegt")
        XCTAssertEqual(draft.unresolved.first?.reason, .noApprovedSubstitute)
    }

    // MARK: - 4. Fehlende Bank + geprüftes Ziel -> nur Kandidat, wenn restliches Equipment passt

    func testMissingBenchSubstitutesToNonBenchTargetWhenRemainingEquipmentMatches() {
        let original = day([spec("Bulgarische Kniebeuge (KH)")])
        // 2 Kurzhanteln bestaetigt, JEDE Bank bestaetigt NICHT vorhanden.
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.count, 1)
        XCTAssertEqual(draft.replacements.first?.replacementName, "Ausfallschritte (KH)")
        XCTAssertEqual(draft.finalEquipmentStatus, .available)
        XCTAssertTrue(draft.isFullyResolved)
    }

    func testMissingBenchDoesNotSubstituteWhenTargetAlsoFailsOnRemainingEquipment() {
        let original = day([spec("Bulgarische Kniebeuge (KH)")])
        // Nur 1 Kurzhantel bestaetigt — "Ausfallschritte (KH)" braucht
        // ebenfalls 2, also faellt auch das Ziel durch.
        let profile = fullyConfirmedProfile(available: [.dumbbell: 1])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Das vorgeschlagene Ziel scheitert selbst am Profil — keine Substitution")
        XCTAssertEqual(draft.unresolved.first?.reason, .noApprovedSubstitute)
    }

    // MARK: - 5. Eine Kettlebell -> kein Zwei-Kettlebell-Regel-Ziel

    func testSingleKettlebellNeverSatisfiesADoubleKettlebellRuleTarget() {
        let fakeRule = ReviewedSubstitutionRule(
            id: "test_one_to_two_kb", sourceExerciseName: "Kettlebell Swing", targetExerciseName: "Kettlebell Front Squat",
            reasonKey: "test.reason"
        ) { original, _ in
            ExerciseSpec(name: "Kettlebell Front Squat", sets: original.sets, repsMin: original.repsMin, repsMax: original.repsMax, restSeconds: original.restSeconds, targetRir: original.targetRir, role: original.role)
        }
        // Quelle kuenstlich als "missing" erzwingen: Kettlebell bestaetigt
        // NICHT vorhanden macht "Kettlebell Swing" selbst .unmet.
        let original = day([spec("Kettlebell Swing")])
        let profile = fullyConfirmedProfile() // alles unavailable, auch Kettlebell
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), rules: [fakeRule], context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Zwei-Kettlebell-Ziel kann mit null bestaetigten Kettlebells nie erfuellt sein")
    }

    // MARK: - 6. Ziel-spezifischer Kraft-Anker -> irrefuehrender Ersatz wird abgelehnt

    func testStrengthGoalRejectsSquatToGobletSquatSubstitution() {
        let original = day([spec("Kniebeuge", repsMin: 5, repsMax: 5)])
        let profile = fullyConfirmedProfile() // Langhantel+Rack fehlen
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: strengthContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Kraft-Ziel darf den Kraft-Anker 'Kniebeuge' nie durch Goblet Squat ersetzen")
        XCTAssertEqual(draft.unresolved.first?.reason, .noApprovedSubstitute)
    }

    func testHypertrophyGoalWithHighRepsAllowsSquatToGobletSquatSubstitution() {
        let original = day([spec("Kniebeuge", repsMin: 10, repsMax: 12)])
        let profile = fullyConfirmedProfile(available: [.dumbbell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.first?.replacementName, "Goblet Squat")
    }

    // MARK: - 7. Starter -> kein schwererer Ersatz nur um Equipment zu erfuellen

    func testStarterTrackRejectsChestSupportedRowToSeatedCableRowSubstitution() {
        let original = day([spec("Chest Supported Row (KH)")])
        let profile = fullyConfirmedProfile(available: [.cableStation: nil]) // Bank fehlt, Kabelstation da
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: starterHypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Sitzendes Kabelrudern verlangt mehr Rumpfstabilisation — fuer Starter ausgeschlossen")
    }

    func testExperiencedTrackAllowsChestSupportedRowToSeatedCableRowSubstitution() {
        let original = day([spec("Chest Supported Row (KH)")])
        let profile = fullyConfirmedProfile(available: [.cableStation: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.first?.replacementName, "Kabelrudern sitzend")
    }

    // MARK: - 8. Kein freigegebener Kandidat -> Luecke bleibt, keine Loeschung

    func testNoApprovedCandidateLeavesOriginalGapInPlaceWithoutDeletion() {
        let original = day([spec("Front Squat")]) // keine Regel registriert
        let profile = fullyConfirmedProfile()
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty)
        XCTAssertEqual(draft.adaptedDays.first?.exercises, [spec("Front Squat")], "Die Uebung bleibt unveraendert stehen, wird nicht entfernt")
        XCTAssertEqual(draft.unresolved.first?.reason, .noApprovedSubstitute)
    }

    // MARK: - 9. Doppelte Namen ueber Tage/innerhalb eines Tages -> nach Vorkommen verfolgt

    func testDuplicateExerciseNameAcrossDifferentDaysAreReplacedIndependentlyWithDistinctSlots() {
        let day1 = day([spec("Kniebeuge", repsMax: 12)], sequenceIndex: 1)
        let day2 = day([spec("Kniebeuge", repsMax: 15)], sequenceIndex: 2)
        let profile = fullyConfirmedProfile(available: [.dumbbell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([day1, day2], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.count, 2)
        XCTAssertEqual(Set(draft.replacements.map(\.slot.dayIndex)), [0, 1])
        XCTAssertEqual(draft.adaptedDays[0].exercises.first?.repsMax, 12, "Jedes Vorkommen behaelt seine EIGENE Vorschrift")
        XCTAssertEqual(draft.adaptedDays[1].exercises.first?.repsMax, 15)
    }

    func testDuplicateExerciseNameWithinTheSameDayAreReplacedIndependentlyByOccurrenceIndex() {
        let sameDay = day([spec("Kniebeuge", repsMax: 12), spec("Plank"), spec("Kniebeuge", repsMax: 15)])
        let profile = fullyConfirmedProfile(available: [.dumbbell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([sameDay], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.count, 2)
        XCTAssertEqual(Set(draft.replacements.map(\.slot.exerciseIndex)), [0, 2])
    }

    // MARK: - 10. Zwei kollidierende Substitutionen in einem Tag -> Blocker

    func testTwoSubstitutionsCollidingOnTheSameTargetWithinADayProducesValidatorBlocker() {
        // Beide Klimmzug-Varianten mappen auf dasselbe Ziel "Latzug
        // (neutraler Griff)" — im selben Tag erzeugt das einen NEUEN
        // Duplikat-Fall, der vorher nicht bestand.
        let collidingDay = day([spec("Klimmzüge"), spec("Klimmzüge (weit)")])
        let profile = fullyConfirmedProfile(available: [.cableStation: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([collidingDay], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.count, 2, "Beide werden einzeln regelkonform ersetzt")
        XCTAssertFalse(draft.validatorBlockers.isEmpty, "Der Programm-Validator muss die neue Dopplung melden")
        XCTAssertFalse(draft.isFullyResolved, "Ein Validator-Blocker verhindert die Freigabe, unabhaengig vom Equipment-Status")
    }

    // MARK: - 11. Wiederholte Auswertung -> gleiches Ergebnis, keine Regelketten

    func testRepeatedEvaluationProducesIdenticalDraftsAndNeverChainsReplacements() {
        let original = day([spec("Bulgarische Kniebeuge (KH)")])
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2])
        let v = variant([original], against: profile)

        let first = ExerciseSubstitutionEngine.adapt(variant: v, context: hypertrophyContext, profile: profile)
        let second = ExerciseSubstitutionEngine.adapt(variant: v, context: hypertrophyContext, profile: profile)
        XCTAssertEqual(first, second)

        // Den bereits adaptierten Plan ERNEUT durch die Engine schicken darf
        // keine weiteren Ersetzungen mehr finden (keine Kette).
        let readapted = ExerciseSubstitutionEngine.adapt(
            variant: CheckedPlanVariant(profile: nil, days: first.adaptedDays, equipmentStatus: first.finalEquipmentStatus),
            context: hypertrophyContext, profile: profile
        )
        XCTAssertTrue(readapted.replacements.isEmpty, "Ein bereits ersetztes Ergebnis ist entweder erfuellt oder hat keine weitere Regel - nie eine Kette")
    }

    // MARK: - 12. Warmup/Cooldown/Working-Rollen + unberuehrte Vorschriften bleiben erhalten

    func testWarmupRoleExerciseIsNeverSubstitutedEvenWithAMatchingRule() {
        let mixedDay = day([
            spec("Kniebeuge", repsMax: 12, role: .warmup),
            spec("Plank", role: .workingSet)
        ])
        let profile = fullyConfirmedProfile(available: [.dumbbell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([mixedDay], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty)
        XCTAssertEqual(draft.unresolved.first?.reason, .globallyExcluded)
        XCTAssertEqual(draft.adaptedDays.first?.exercises.first, spec("Kniebeuge", repsMax: 12, role: .warmup), "Unberuehrte Vorschrift bleibt exakt gleich")
    }

    func testUntouchedExercisesKeepTheirExactPrescriptionInAdaptedDays() {
        let mixedDay = day([
            spec("Kniebeuge", repsMax: 12),
            spec("Plank", sets: 4, repsMin: 45, repsMax: 60, rest: 45, rir: 1.0)
        ])
        let profile = fullyConfirmedProfile(available: [.dumbbell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([mixedDay], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.adaptedDays.first?.exercises.last, spec("Plank", sets: 4, repsMin: 45, repsMax: 60, rest: 45, rir: 1.0))
    }

    // MARK: - 13. Zeitformat-Tage im MVP abgelehnt, Metadaten erhalten

    func testTimedCircuitDayIsNeverAdaptedAndKeepsAllCircuitMetadata() {
        let circuitDay = day(
            [spec("Kniebeuge", repsMax: 12)],
            timeFormat: .circuit, timeCapMinutes: 20, circuitRounds: 5, circuitRestSeconds: 30, circuitMode: .fixedReps
        )
        let profile = fullyConfirmedProfile(available: [.dumbbell: nil])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([circuitDay], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertTrue(draft.replacements.isEmpty, "Zeitformat-Tage sind im MVP global gesperrt")
        XCTAssertEqual(draft.unresolved.first?.reason, .globallyExcluded)
        let adapted = draft.adaptedDays.first!
        XCTAssertEqual(adapted.timeFormat, .circuit)
        XCTAssertEqual(adapted.timeCapMinutes, 20)
        XCTAssertEqual(adapted.circuitRounds, 5)
        XCTAssertEqual(adapted.circuitRestSeconds, 30)
        XCTAssertEqual(adapted.circuitMode, .fixedReps)
    }

    // MARK: - 14. Quell-Equipment-Profil bleibt durch die Anpassung unveraendert

    func testSourceEquipmentProfileIsNeverMutatedByAdaptation() {
        let original = day([spec("Bulgarische Kniebeuge (KH)")])
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2])
        let profileBefore = profile
        _ = ExerciseSubstitutionEngine.adapt(variant: variant([original], against: profile), context: hypertrophyContext, profile: profile)
        XCTAssertEqual(profile, profileBefore)
    }

    // MARK: - 17. Teil-Entwuerfe bekommen nie das "vollstaendig kompatibel"-Signal

    func testPartialDraftWithOneResolvedAndOneUnresolvedExerciseIsNeverFullyResolved() {
        let mixedDay = day([
            spec("Bulgarische Kniebeuge (KH)"), // wird ersetzt
            spec("Front Squat")                  // keine Regel -> bleibt offen
        ])
        let profile = fullyConfirmedProfile(available: [.dumbbell: 2])
        let draft = ExerciseSubstitutionEngine.adapt(variant: variant([mixedDay], against: profile), context: hypertrophyContext, profile: profile)

        XCTAssertEqual(draft.replacements.count, 1)
        XCTAssertEqual(draft.unresolved.count, 1)
        XCTAssertFalse(draft.isFullyResolved, "Ein teilweise geloester Entwurf gilt niemals als vollstaendig kompatibel")
    }
}
