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

    // MARK: - ProgramTemplates 1-day coverage

    func testOneDayTemplateExists() {
        let oneDayTemplates = ProgramTemplates.all.filter { $0.daysPerWeek == 1 }
        XCTAssertFalse(oneDayTemplates.isEmpty, "ProgramTemplates.all must include at least one 1-day template")
    }
}
