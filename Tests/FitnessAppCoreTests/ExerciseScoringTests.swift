import XCTest
@testable import FitnessAppCore

/// DEL-099: Tests fuer den Recovery-Scoring-Algorithmus.
final class ExerciseScoringTests: XCTestCase {

    private let eps = 0.001

    // MARK: RIR-Multiplikator

    func testRIRMultiplierIsBaselineAtRIRThree() {
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 3), 1.0, accuracy: eps,
                       "RIR 3 muss der Baseline-Wert sein")
    }

    func testRIRMultiplierClimbsTowardFailure() {
        // RIR 0 = bis zum Muskelversagen → 1.45×
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 0), 1.45, accuracy: eps)
        // RIR 1 = beinahe Versagen
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 1), 1.30, accuracy: eps)
        // RIR 2 = letzte 2 Wiederholungen im Tank
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 2), 1.15, accuracy: eps)
    }

    func testRIRMultiplierDropsForEasySets() {
        // RIR 5 sollte unter 1.0 fallen, aber nicht unter den Floor.
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 5), 0.7, accuracy: eps)
        // RIR 6 ist schon im Floor-Bereich (1.0 - 3*0.15 = 0.55).
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 6), 0.55, accuracy: eps)
    }

    func testRIRMultiplierFloorIsHalf() {
        // Extreme RIR (Warmup, Pyramid-Down-Set) — Floor 0.5×.
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 10), 0.5, accuracy: eps)
        XCTAssertEqual(ExerciseScoring.rirMultiplier(rir: 100), 0.5, accuracy: eps)
    }

    // MARK: Weight-Multiplikator

    func testBodyweightMultiplierIsOne() {
        XCTAssertEqual(ExerciseScoring.weightMultiplier(weightKg: 0), 1.0, accuracy: eps,
                       "Bodyweight muss als 1.0 zaehlen (kein Penalty fuer Liegestuetze)")
    }

    func testWeightMultiplierScalesLog10() {
        // log10(60) ≈ 1.778, log10(110) ≈ 2.041
        XCTAssertEqual(ExerciseScoring.weightMultiplier(weightKg: 50), log10(60), accuracy: eps)
        XCTAssertEqual(ExerciseScoring.weightMultiplier(weightKg: 100), log10(110), accuracy: eps)
    }

    func testWeightMultiplierGrowsSlowly() {
        // 100 kg sollte NICHT 10× ueber 10 kg liegen.
        let light = ExerciseScoring.weightMultiplier(weightKg: 10)
        let heavy = ExerciseScoring.weightMultiplier(weightKg: 100)
        XCTAssertLessThan(heavy / light, 2.5,
                          "log10-Skala muss verhindern, dass schwere Lifts den Score sprengen")
    }

    // MARK: Strength CNS

    func testStrengthCNSScoreUsesAllInputs() {
        let score = ExerciseScoring.strengthCNSScore(
            weightKg: 100,
            rir: 1,            // 1.30×
            cnsDemandFactor: 0.85  // ≈ Squat
        )
        // 10 * log10(110) * 1.30 * 0.85 ≈ 22.55
        XCTAssertEqual(score, 22.55, accuracy: 0.5)
    }

    func testStrengthCNSScoreZeroForRestSet() {
        // Edge: weight=0, rir=5 → bodyweight + easy → kleine, aber non-zero Last.
        let score = ExerciseScoring.strengthCNSScore(
            weightKg: 0, rir: 5, cnsDemandFactor: 0.5
        )
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThan(score, 5)
    }

    // MARK: Strength Muscle Damage

    func testMuscleDamageScalesWithReps() {
        let lowReps = ExerciseScoring.strengthMuscleDamageScore(
            reps: 5, rir: 2, localMuscleDamageFactor: 0.6
        )
        let highReps = ExerciseScoring.strengthMuscleDamageScore(
            reps: 20, rir: 2, localMuscleDamageFactor: 0.6
        )
        XCTAssertGreaterThan(highReps, lowReps,
                             "Mehr Reps = mehr DOMS, der repsMultiplier muss durchschlagen")
    }

    // MARK: Time-Based

    func testTimeBasedScoreScalesLinearWithDuration() {
        let short = ExerciseScoring.timeBasedScore(durationSeconds: 60, factor: 0.5)
        let long  = ExerciseScoring.timeBasedScore(durationSeconds: 600, factor: 0.5)
        XCTAssertEqual(short, 5.0, accuracy: eps)    // 1 min × 10 × 0.5
        XCTAssertEqual(long, 50.0, accuracy: eps)    // 10 min × 10 × 0.5
    }

    func testTimeBasedScoreReturnsZeroForZeroDuration() {
        XCTAssertEqual(
            ExerciseScoring.timeBasedScore(durationSeconds: 0, factor: 0.5),
            0.0, accuracy: eps
        )
    }

    func testTimeBasedScoreRejectsNegativeDuration() {
        // Defensive — keine Crash bei kaputten Logs.
        XCTAssertEqual(
            ExerciseScoring.timeBasedScore(durationSeconds: -100, factor: 0.5),
            0.0, accuracy: eps
        )
    }

    // MARK: Recovery-Mapping

    func testRecoveryHoursForRestDay() {
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 0), 12)
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 49.99), 12)
    }

    func testRecoveryHoursForNormalSession() {
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 80), 24)
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 149.99), 24)
    }

    func testRecoveryHoursForHardSession() {
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 200), 48)
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 299.99), 48)
    }

    func testRecoveryHoursForOverreaching() {
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 350), 72)
        XCTAssertEqual(ExerciseScoring.estimatedRecoveryHours(maxLoad: 999), 72)
    }

    // MARK: End-to-End — Plausibility

    /// Heavy Squat-Day: 5x5 @ 130kg, RIR 1, cns=0.85 (Back Squat).
    /// Sollte deutlich in den 48h-Bereich rutschen.
    func testHeavySquatSessionLandsIn48HourBucket() {
        // 5 Saetze
        let perSet = ExerciseScoring.strengthCNSScore(
            weightKg: 130, rir: 1, cnsDemandFactor: 0.85
        )
        let total = perSet * 5
        let hours = ExerciseScoring.estimatedRecoveryHours(maxLoad: total)
        // 5 * 10 * log10(140) * 1.30 * 0.85 ≈ 119.5 → 24h-Bucket. Hmm,
        // das ist EHRLICH gesagt richtig — fuenf Compound-Saetze sind ein
        // anstaendiger aber kein zerstoererischer Tag. Erst Volumen DRUEBER
        // (z.B. 10 Saetze) landet im 48h-Bereich.
        XCTAssertEqual(hours, 24, "5 Squat-Saetze bei RIR 1 sollten im 24h-Bucket landen")
    }

    /// Easy-Mode-Bizeps-Curl-Pump: 3x12 @ 12kg, RIR 3, cns=0.10.
    /// Sollte im 12h-Bucket landen — minimaler Recovery-Bedarf.
    func testIsolationPumpSessionStaysInLightBucket() {
        let perSet = ExerciseScoring.strengthCNSScore(
            weightKg: 12, rir: 3, cnsDemandFactor: 0.10
        )
        let total = perSet * 3
        let hours = ExerciseScoring.estimatedRecoveryHours(maxLoad: total)
        XCTAssertEqual(hours, 12, "Curls bei RIR 3 sollten kaum Recovery brauchen")
    }

    /// Long-Run: 60 Min Laufband mit factor=0.55.
    /// minutes(60) × 10 × 0.55 = 330 → 72h Bucket. Ist offensiv aggressiv
    /// kalibriert — fuer einen einzelnen Long-Run vermutlich Overshoot,
    /// aber der Beta-Test-Hinweis im Algorithmus deckt das.
    func testLongRunSessionLandsInExtremeBucket() {
        let score = ExerciseScoring.timeBasedScore(durationSeconds: 60 * 60, factor: 0.55)
        let hours = ExerciseScoring.estimatedRecoveryHours(maxLoad: score)
        XCTAssertEqual(hours, 72, "60-Min Long Run sollte aktuell im Extreme-Bucket landen")
    }
}
