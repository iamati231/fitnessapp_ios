import XCTest
@testable import FitnessAppCore

final class PRCelebrationTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)

    private func record(
        _ kind: PersonalRecord.Kind,
        exercise: String = "Bankdruecken",
        weight: Double = 100,
        reps: Int = 5,
        previous: Double = 90,
        new: Double = 100
    ) -> PersonalRecord {
        PersonalRecord(
            kind: kind,
            exerciseName: exercise,
            weightKg: weight,
            reps: reps,
            previousValue: previous,
            newValue: new,
            achievedAt: now
        )
    }

    // MARK: Empty/single-record cases

    func testEmptyArrayReturnsNil() {
        XCTAssertNil(PRCelebration.make(from: []))
    }

    func testSingleRecordHeadlineAndBody() {
        let pr = record(.heaviestWeight, weight: 100, reps: 5, previous: 90, new: 100)
        let cel = PRCelebration.make(from: [pr])
        XCTAssertNotNil(cel)
        XCTAssertEqual(cel?.recordCount, 1)
        XCTAssertTrue(cel!.title.contains("Maximalgewicht"))
        XCTAssertTrue(cel!.body.contains("Bankdruecken"))
        XCTAssertFalse(cel!.body.contains("weitere"),
                       "Solo PR shouldn't tag a 'weitere' suffix")
    }

    // MARK: Headline priority — 1RM beats Heaviest beats BestSet beats reps beats time

    func testEstimated1RMOutranksHeaviestWeight() {
        let oneRM = record(.estimated1RM, exercise: "Kniebeuge", new: 150)
        let heaviest = record(.heaviestWeight, exercise: "Bankdruecken", new: 100)
        let cel = PRCelebration.make(from: [heaviest, oneRM])
        XCTAssertEqual(cel?.recordCount, 2)
        XCTAssertTrue(cel!.title.contains("1RM"),
                      "1RM headline should win even when listed second")
        XCTAssertTrue(cel!.body.contains("Kniebeuge"))
        XCTAssertTrue(cel!.body.contains("+1 weiterer Rekord"),
                      "Trailing +1 weiterer for the second PR")
    }

    func testHeaviestOutranksBestSet() {
        let heaviest = record(.heaviestWeight, new: 105)
        let bestSet = record(.bestSet, new: 800)
        let cel = PRCelebration.make(from: [bestSet, heaviest])
        XCTAssertTrue(cel!.title.contains("Maximalgewicht"))
    }

    func testBestSetOutranksMaxReps() {
        let bestSet = record(.bestSet, new: 800)
        let maxReps = record(.maxReps, exercise: "Liegestuetze",
                              weight: 0, reps: 20, previous: 15, new: 20)
        let cel = PRCelebration.make(from: [maxReps, bestSet])
        XCTAssertTrue(cel!.title.contains("Bestsatz"))
    }

    func testMaxRepsOutranksMaxHoldSeconds() {
        let maxReps = record(.maxReps, exercise: "Liegestuetze",
                              weight: 0, reps: 20, previous: 15, new: 20)
        let plank = record(.maxHoldSeconds, exercise: "Plank",
                           weight: 0, reps: 60, previous: 45, new: 60)
        let cel = PRCelebration.make(from: [plank, maxReps])
        XCTAssertTrue(cel!.title.contains("Reps"))
    }

    // MARK: Plurals + counting

    func testTwoExtraRecordsUsesPluralSuffix() {
        let prs = [
            record(.estimated1RM, exercise: "Kniebeuge", new: 150),
            record(.heaviestWeight, exercise: "Bankdruecken", new: 100),
            record(.bestSet, exercise: "Rudern", new: 600)
        ]
        let cel = PRCelebration.make(from: prs)
        XCTAssertEqual(cel?.recordCount, 3)
        XCTAssertTrue(cel!.body.contains("+2 weitere Rekorde"),
                      "Two extras → 'weitere Rekorde' (plural)")
    }

    func testOneExtraRecordUsesSingularSuffix() {
        let prs = [
            record(.estimated1RM, exercise: "Kniebeuge", new: 150),
            record(.bestSet, exercise: "Rudern", new: 600)
        ]
        let cel = PRCelebration.make(from: prs)
        XCTAssertTrue(cel!.body.contains("+1 weiterer Rekord"))
    }

    // MARK: Activity-line format (Dynamic Island sized)

    func testActivityLineForWeightedKindShowsKg() {
        let pr = record(.heaviestWeight, exercise: "Bankdruecken", new: 100)
        let cel = PRCelebration.make(from: [pr])!
        XCTAssertTrue(cel.activityLine.contains("🏆"))
        XCTAssertTrue(cel.activityLine.contains("100 kg"))
        XCTAssertTrue(cel.activityLine.contains("Bankdruecken"))
    }

    func testActivityLineForBodyweightShowsReps() {
        let pr = record(.maxReps, exercise: "Liegestuetze",
                        weight: 0, reps: 25, previous: 20, new: 25)
        let cel = PRCelebration.make(from: [pr])!
        XCTAssertTrue(cel.activityLine.contains("25 Wdh"))
        XCTAssertFalse(cel.activityLine.contains("kg"))
    }

    func testActivityLineForTimeBasedShowsSeconds() {
        let pr = record(.maxHoldSeconds, exercise: "Plank",
                        weight: 0, reps: 90, previous: 60, new: 90)
        let cel = PRCelebration.make(from: [pr])!
        XCTAssertTrue(cel.activityLine.contains("90s"))
        XCTAssertTrue(cel.activityLine.contains("Plank"))
    }

    func testActivityLineTruncatesLongExerciseNames() {
        // 18-char name should be truncated to 13 + ellipsis (14 total) so the
        // Dynamic-Island compactTrailing region doesn't overflow.
        let pr = record(.heaviestWeight, exercise: "Schulterdrueckenmaschine", new: 60)
        let cel = PRCelebration.make(from: [pr])!
        XCTAssertTrue(cel.activityLine.contains("…"),
                      "Long exercise names should be ellipsised")
        XCTAssertFalse(cel.activityLine.contains("Schulterdrueckenmaschine"),
                       "Full long name shouldn't survive the shortener")
    }

    // MARK: Stable ordering when priorities tie

    func testTiedPriorityIsAlphabeticallyStable() {
        // Two heaviestWeight PRs — headline should be alphabetically first exercise.
        let bench = record(.heaviestWeight, exercise: "Bankdruecken", new: 100)
        let squat = record(.heaviestWeight, exercise: "Kniebeuge", new: 150)
        let cel = PRCelebration.make(from: [squat, bench])
        // Bankdruecken comes alphabetically before Kniebeuge.
        XCTAssertTrue(cel!.body.contains("Bankdruecken"))
    }

    // MARK: README 2.16 (28c) — Emoji sind eine Eigenschaft der Tonlage

    func testDefaultToneKeepsEmoji() {
        let pr = record(.heaviestWeight, new: 100)
        let cel = PRCelebration.make(from: [pr])!
        XCTAssertTrue(cel.title.contains("💪"))
        XCTAssertTrue(cel.activityLine.contains("🏆"))
    }

    func testAnalyticalToneOmitsEmoji() {
        let pr = record(.heaviestWeight, new: 100)
        let cel = PRCelebration.make(from: [pr], tone: .analytical)!
        XCTAssertTrue(cel.title.contains("Maximalgewicht"))
        XCTAssertFalse(cel.title.contains("💪"))
        XCTAssertFalse(cel.activityLine.contains("🏆"))
    }

    func testStrictToneOmitsEmoji() {
        let pr = record(.estimated1RM, new: 150)
        let cel = PRCelebration.make(from: [pr], tone: .strict)!
        XCTAssertFalse(cel.title.contains("🏆"))
        XCTAssertFalse(cel.activityLine.contains("🏆"))
    }
}
