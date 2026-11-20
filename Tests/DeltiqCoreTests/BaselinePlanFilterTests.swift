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

    func testUnknownAlwaysPasses() {
        for required in BaselineBand.allCases {
            XCTAssertTrue(BaselineBand.unknown.meetsMinimum(required),
                          "unknown should pass minimum \(required)")
        }
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

    func testSevenDayTemplateLastDayIsLightCore() {
        guard let template = ProgramTemplates.all.first(where: { $0.daysPerWeek == 7 }) else {
            return XCTFail("No 7-day template found")
        }
        let day7 = template.days.first { $0.sequenceIndex == 7 }
        XCTAssertNotNil(day7, "Day 7 (sequenceIndex 7) must exist")
        // Day 7 must be lighter than a full PPL day: at most 10 sets total
        let totalSets = day7?.exercises.reduce(0) { $0 + $1.sets } ?? 0
        XCTAssertLessThanOrEqual(totalSets, 10,
            "Day 7 must be a light recovery day (≤10 sets), not a full strength session")
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
        XCTAssertNotEqual(result.name, "Liegestütze",
                          "Blocked push-up must be replaced for veryLow push band")
    }

    func testBaselineSubstituteAccessibleExerciseUnchanged() {
        let highBands = BaselineBands(push: .high, legs: .high, pull: .high,
                                      core: .high, cardio: .unknown)
        let spec = ExerciseSpec(name: "Liegestütze", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            spec, bands: highBands, equipmentPool: [.bodyweight])
        XCTAssertEqual(result.name, "Liegestütze",
                       "Exercise accessible for high band must remain unchanged")
    }

    func testBaselineSubstituteUnknownExerciseUnchanged() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .veryLow, pull: .veryLow,
                                        core: .veryLow, cardio: .unknown)
        let spec = ExerciseSpec(name: "Nicht-Existierende-Übung", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 60)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            spec, bands: veryLowPush, equipmentPool: [.bodyweight])
        XCTAssertEqual(result.name, "Nicht-Existierende-Übung",
                       "Exercise not in library must be returned unchanged (no crash)")
    }

    func testBaselineSubstituteAlternativePreservesSetCount() {
        let veryLowPush = BaselineBands(push: .veryLow, legs: .moderate, pull: .moderate,
                                        core: .moderate, cardio: .unknown)
        let blocked = ExerciseSpec(name: "Liegestütze", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 90)
        let result = ExerciseAlternativeFinder.baselineSubstitute(
            blocked, bands: veryLowPush, equipmentPool: [.bodyweight])
        // The alternative must preserve the original set count
        XCTAssertEqual(result.sets, 4, "Substituted exercise must keep the original set count")
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
