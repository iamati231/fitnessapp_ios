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

    // (Time-based exercises now produce maxHoldSeconds PRs — see the dedicated
    // section below. The old "ignored" behavior was lifted in the categorization
    // refactor.)

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

    // MARK: Bodyweight — maxReps

    private func pushup(_ reps: Int, _ date: Date? = nil) -> LiftAttempt {
        LiftAttempt(exerciseName: "Liegestuetze", weightKg: 0, reps: reps,
                    date: date ?? now)
    }

    func testPushupMaxRepsPR_detectsNewMax() {
        // Best so far: 12 reps. Session: 15 reps → maxReps PR.
        let prs = PRDetector.detectPRs(
            sessionLifts: [pushup(15)],
            history: [pushup(10, weekAgo), pushup(12, weekAgo)]
        )
        XCTAssertEqual(prs.count, 1)
        let pr = prs.first
        XCTAssertEqual(pr?.kind, .maxReps)
        XCTAssertEqual(pr?.exerciseName, "Liegestuetze")
        XCTAssertEqual(pr?.reps, 15)
        XCTAssertEqual(pr?.weightKg, 0)
        XCTAssertEqual(pr?.previousValue, 12)
        XCTAssertEqual(pr?.newValue, 15)
    }

    func testPushupMaxRepsTied_isNotAPR() {
        // 12 reps history vs 12 reps session → strict > only, no PR.
        let prs = PRDetector.detectPRs(
            sessionLifts: [pushup(12)],
            history: [pushup(12, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty, "Tied bodyweight reps must not produce a PR")
    }

    func testPushupNoHistory_noMaxRepsPR() {
        // First session, no history → no baseline, no PR.
        let prs = PRDetector.detectPRs(
            sessionLifts: [pushup(20)],
            history: []
        )
        XCTAssertTrue(prs.isEmpty)
    }

    func testPushupMultipleSetsCreditsBestSet() {
        // Three sets, BEST attempt should be credited even when the user did them
        // in non-monotonic order.
        let prs = PRDetector.detectPRs(
            sessionLifts: [pushup(13), pushup(18), pushup(15)],
            history: [pushup(12, weekAgo)]
        )
        let maxReps = prs.filter { $0.kind == .maxReps }
        XCTAssertEqual(maxReps.count, 1, "At most one maxReps PR per (exercise, kind)")
        XCTAssertEqual(maxReps.first?.reps, 18)
    }

    // MARK: Time-based — maxHoldSeconds

    private func plank(_ seconds: Int, _ weight: Double = 0, _ date: Date? = nil) -> LiftAttempt {
        LiftAttempt(exerciseName: "Plank", weightKg: weight, reps: seconds,
                    date: date ?? now, isTimeBased: true)
    }

    func testPlankMaxHoldSecondsPR_detectsNewTime() {
        // 30s history → 60s session = new max-hold PR.
        let prs = PRDetector.detectPRs(
            sessionLifts: [plank(60)],
            history: [plank(30, 0, weekAgo)]
        )
        XCTAssertEqual(prs.count, 1)
        let pr = prs.first
        XCTAssertEqual(pr?.kind, .maxHoldSeconds)
        XCTAssertEqual(pr?.exerciseName, "Plank")
        XCTAssertEqual(pr?.reps, 60)
        XCTAssertEqual(pr?.previousValue, 30)
        XCTAssertEqual(pr?.newValue, 60)
    }

    func testPlankShorterTime_isNotAPR() {
        // 60s history vs 45s session → no PR (didn't beat best).
        let prs = PRDetector.detectPRs(
            sessionLifts: [plank(45)],
            history: [plank(60, 0, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty)
    }

    func testPlankTiedTime_isNotAPR() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [plank(60)],
            history: [plank(60, 0, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty, "Tied hold-time must not produce a PR")
    }

    func testWeightedPlank_stillUsesMaxHoldSeconds() {
        // A weighted plank (10 kg belt, 50s) — weight is irrelevant for time-based.
        // Category is timeBased because at least one attempt has isTimeBased==true,
        // so we expect a maxHoldSeconds PR (50s > 40s) and NO weighted PRs.
        let prs = PRDetector.detectPRs(
            sessionLifts: [plank(50, 10)],
            history: [plank(40, 0, weekAgo)]
        )
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs.first?.kind, .maxHoldSeconds)
        XCTAssertEqual(prs.first?.reps, 50)
    }

    // MARK: Weighted-pullup fallback (the critical edge case)

    private func pullup(_ weight: Double, _ reps: Int, _ date: Date? = nil) -> LiftAttempt {
        LiftAttempt(exerciseName: "Klimmzuege", weightKg: weight, reps: reps,
                    date: date ?? now)
    }

    func testWeightedPullup_fallsBackToWeightedLogic() {
        // History: pure bodyweight pullups (12 reps).
        // Session: user adds a 10kg belt for 8 reps — weighted attempt → category
        // flips to .weighted for the WHOLE exercise, so we get a heaviestWeight PR
        // (10 > 0), NOT a maxReps PR (since session reps 8 < history 12 anyway).
        let prs = PRDetector.detectPRs(
            sessionLifts: [pullup(10, 8)],
            history: [pullup(0, 10, weekAgo), pullup(0, 12, weekAgo)]
        )
        // Expect weighted PRs (heaviestWeight + bestSet + estimated1RM possible),
        // but NEVER a maxReps PR for this exercise.
        let kinds = Set(prs.map(\.kind))
        XCTAssertFalse(kinds.contains(.maxReps),
                       "A weighted attempt must shift the category — no maxReps PR allowed")
        XCTAssertTrue(kinds.contains(.heaviestWeight),
                      "10kg over a 0kg history is a clear heaviestWeight PR")
        let heaviest = prs.first { $0.kind == .heaviestWeight }
        XCTAssertEqual(heaviest?.weightKg, 10)
        XCTAssertEqual(heaviest?.previousValue, 0)
        XCTAssertEqual(heaviest?.newValue, 10)
    }

    func testMixedSession_anyWeightedAttemptTriggersWeightedLogic() {
        // Same exercise, mixed session: one bodyweight set + one weighted set.
        // The single weighted attempt anywhere flips the category to .weighted.
        // History only has bodyweight, so weighted PRs are easy wins.
        let prs = PRDetector.detectPRs(
            sessionLifts: [pullup(0, 14), pullup(5, 6)],
            history: [pullup(0, 10, weekAgo)]
        )
        let kinds = Set(prs.map(\.kind))
        XCTAssertFalse(kinds.contains(.maxReps),
                       "Mixed bodyweight + weighted = weighted branch only")
        XCTAssertTrue(kinds.contains(.heaviestWeight),
                      "5kg over a 0kg history is a heaviestWeight PR")
    }

    func testHistoryWeightedSessionBodyweight_stillWeightedBranch() {
        // Inverse direction: history has weighted attempts, session is pure bodyweight.
        // Category still resolves to .weighted (history attempts contribute), so the
        // bodyweight session attempts get filtered out of weighted-detection (weight==0)
        // and produce no PRs — and crucially NO maxReps PR either.
        let prs = PRDetector.detectPRs(
            sessionLifts: [pullup(0, 15)],
            history: [pullup(10, 5, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty,
                      "Weighted history + bodyweight session = no PR (weighted branch, no weighted attempt this session)")
    }

    // MARK: - DEL-064 Cardio PRs

    /// Helper fuer Cardio-Test-LiftAttempts.
    private func run(_ km: Double, _ seconds: Int, _ date: Date? = nil) -> LiftAttempt {
        LiftAttempt(
            exerciseName: "Easy Run",
            weightKg: 0,
            reps: 0,
            date: date ?? now,
            isCardio: true,
            distanceKm: km,
            durationSeconds: seconds
        )
    }

    /// Lauf mit neuer Maximaldistanz → `.longestDistance`-PR.
    func testCardioLongestDistance_detectsNewBest() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(8.0, 50 * 60)],
            history: [run(5.0, 30 * 60, weekAgo)]
        )
        let pr = prs.first { $0.kind == .longestDistance }
        XCTAssertNotNil(pr)
        XCTAssertEqual(pr?.exerciseName, "Easy Run")
        XCTAssertEqual(pr?.previousValue, 5.0)
        XCTAssertEqual(pr?.newValue, 8.0)
    }

    /// Lauf mit besserer Pace → `.fastestPace`-PR. 5 km in 25 Min (5:00 /km)
    /// schlaegt history 5 km in 30 Min (6:00 /km).
    func testCardioFastestPace_detectsNewBest() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(5.0, 25 * 60)],
            history: [run(5.0, 30 * 60, weekAgo)]
        )
        let pr = prs.first { $0.kind == .fastestPace }
        XCTAssertNotNil(pr)
        // Pace: 5:00 vs 6:00 — lower is better.
        XCTAssertEqual(pr?.newValue ?? 99, 5.0, accuracy: 0.001)
        XCTAssertEqual(pr?.previousValue ?? 99, 6.0, accuracy: 0.001)
    }

    /// Sprint-Guard: Lauf unter 1 km darf KEINEN Pace-PR liefern (sonst
    /// kann ein 100m-Sprint mit 3:00/km die 5K-Pace ueberlagern).
    func testCardioFastestPace_respectsMinDistanceGuard() {
        // 0,5 km in 1 Min = 2:00 /km (absurd-schnell)
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(0.5, 60)],
            history: [run(5.0, 30 * 60, weekAgo)]
        )
        XCTAssertFalse(prs.contains { $0.kind == .fastestPace },
                       "Sprint unter 1 km darf keinen Pace-PR triggern")
    }

    /// Distance-PR triggert auch unterhalb der Pace-Mindest-Distanz — bei
    /// einem persoenlichen Maximum-Lauf ist die km-Zahl immer relevant.
    func testCardioLongestDistance_worksEvenForShortRuns() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(0.7, 5 * 60)],
            history: [run(0.5, 4 * 60, weekAgo)]
        )
        XCTAssertTrue(prs.contains { $0.kind == .longestDistance })
    }

    /// Erste Cardio-Session ohne History → keine PRs (Baseline-Regel).
    func testCardioFirstSessionProducesNoPRs() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(5.0, 25 * 60)],
            history: []
        )
        XCTAssertTrue(prs.isEmpty)
    }

    /// Gleiche Pace + gleiche Distanz → kein PR (strict-greater-than).
    func testCardioTieIsNotAPR() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(5.0, 25 * 60)],
            history: [run(5.0, 25 * 60, weekAgo)]
        )
        XCTAssertTrue(prs.isEmpty)
    }

    /// Mixed-Session: 1 Bench-PR + 1 Cardio-Distance-PR → beide werden
    /// detektiert, in Kategorie-getrennten Branches.
    func testMixedStrengthAndCardioBothProduceTheirOwnPRs() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [run(8.0, 45 * 60), bench(90, 5)],
            history: [run(5.0, 30 * 60, weekAgo), bench(80, 5, weekAgo)]
        )
        XCTAssertTrue(prs.contains { $0.kind == .longestDistance })
        XCTAssertTrue(prs.contains { $0.kind == .heaviestWeight })
    }

    // MARK: - Zeitformate (README 2.9): detectTimedFormatPR

    private func amrapAttempt(rounds: Int, partial: Int = 0, wod: String = "Cindy", date: Date? = nil) -> TimedWorkoutAttempt {
        TimedWorkoutAttempt(wodName: wod, format: .amrap, date: date ?? now, roundsCompleted: rounds, partialReps: partial)
    }

    private func forTimeAttempt(seconds: Int, wod: String = "Fran", date: Date? = nil, completedTarget: Bool = true) -> TimedWorkoutAttempt {
        TimedWorkoutAttempt(wodName: wod, format: .forTime, date: date ?? now, finishTimeSeconds: seconds, completedTarget: completedTarget)
    }

    func testAmrapFirstAttemptProducesNoPR() {
        let pr = PRDetector.detectTimedFormatPR(session: amrapAttempt(rounds: 10), history: [])
        XCTAssertNil(pr, "Erste Session an diesem WOD hat keine Baseline zum Schlagen")
    }

    func testAmrapDifferentWodNameIsNotABaseline() {
        let pr = PRDetector.detectTimedFormatPR(
            session: amrapAttempt(rounds: 10, wod: "Cindy"),
            history: [amrapAttempt(rounds: 5, wod: "Annie", date: weekAgo)]
        )
        XCTAssertNil(pr, "Historie eines ANDEREN WODs darf keine Baseline liefern")
    }

    func testAmrapMoreRoundsIsAPR() {
        let pr = PRDetector.detectTimedFormatPR(
            session: amrapAttempt(rounds: 13, partial: 4),
            history: [amrapAttempt(rounds: 12, partial: 8, date: weekAgo)]
        )
        XCTAssertEqual(pr?.kind, .mostRounds)
        XCTAssertEqual(pr?.newValue, 13)
        XCTAssertEqual(pr?.previousValue, 12)
        XCTAssertEqual(pr?.reps, 4, "reps traegt die aktuellen partialReps fuer die Anzeige")
    }

    func testAmrapFewerOrEqualRoundsIsNotAPR() {
        let sameRounds = PRDetector.detectTimedFormatPR(
            session: amrapAttempt(rounds: 12, partial: 8),
            history: [amrapAttempt(rounds: 12, partial: 2, date: weekAgo)]
        )
        XCTAssertNil(sameRounds, "Gleiche Rundenzahl ist kein PR, auch mit mehr Restwiederholungen (v1-Vereinfachung)")

        let fewerRounds = PRDetector.detectTimedFormatPR(
            session: amrapAttempt(rounds: 11),
            history: [amrapAttempt(rounds: 12, date: weekAgo)]
        )
        XCTAssertNil(fewerRounds)
    }

    func testForTimeFasterIsAPR() {
        let pr = PRDetector.detectTimedFormatPR(
            session: forTimeAttempt(seconds: 300),
            history: [forTimeAttempt(seconds: 330, date: weekAgo)]
        )
        XCTAssertEqual(pr?.kind, .fastestTime)
        XCTAssertEqual(pr?.newValue, 300)
        XCTAssertEqual(pr?.previousValue, 330)
    }

    func testForTimeSlowerOrEqualIsNotAPR() {
        let slower = PRDetector.detectTimedFormatPR(
            session: forTimeAttempt(seconds: 340),
            history: [forTimeAttempt(seconds: 330, date: weekAgo)]
        )
        XCTAssertNil(slower)

        let tied = PRDetector.detectTimedFormatPR(
            session: forTimeAttempt(seconds: 330),
            history: [forTimeAttempt(seconds: 330, date: weekAgo)]
        )
        XCTAssertNil(tied, "Identische Zeit ist kein PR — strict > only, analog zu Kraft-PRs")
    }

    /// README 2.10/19e-Vorbedingung: ein frueh gespeicherter (kuerzerer) Lauf
    /// darf nicht als Bestzeit durchgehen, egal wie schnell seine Zeit
    /// gegenueber einem echten, vollstaendigen Lauf wirkt.
    func testForTimeAbandonedRunNeverProducesAPR() {
        let pr = PRDetector.detectTimedFormatPR(
            session: forTimeAttempt(seconds: 192, completedTarget: false),
            history: [forTimeAttempt(seconds: 580, date: weekAgo)]
        )
        XCTAssertNil(pr, "4 von 9 Runden in 3:12 darf 9 von 9 in 9:40 nicht schlagen")
    }

    /// Gegenstueck: eine abgebrochene HISTORISCHE Session darf nicht als
    /// schlagbare Baseline zaehlen — sonst wuerde ein spaeterer, ebenfalls
    /// abgebrochener Lauf sie faelschlich als PR ausweisen.
    func testForTimeAbandonedHistoryIsNotABaseline() {
        let pr = PRDetector.detectTimedFormatPR(
            session: forTimeAttempt(seconds: 400),
            history: [forTimeAttempt(seconds: 192, date: weekAgo, completedTarget: false)]
        )
        XCTAssertNil(pr, "Eine abgebrochene Historie darf keine Baseline liefern, egal wie kurz")
    }

    func testEmomNeverProducesAPR() {
        let attempt = TimedWorkoutAttempt(
            wodName: "EMOM 12", format: .emom, date: now, roundsCompleted: 12
        )
        let history = TimedWorkoutAttempt(
            wodName: "EMOM 12", format: .emom, date: weekAgo, roundsCompleted: 6
        )
        XCTAssertNil(
            PRDetector.detectTimedFormatPR(session: attempt, history: [history]),
            "EMOM ist pass/fail, kein maximierbarer Wert — bewusst kein PR-Kind"
        )
    }

    /// Nutzer-Feedback (13. August, zweite Runde): `.circuit` hat eine vom
    /// Tag fest vorgegebene Rundenzahl (`TrainingDay.circuitRounds`) - anders
    /// als EMOM (pass/fail) ist hier `roundsCompleted` sogar ein Zahlenwert,
    /// der theoretisch verglichen werden KOENNTE, aber bewusst nicht wird:
    /// die Zahl ist durch den Plan fix, keine variable Leistung, gegen die
    /// sich ein Bestwert bilden liesse.
    func testCircuitNeverProducesAPR() {
        let attempt = TimedWorkoutAttempt(
            wodName: "Ganzkörper-Komplex", format: .circuit, date: now, roundsCompleted: 5
        )
        let history = TimedWorkoutAttempt(
            wodName: "Ganzkörper-Komplex", format: .circuit, date: weekAgo, roundsCompleted: 3
        )
        XCTAssertNil(
            PRDetector.detectTimedFormatPR(session: attempt, history: [history]),
            "Zirkel-Rundenzahl ist durch den Tag fest vorgegeben, kein maximierbarer Wert — bewusst kein PR-Kind"
        )
    }

    // MARK: - DEL-218 displayOrder

    /// Regression: `displayOrder` MUSS jeden Case enthalten. Vor DEL-218 lag
    /// die Reihenfolge in vier Kopien, zwei davon ohne die Cardio-Kinds —
    /// Cardio-PRs waren im Trophy-Room dadurch unsichtbar (leere Kind-Liste
    /// ⇒ kein Picker, kein Chart). Faellt dieser Test, verschwindet ein Kind
    /// still aus der gesamten Anzeige.
    func testDisplayOrderCoversEveryKind() {
        XCTAssertEqual(
            Set(PersonalRecord.Kind.displayOrder),
            Set(PersonalRecord.Kind.allCases),
            "displayOrder muss alle Kind-Cases abdecken — fehlende Cases werden unsichtbar"
        )
        XCTAssertEqual(
            PersonalRecord.Kind.displayOrder.count,
            PersonalRecord.Kind.allCases.count,
            "displayOrder darf keine Duplikate enthalten"
        )
    }

    /// Strength-PRs rangieren vor Cardio-PRs (DEL-064-Entscheidung), und 1RM
    /// bleibt der Spitzenplatz.
    func testDisplayPriorityRanksStrengthBeforeCardio() {
        XCTAssertEqual(PersonalRecord.Kind.estimated1RM.displayPriority, 0)
        for strength in [PersonalRecord.Kind.estimated1RM, .heaviestWeight, .bestSet, .maxReps, .maxHoldSeconds] {
            for cardio in [PersonalRecord.Kind.longestDistance, .fastestPace] {
                XCTAssertLessThan(
                    strength.displayPriority, cardio.displayPriority,
                    "\(strength) sollte vor \(cardio) rangieren"
                )
            }
        }
    }

    // MARK: - Settings-Epic Phase 6 (EXLIB-07/09): ID-first Gruppierung

    /// Kernfall des Bugs: eine Uebung wurde umbenannt (Historie traegt noch
    /// den ALTEN Namens-Snapshot, die aktuelle Session den NEUEN), aber
    /// beide Attempts tragen dieselbe stabile `exerciseTemplateID`. Vor
    /// Phase 6 waere das eine "neue Uebung ohne Historie" gewesen (0 PRs,
    /// weil `exerciseHistory` leer bleibt) — jetzt gruppiert die ID beide
    /// zusammen, die Historie bleibt gefunden.
    func testRenameSurvivesViaSharedTemplateID() {
        let templateID = UUID()
        // Gleiche Zahlen wie testHeaviestWeightPRDetected (dort gegen den
        // Namen allein verifiziert): 90kg x 3 schlaegt nur das Gewicht
        // (90 gegen 80), nicht Volume (270 gegen 640) oder 1RM (99 gegen
        // 101.33) — isoliert also sauber genau EINEN PR-Kind.
        let history = LiftAttempt(
            exerciseName: "Alter Name", exerciseTemplateID: templateID,
            weightKg: 80, reps: 8, date: weekAgo
        )
        let session = LiftAttempt(
            exerciseName: "Neuer Name", exerciseTemplateID: templateID,
            weightKg: 90, reps: 3, date: now
        )
        let prs = PRDetector.detectPRs(sessionLifts: [session], history: [history])
        XCTAssertEqual(prs.count, 1, "Trotz Namenswechsel sollte die gemeinsame ID die Historie finden")
        XCTAssertEqual(prs.first?.kind, .heaviestWeight)
        XCTAssertEqual(prs.first?.exerciseTemplateID, templateID)
        // Anzeige-Name ist der AKTUELLE (Session-)Name, nicht der veraltete.
        XCTAssertEqual(prs.first?.exerciseName, "Neuer Name")
    }

    /// Kehrprobe: zwei verschiedene Uebungen, die zufaellig denselben Namen
    /// tragen (z.B. eine geloeschte und eine neu angelegte Custom-Uebung),
    /// aber unterschiedliche IDs — duerfen NIEMALS zusammengelegt werden,
    /// sonst koennte ein Namens-Zufall fremde Historie "erben".
    func testDifferentTemplateIDsWithSameNameStayAparts() {
        let idA = UUID()
        let idB = UUID()
        let history = LiftAttempt(
            exerciseName: "Rudern", exerciseTemplateID: idA,
            weightKg: 80, reps: 8, date: weekAgo
        )
        let session = LiftAttempt(
            exerciseName: "Rudern", exerciseTemplateID: idB,
            weightKg: 90, reps: 8, date: now
        )
        let prs = PRDetector.detectPRs(sessionLifts: [session], history: [history])
        XCTAssertTrue(prs.isEmpty, "Unterschiedliche IDs duerfen trotz gleichem Namen keine Historie teilen")
    }

    /// Alt-Daten ohne jede ID (vor dieser Phase geloggt, nicht per Backfill
    /// aufloesbar) gruppieren weiterhin per Name — unveraendertes Verhalten,
    /// keine Regression.
    func testNilTemplateIDFallsBackToNameGrouping() {
        let prs = PRDetector.detectPRs(
            sessionLifts: [bench(90, 3)],
            history: [bench(80, 8, weekAgo)]
        )
        XCTAssertEqual(prs.count, 1)
        XCTAssertNil(prs.first?.exerciseTemplateID)
    }

    /// Eine Seite mit ID, die andere ohne (z.B. Session schon migriert,
    /// Historie-Zeile ein nicht per Backfill aufloesbarer Alt-Eintrag mit
    /// zufaellig gleichem Namen) — gilt bewusst als NICHT derselbe Bucket,
    /// damit nie ID- und Namens-Identitaet vermischt werden.
    func testMixedIDAndNilNeverMerge() {
        let session = LiftAttempt(
            exerciseName: "Bankdruecken", exerciseTemplateID: UUID(),
            weightKg: 90, reps: 8, date: now
        )
        let history = bench(80, 8, weekAgo)   // kein exerciseTemplateID
        let prs = PRDetector.detectPRs(sessionLifts: [session], history: [history])
        XCTAssertTrue(prs.isEmpty, "ID-Attempt und namensgleicher Nil-ID-Attempt duerfen nicht gemischt gruppiert werden")
    }
}
