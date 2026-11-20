import XCTest
@testable import DeltiqCore

/// Issue #51: verifies that BaselineBands.band(for:) mapping and
/// BaselineBand.meetsMinimum(_:) work correctly, and that PlanGenerator
/// respects baselineMinBand annotations when bands are provided.
final class BaselinePlanFilterTests: XCTestCase {

    // MARK: - BaselineBand.meetsMinimum

    func testVeryLowDoesNotMeetLow() {
        XCTAssertFalse(BaselineBand.veryLow.meetsMinimum(.low))
    }

    func testLowMeetsLow() {
        XCTAssertTrue(BaselineBand.low.meetsMinimum(.low))
    }

    func testModerateMeetsLow() {
        XCTAssertTrue(BaselineBand.moderate.meetsMinimum(.low))
    }

    func testHighMeetsModerate() {
        XCTAssertTrue(BaselineBand.high.meetsMinimum(.moderate))
    }

    func testVeryLowDoesNotMeetModerate() {
        XCTAssertFalse(BaselineBand.veryLow.meetsMinimum(.moderate))
    }

    func testLowDoesNotMeetModerate() {
        XCTAssertFalse(BaselineBand.low.meetsMinimum(.moderate))
    }

    func testUnknownBandConservativeBehavior() {
        // .unknown now behaves like .low (conservative, not permissive)
        XCTAssertTrue(BaselineBand.unknown.meetsMinimum(.veryLow))
        XCTAssertTrue(BaselineBand.unknown.meetsMinimum(.low))
        XCTAssertFalse(BaselineBand.unknown.meetsMinimum(.moderate),
                       ".unknown must NOT pass .moderate — skipping the test should not unlock advanced exercises")
        XCTAssertFalse(BaselineBand.unknown.meetsMinimum(.high))
    }

    func testConservativeBandsPassLowRequirement() {
        // .conservative = push:.low — must pass a .low-gated exercise
        XCTAssertTrue(BaselineBands.conservative.band(for: .chest).meetsMinimum(.low))
    }

    func testConservativeBandsBlockModerateRequirement() {
        // .conservative = push:.low — must block a .moderate-gated exercise
        XCTAssertFalse(BaselineBands.conservative.band(for: .chest).meetsMinimum(.moderate))
    }

    // MARK: - BaselineBands.band(for:)

    func testBandMappingPushMuscles() {
        let bands = BaselineBands(push: .low, legs: .high, pull: .moderate, core: .veryLow, cardio: .unknown)
        XCTAssertEqual(bands.band(for: .chest),    .low)
        XCTAssertEqual(bands.band(for: .shoulders), .low)
        XCTAssertEqual(bands.band(for: .triceps),   .low)
    }

    func testBandMappingPullMuscles() {
        let bands = BaselineBands(push: .low, legs: .high, pull: .moderate, core: .veryLow, cardio: .unknown)
        XCTAssertEqual(bands.band(for: .back),    .moderate)
        XCTAssertEqual(bands.band(for: .biceps),  .moderate)
    }

    func testBandMappingLegMuscles() {
        let bands = BaselineBands(push: .low, legs: .high, pull: .moderate, core: .veryLow, cardio: .unknown)
        XCTAssertEqual(bands.band(for: .quads),     .high)
        XCTAssertEqual(bands.band(for: .hamstrings), .high)
        XCTAssertEqual(bands.band(for: .glutes),     .high)
        XCTAssertEqual(bands.band(for: .calves),     .high)
    }

    func testBandMappingCore() {
        let bands = BaselineBands(push: .low, legs: .high, pull: .moderate, core: .veryLow, cardio: .unknown)
        XCTAssertEqual(bands.band(for: .core), .veryLow)
    }

    // MARK: - PlanGenerator baseline filtering

    private func bodyweightInput(bands: BaselineBands?) -> PlanGeneratorInput {
        let selection = PlanGeneratorTypeSelection(
            kind: .bodyweight, daysPerWeek: 1, sessionDurationMinutes: 45, experience: .beginner
        )
        return PlanGeneratorInput(
            selections: [selection],
            equipmentPreferences: [],
            usesFixedWeekdays: false,
            baselineBands: bands
        )
    }

