import XCTest
@testable import FitnessAppCore

final class PRDetectorTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)
    private let weekAgo = Date(timeIntervalSinceReferenceDate: -7 * 24 * 3600)

    private func bench(_ weight: Double, _ reps: Int, _ date: Date? = nil) -> LiftAttempt {
        LiftAttempt(exerciseName: "Bankdruecken", weightKg: weight, reps: reps,
                    date: date ?? now)
    }

    private func squat(_ weight: Double, _ reps: Int, _ date: Date? = nil) -> LiftAttempt {
        LiftAttempt(exerciseName: "Kniebeuge", weightKg: weight, reps: reps,
                    date: date ?? now)
    }

    // MARK: Empty / first-session edge cases

    func testEmptySessionProducesNoPRs() {
        let prs = PRDetector.detectPRs(sessionLifts: [], history: [bench(80, 8, weekAgo)])
        XCTAssertTrue(prs.isEmpty)
    }

    func testFirstEverSessionProducesNoPRs() {
        // No history at all → can't beat what doesn't exist
        let prs = PRDetector.detectPRs(sessionLifts: [bench(100, 5)], history: [])
        XCTAssertTrue(prs.isEmpty,
                      "First-ever session should NOT produce PRs (need a baseline to beat)")
    }

    func testNewExerciseInExistingHistoryProducesNoPRs() {
        // History exists but for a DIFFERENT exercise → still no baseline for the new one
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(100, 5)],
            history: [squat(120, 5, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty)
    }

    // MARK: Strict greater-than (no ties)

    func testTiedHeaviestWeightIsNotAPR() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(80, 8)],
            history: [bench(80, 8, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty, "Identical performance is not a PR — strict > only")
    }

    // MARK: Single PR detection

    func testHeaviestWeightPRDetected() {
        // Prev best 80kg×8 (vol=640, 1RM via Epley=80*(1+8/30)=101.33)
        // Now 90kg×3 (vol=270, 1RM=90*(1+3/30)=99.0)
        // → heaviestWeight PR (90 > 80), but NOT 1RM (99 < 101) and NOT bestSet (270 < 640)
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(90, 3)],
            history: [bench(80, 8, weekAgo)]
        )
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs.first?.kind, .heaviestWeight)
        XCTAssertEqual(prs.first?.weightKg, 90)
        XCTAssertEqual(prs.first?.previousValue, 80)
        XCTAssertEqual(prs.first?.newValue, 90)
    }

    func testEstimated1RMPRViaMoreReps() {
        // Prev best 80×3 → 1RM(avg) ≈ ((80*1.1) + (80*36/34))/2 ≈ (88 + 84.7)/2 ≈ 86.35
        // Now 80×6     → 1RM(avg) ≈ ((80*1.2) + (80*36/31))/2 ≈ (96 + 92.9)/2 ≈ 94.45
        // → 1RM PR (94 > 86), bestSet PR (480 > 240), NO heaviest (tied at 80)
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(80, 6)],
            history: [bench(80, 3, weekAgo)]
        )
        let kinds = Set(prs.map(\.kind))
        XCTAssertTrue(kinds.contains(.estimated1RM))
        XCTAssertTrue(kinds.contains(.bestSet))
        XCTAssertFalse(kinds.contains(.heaviestWeight),
                       "Tied weight should NOT trigger heaviest PR")
    }

    // MARK: Multiple sets in same session

    func testMultiplePRSetsInSameSessionEmitOnePRPerKind() {
        // History: 60×8 (vol=480, 1RM≈73)
        // Session: 80×8 then 70×10 then 75×6
        // → only one heaviestWeight PR (80, the best of the three) — not three.
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(80, 8), bench(70, 10), bench(75, 6)],
            history: [bench(60, 8, weekAgo)]
        )
        let heaviestPRs = prs.filter { $0.kind == .heaviestWeight }
        XCTAssertEqual(heaviestPRs.count, 1)
        XCTAssertEqual(heaviestPRs.first?.weightKg, 80,
                       "The BEST attempt in the session should be credited, not the first")
    }

    // MARK: Cardio + time-based filtering

    func testCardioAttemptsAreIgnored() {
        let cardioRun = LiftAttempt(
            exerciseName: "Laufband", weightKg: 0, reps: 30,
            date: now, isCardio: true
        )
        let prs = PRDetector.detectPRs(
            sessionLifts: [cardioRun],
            history: [LiftAttempt(exerciseName: "Laufband", weightKg: 0, reps: 20,
                                  date: weekAgo, isCardio: true)]
        )
        XCTAssertTrue(prs.isEmpty,
                      "Cardio attempts have different PR semantics — filtered out for v1")
    }

    func testTimeBasedAttemptsAreIgnored() {
        let plank = LiftAttempt(
            exerciseName: "Plank", weightKg: 0, reps: 60,
            date: now, isTimeBased: true
        )
        let prs = PRDetector.detectPRs(
            sessionLifts: [plank],
            history: [LiftAttempt(exerciseName: "Plank", weightKg: 0, reps: 30,
                                  date: weekAgo, isTimeBased: true)]
        )
        XCTAssertTrue(prs.isEmpty)
    }

    func testMixedSessionDetectsLiftPRsAndIgnoresCardio() {
        let cardio = LiftAttempt(exerciseName: "Laufband", weightKg: 0, reps: 30,
                                 date: now, isCardio: true)
        let prs = PRDetector.detectPRs(
            sessionLifts: [cardio, bench(85, 5)],
            history: [bench(80, 5, weekAgo)]
        )
        XCTAssertFalse(prs.isEmpty)
        XCTAssertTrue(prs.allSatisfy { $0.exerciseName == "Bankdruecken" })
    }

    // MARK: Multiple exercises

    func testMultipleExercisesEachJudgedSeparately() {
        // Bench gets a PR (90 > 80), Squat doesn't (100 == 100)
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(90, 5), squat(100, 5)],
            history: [bench(80, 5, weekAgo), squat(100, 5, weekAgo)]
        )
        let exercises = Set(prs.map(\.exerciseName))
        XCTAssertTrue(exercises.contains("Bankdruecken"))
        XCTAssertFalse(exercises.contains("Kniebeuge"))
    }

    // MARK: Output ordering

    func testPRsSortedByExerciseThenByKindPriority() {
        // Two exercises, both with multiple kinds of PR.
        // Expected: alphabetical exercise order, then kindOrder (1RM first).
        let prs = PRDetector.detectPRs(
            sessionLifts: [
                bench(90, 8),    // bench: should produce 1RM + heaviest + bestSet PRs
                squat(120, 8)    // squat: same
            ],
            history: [
                bench(60, 8, weekAgo),
                squat(100, 8, weekAgo)
            ]
        )
        // First exercise is "Bankdruecken" (alphabetical), then "Kniebeuge".
        // Within each: estimated1RM kind first.
        XCTAssertEqual(prs.first?.exerciseName, "Bankdruecken")
        XCTAssertEqual(prs.first?.kind, .estimated1RM)
    }

    // MARK: Delta calculations

    func testPRRecordCarriesPositiveDelta() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(100, 5)],
            history: [bench(80, 5, weekAgo)]
        )
        let heaviest = prs.first { $0.kind == .heaviestWeight }
        XCTAssertNotNil(heaviest)
        XCTAssertEqual(heaviest?.delta, 20)
        XCTAssertEqual(heaviest!.deltaPercent, 0.25, accuracy: 1e-9)
    }
}
