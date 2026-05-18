import XCTest
@testable import FitnessAppCore

/// DEL-097: Tests fuer den Single-Active-Time-Based-Exercise-Guard.
final class TimedExerciseGuardTests: XCTestCase {

    // MARK: canStart

    /// Strength-Lift hat keinen Hold-Timer — der Guard greift nicht.
    func testStrengthExerciseAlwaysCanStart() {
        let result = TimedExerciseGuard.canStart(
            candidateID: "bench-press",
            candidateIsTimeBased: false,
            activeTimedExerciseID: "plank"   // Plank laeuft, sollte aber Bench nicht stoppen
        )
        XCTAssertTrue(result, "Strength-Lifts duerfen nie geguarded werden")
    }

    /// Cardio-Eintrag (Run) ist nicht time-based im Plank-Sinn — gleicher
    /// Pfad wie Strength.
    func testCardioExerciseAlwaysCanStart() {
        let result = TimedExerciseGuard.canStart(
            candidateID: "easy-run",
            candidateIsTimeBased: false,
            activeTimedExerciseID: "plank"
        )
        XCTAssertTrue(result)
    }

    /// Slot frei → Time-Exercise darf starten.
    func testTimeExerciseCanStartWhenSlotIsFree() {
        let result = TimedExerciseGuard.canStart(
            candidateID: "plank",
            candidateIsTimeBased: true,
            activeTimedExerciseID: nil
        )
        XCTAssertTrue(result)
    }

    /// Slot wird von der SELBEN Uebung gehalten → Resume erlaubt.
    func testTimeExerciseCanResumeItself() {
        let result = TimedExerciseGuard.canStart(
            candidateID: "plank",
            candidateIsTimeBased: true,
            activeTimedExerciseID: "plank"
        )
        XCTAssertTrue(result, "Same-exercise Resume muss erlaubt bleiben")
    }

    /// Slot wird von einer ANDEREN Time-Exercise gehalten → Block.
    func testSecondTimeExerciseBlockedWhilePlankIsRunning() {
        let result = TimedExerciseGuard.canStart(
            candidateID: "wall-sit",
            candidateIsTimeBased: true,
            activeTimedExerciseID: "plank"
        )
        XCTAssertFalse(result, "Wall Sit darf nicht starten, solange Plank laeuft")
    }

    // MARK: isBlockedByOther — Komplement-Check

    func testStrengthLiftIsNeverBlocked() {
        XCTAssertFalse(TimedExerciseGuard.isBlockedByOther(
            candidateID: "bench-press",
            candidateIsTimeBased: false,
            activeTimedExerciseID: "plank"
        ))
    }

    func testTimeExerciseNotBlockedWhenSlotEmpty() {
        XCTAssertFalse(TimedExerciseGuard.isBlockedByOther(
            candidateID: "plank",
            candidateIsTimeBased: true,
            activeTimedExerciseID: nil
        ))
    }

    func testTimeExerciseNotBlockedByItself() {
        XCTAssertFalse(TimedExerciseGuard.isBlockedByOther(
            candidateID: "plank",
            candidateIsTimeBased: true,
            activeTimedExerciseID: "plank"
        ))
    }

    func testTimeExerciseBlockedByOtherTimeExercise() {
        XCTAssertTrue(TimedExerciseGuard.isBlockedByOther(
            candidateID: "wall-sit",
            candidateIsTimeBased: true,
            activeTimedExerciseID: "plank"
        ))
    }

    // MARK: ID-Typ-Vielfalt (Generic-Verhalten)

    /// Beispiel mit UUID — analog zum SwiftData-PersistentIdentifier in
    /// der UI-Schicht (dort wird Exercise.persistentModelID verwendet,
    /// das ebenfalls Hashable ist).
    func testGenericWorksWithUUID() {
        let plankID = UUID()
        let wallSitID = UUID()

        XCTAssertTrue(TimedExerciseGuard.canStart(
            candidateID: plankID,
            candidateIsTimeBased: true,
            activeTimedExerciseID: plankID
        ))
        XCTAssertFalse(TimedExerciseGuard.canStart(
            candidateID: wallSitID,
            candidateIsTimeBased: true,
            activeTimedExerciseID: plankID
        ))
    }
}