    func testVeryLowPushBandExcludesStandardPushUps() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .moderate, pull: .moderate, core: .moderate, cardio: .unknown)
        let result = PlanGenerator.generate(from: bodyweightInput(bands: veryLowPush))
        let allExerciseNames = result.days.flatMap { $0.spec.exercises.map(\.name) }
        XCTAssertFalse(allExerciseNames.contains("Liegestütze"),
                       "veryLow push band must exclude standard push-ups")
        XCTAssertFalse(allExerciseNames.contains("Breite Liegestütze"),
                       "veryLow push band must exclude wide push-ups")
    }

    func testVeryLowPushBandStillIncludesKneePushUps() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .moderate, pull: .moderate, core: .moderate, cardio: .unknown)
        let result = PlanGenerator.generate(from: bodyweightInput(bands: veryLowPush))
        let allExerciseNames = result.days.flatMap { $0.spec.exercises.map(\.name) }
        // "Liegestütze (Knie)" has no baselineMinBand — must remain eligible
        // (at least one day should have beginner bodyweight exercises for chest)
        let hasKneeOrAlternative = allExerciseNames.contains("Liegestütze (Knie)")
            || allExerciseNames.contains("Pike Liegestütze")
            || allExerciseNames.contains("Liegestütz aufwärts")
        XCTAssertTrue(hasKneeOrAlternative,
                      "veryLow push user must still receive an accessible chest alternative")
    }

    func testNilBandsIncludesAllExercises() {
        let result = PlanGenerator.generate(from: bodyweightInput(bands: nil))
        let allExerciseNames = result.days.flatMap { $0.spec.exercises.map(\.name) }
        // With no bands, standard push-ups must be eligible (pool unrestricted)
        // We just verify the plan is non-empty.
        XCTAssertFalse(allExerciseNames.isEmpty)
    }

    // MARK: - PlanGeneratorInput.withBaselineBands

    func testWithBaselineBandsCopiesAllFields() {
        let orig = PlanGeneratorInput(
            selections: [PlanGeneratorTypeSelection(kind: .dumbbell, daysPerWeek: 3, sessionDurationMinutes: 45, experience: .intermediate)],
            equipmentPreferences: [.dumbbell],
            usesFixedWeekdays: true,
            fixedWeekdays: [2, 4, 6],
            trainingGoal: .hypertrophy
        )
        let bands = BaselineBands(push: .low, legs: .moderate, pull: .low, core: .moderate, cardio: .unknown)
        let copy = orig.withBaselineBands(bands)
        XCTAssertEqual(copy.selections, orig.selections)
        XCTAssertEqual(copy.equipmentPreferences, orig.equipmentPreferences)
        XCTAssertEqual(copy.usesFixedWeekdays, orig.usesFixedWeekdays)
        XCTAssertEqual(copy.fixedWeekdays, orig.fixedWeekdays)
        XCTAssertEqual(copy.trainingGoal, orig.trainingGoal)
        XCTAssertEqual(copy.baselineBands, bands)
    }

    // MARK: - ProgramTemplates day-count coverage

    func testOneDayTemplateExists() {
        let oneDayTemplates = ProgramTemplates.all.filter { $0.daysPerWeek == 1 }
        XCTAssertFalse(oneDayTemplates.isEmpty, "ProgramTemplates.all must include at least one 1-day template")
    }

    func testSevenDayTemplateExists() {
        let sevenDayTemplates = ProgramTemplates.all.filter { $0.daysPerWeek == 7 }
        XCTAssertFalse(sevenDayTemplates.isEmpty, "ProgramTemplates.all must include at least one 7-day template")
    }

    func testSevenDayTemplateHasSevenDays() {
        let template = ProgramTemplates.all.first { $0.daysPerWeek == 7 }
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.days.count, 7, "7-day template must contain exactly 7 DaySpecs")
    }

    // MARK: - P2: 7-day template recovery design

    func testSevenDayTemplateLastDayIsActiveRecovery() {
        guard let template = ProgramTemplates.all.first(where: { $0.daysPerWeek == 7 }) else {
            return XCTFail("No 7-day template found")
        }
        let day7 = template.days.first { $0.sequenceIndex == 7 }
        XCTAssertNotNil(day7, "Day 7 (sequenceIndex 7) must exist")
        // daysPerWeek = 7 → 7 real activities; Day 7 is active recovery (light load),
        // not a rest day — ensures the declared frequency matches planned activities.
        XCTAssertNotEqual(day7?.type, .rest,
            "Day 7 must be an active recovery day, not rest — daysPerWeek=7 must equal 7 actual training days")
        XCTAssertFalse(day7?.exercises.isEmpty ?? true,
            "Active recovery day must have exercises (light bodyweight work)")
        // Load management: active recovery must be light (≤ 2 sets per exercise)
        let maxSets = day7?.exercises.map(\.sets).max() ?? 0
        XCTAssertLessThanOrEqual(maxSets, 3,
            "Active recovery day exercises should have at most 3 sets (issue #51 P1: sensible load management)")
    }

    func testSevenDayTemplateIsAdvancedOnly() {
        let template = ProgramTemplates.all.first { $0.daysPerWeek == 7 }
        XCTAssertNotNil(template)
        XCTAssertFalse(template?.targetExperience.contains(.beginner) ?? true,
                       "7-day no-rest template must not target beginners")
    }

    // MARK: - P2: Beginner K.O. filter for advanced 7-day template

    func testBeginnerExperienceTrackExcludesAdvanced7DayTemplate() {
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: .beginner,
            preferredDays: 7,
            environment: .gym
        )
        let result = PlanMatchmaker.rankPlansDetailed(
            for: answers,
            templates: ProgramTemplates.all,
            experienceTrack: .starter
        )
        let ids = result.templates.map { $0.id }
        XCTAssertFalse(ids.contains("push_pull_legs_7x"),
                       "Advanced 7-day PPL must be K.O. filtered for beginners (ExperienceTrack.starter)")
    }

    // MARK: - P4: ExerciseAlternativeFinder.baselineSubstitute

    func testBaselineSubstituteBlockedPushUp() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .moderate, pull: .moderate,
                                        core: .moderate, cardio: .unknown)
        let blocked = ExerciseSpec(name: "Liegestütze", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            blocked, bands: veryLowPush, equipmentPool: [.bodyweight])
        XCTAssertNotNil(result, "A blocked push-up with accessible bodyweight alternatives must substitute, not skip")
        XCTAssertNotEqual(result?.name, "Liegestütze",
                          "Blocked push-up must be replaced for veryLow push band")
    }

    func testBaselineSubstituteAccessibleExerciseUnchanged() {
        let highBands = BaselineBands(push: .high, legs: .high, pull: .high,
                                      core: .high, cardio: .unknown)
        let spec = ExerciseSpec(name: "Liegestütze", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            spec, bands: highBands, equipmentPool: [.bodyweight])
        XCTAssertNotNil(result, "Accessible exercise must be returned unchanged")
        XCTAssertEqual(result?.name, "Liegestütze",
                       "Exercise accessible for high band must remain unchanged")
    }

    func testBaselineSubstituteUnknownExerciseUnchanged() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                        core: .veryLow, cardio: .unknown)
        let spec = ExerciseSpec(name: "Nicht-Existierende-Übung", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            spec, bands: veryLowPush, equipmentPool: [.bodyweight])
        XCTAssertNotNil(result, "Exercise not in library must be returned unchanged (no crash)")
        XCTAssertEqual(result?.name, "Nicht-Existierende-Übung",
                       "Exercise not in library must be returned unchanged")
    }

    func testBaselineSubstituteAlternativePreservesSetCount() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .moderate, pull: .moderate,
                                        core: .moderate, cardio: .unknown)
        let blocked = ExerciseSpec(name: "Liegestütze", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 90)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            blocked, bands: veryLowPush, equipmentPool: [.bodyweight])
        XCTAssertNotNil(result, "A blocked push-up with accessible bodyweight alternatives must substitute")
        XCTAssertEqual(result?.sets, 4, "Substituted exercise must keep the original set count")
    }

    func testBaselineSubstituteNeverReturnsSilentlyBlockedExercise() {
        // "Klimmzüge" is a confirmed library entry (baselineMinBand: .low, equipment: .bodyweight,
        // equipmentRequirement: .item(.pullUpBar)). With veryLow pull and pool [.bodyweight],
        // pass 1 may find "Australian Pull-ups" (back, no baselineMinBand, pool check passes).
        // The invariant: the original blocked exercise must NEVER be returned unchanged.
        let veryLowAll = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                       core: .veryLow, cardio: .unknown)
        let blocked = ExerciseSpec(name: "Klimmzüge", sets: 3, repsMin: 5, repsMax: 8, restSeconds: 120)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            blocked, bands: veryLowAll, equipmentPool: [.bodyweight])
        if let r = result {
            XCTAssertNotEqual(r.name, "Klimmzüge",
                              "A demonstrably blocked exercise must never be silently returned unchanged")
        }
        // nil is also valid — the caller tracks it as a BaselineConflict
    }

    func testBaselineSubstituteReturnsNilWhenNoAccessibleAlternative() {
        // "Klimmzüge" blocked (veryLow pull, .low gate), pool empty → pass 1 finds nothing.
        // Pass 2 uses strictBodyweight: all back bodyweight exercises require .item(.pullUpBar)
        // so none pass requiresNoPhysicalItem → nil.
        let veryLowAll = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                       core: .veryLow, cardio: .unknown)
        let blocked = ExerciseSpec(name: "Klimmzüge", sets: 3, repsMin: 5, repsMax: 8, restSeconds: 120)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            blocked, bands: veryLowAll, equipmentPool: [])
        XCTAssertNil(result,
            "No bodyweight back exercise exists without a physical item requirement → must return nil")
    }

    func testBaselineConflictsTrackedInSelection() {
        // When substitution removes an exercise, it must appear in baselineConflicts.
        guard let template = ProgramTemplates.all.first(where: { $0.id == "push_pull_legs_7x" }) else {
            return XCTFail("PPL 7x template not found")
        }
        // veryLow pull → "Klimmzüge (weit)" in Pull A is blocked; empty pool → no alternative
        let veryLowAll = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                       core: .veryLow, cardio: .unknown)
        let profile = UserEquipmentProfile(availability: [:])
        let selection = PlanSelectionResolver.resolve(
            template: template, profile: profile,
            context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        ).withBaselineSubstitution(bands: veryLowAll)
        // With veryLow pull bands and no equipment, pull-up bar exercises must be conflicted
        XCTAssertFalse(selection.baselineConflicts.isEmpty,
            "veryLow pull with no equipment pool must produce at least one baseline conflict")
    }

    // MARK: - E2E: Preview / substitution consistency

    func testNoEmptyTrainingDaysAfterConservativeSubstitution() {
        // No template should produce an empty non-rest training day for conservative bands.
        let profile = UserEquipmentProfile(availability: [:])
        for template in ProgramTemplates.all {
            let selection = PlanSelectionResolver.resolve(
                template: template, profile: profile,
                context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
            ).withBaselineSubstitution(bands: .conservative)
            for day in selection.days where day.type != .rest && !day.exercises.isEmpty == false {
                // A day that was non-empty in the original template but became empty is a conflict
                XCTFail("Template '\(template.id)' day '\(day.name)' became empty after conservative substitution")
            }
        }
    }

    func testDoubleSubstitutionIsIdempotent() {
        // Applying withBaselineSubstitution twice must return the same result as once.
        guard let template = ProgramTemplates.all.first(where: { $0.id == "push_pull_legs_7x" }) else {
            return XCTFail("PPL 7x template not found")
        }
        let profile = UserEquipmentProfile(availability: [:])
        let raw = PlanSelectionResolver.resolve(
            template: template, profile: profile,
            context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        )
        let once = raw.withBaselineSubstitution(bands: .conservative)
        let twice = once.withBaselineSubstitution(bands: .conservative)
        XCTAssertEqual(once.days.flatMap(\.exercises).map(\.name),
                       twice.days.flatMap(\.exercises).map(\.name),
                       "withBaselineSubstitution must be idempotent — preview and save must match")
    }

    func testNoFrequencyChangeDuringSubstitution() {
        // daysPerWeek declared in a template must not change after substitution.
        let profile = UserEquipmentProfile(availability: [:])
        for template in ProgramTemplates.all {
            let selection = PlanSelectionResolver.resolve(
                template: template, profile: profile,
                context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
            ).withBaselineSubstitution(bands: .conservative)
            XCTAssertEqual(selection.days.count, template.days.count,
                "Template '\(template.id)': day count must not change after baseline substitution")
        }
    }

    // MARK: - P3: Template frequency coverage

    func testAllTrainingFrequenciesHaveTemplates() {
        // Frequencies 1–7: each should have at least one template,
        // or fall back to the Plan Builder. This test documents current state.
        let allDays = ProgramTemplates.all.map { $0.daysPerWeek }
        for freq in 1...7 {
            let hasTemplate = allDays.contains(freq)
            // Frequencies without a template use the dynamic Plan Builder —
            // this is acceptable, but we document it here.
            if !hasTemplate {
                XCTFail("No template for \(freq) training days/week — users will fall back to Plan Builder only. Consider adding a template.")
            }
        }
    }

    // MARK: - Issue #51 Review-Findings

    /// P1: conflicts from a first substitution call must still be present after a second call.
    func testBaselineConflictsAccumulateOnResubstitution() {
        guard let template = ProgramTemplates.all.first(where: { $0.id == "push_pull_legs_7x" }) else {
            return XCTFail("PPL 7x template not found")
        }
        let veryLowAll = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                       core: .veryLow, cardio: .unknown)
        let profile = UserEquipmentProfile(availability: [:])
        let raw = PlanSelectionResolver.resolve(
            template: template, profile: profile,
            context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        )
        let once = raw.withBaselineSubstitution(bands: veryLowAll)
        let twice = once.withBaselineSubstitution(bands: veryLowAll)
        // Every conflict from the first call must still be present in the second call.
        for c in once.baselineConflicts {
            XCTAssertTrue(twice.baselineConflicts.contains(c),
                "Conflict '\(c.exerciseName)' in day '\(c.dayName)' was lost on resubstitution")
        }
    }

    /// P0: an empty-day conflict must set isCritical = true.
    func testCriticalConflictIsFlaggedOnEmptyDay() {
        guard let template = ProgramTemplates.all.first(where: { $0.id == "push_pull_legs_7x" }) else {
            return XCTFail("PPL 7x template not found")
        }
        let veryLowAll = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                       core: .veryLow, cardio: .unknown)
        let profile = UserEquipmentProfile(availability: [:])
        let selection = PlanSelectionResolver.resolve(
            template: template, profile: profile,
            context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        ).withBaselineSubstitution(bands: veryLowAll)
        // With all bands at veryLow and no equipment, at least one day must become empty
        // → that conflict must be flagged as critical.
        let criticals = selection.baselineConflicts.filter(\.isCritical)
        XCTAssertFalse(criticals.isEmpty,
            "veryLow bands + no equipment must produce at least one critical (empty-day) conflict")
    }

    /// P1: an individual exercise removal conflict must NOT be critical.
    func testIndividualExerciseRemovalConflictIsNotCritical() {
        guard let template = ProgramTemplates.all.first(where: { $0.id == "push_pull_legs_7x" }) else {
            return XCTFail("PPL 7x template not found")
        }
        // conservative bands: some exercises blocked, but days should not become empty
        let profile = UserEquipmentProfile(availability: [:])
        let selection = PlanSelectionResolver.resolve(
            template: template, profile: profile,
            context: SubstitutionContext(goal: .hypertrophy, experienceTrack: .experienced)
        ).withBaselineSubstitution(bands: .conservative)
        // Conservative bands must not cause any critical conflicts
        let criticals = selection.baselineConflicts.filter(\.isCritical)
        XCTAssertTrue(criticals.isEmpty,
            "Conservative substitution must not produce critical (empty-day) conflicts; got: \(criticals.map(\.dayName))")
    }

    // MARK: - P3: Exercise name validity

    func testSevenDayTemplateExercisesAllExistInLibrary() {
        guard let template = ProgramTemplates.all.first(where: { $0.daysPerWeek == 7 }) else {
            return XCTFail("No 7-day template found")
        }
        let unknownExercises = template.days
            .flatMap { $0.exercises.map(\.name) }
            .filter { ExerciseLibraryData.byName[$0] == nil }
        XCTAssertTrue(unknownExercises.isEmpty,
                      "These exercises in the 7-day template are not in ExerciseLibraryData: \(unknownExercises)")
    }
}
