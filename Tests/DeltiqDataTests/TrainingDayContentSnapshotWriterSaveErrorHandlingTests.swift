import XCTest

/// Modul-8-Audit (Workout-Ausfuehrung): alle fuenf `Bool`-zurueckgebenden
/// Snapshot-Writer-Funktionen (`capture`, `recordAdHocExerciseAdded`,
/// `recordAdHocExerciseRemoved`, `recordAdHocExerciseEdited`,
/// `recordSetCountChange`) nutzten `try? context.save()` und gaben
/// anschliessend unbedingt `true` zurueck - ein echter Save-Fehlschlag war
/// fuer JEDEN Aufrufer unsichtbar, selbst einen, der den Rueckgabewert
/// korrekt prueft (z.B. `ExerciseCard.addSet()`/`removeSet()`). Quelltext-
/// Pruefung (gleiches Muster wie `ExerciseCardSaveErrorHandlingTests`),
/// weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class TrainingDayContentSnapshotWriterSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // this file
                    .deletingLastPathComponent() // DeltiqDataTests
                    .deletingLastPathComponent() // Tests
                    .appendingPathComponent("Sources/DeltiqData/TrainingDayContentSnapshotWriter.swift"),
                encoding: .utf8
            )
        }
    }

    func testNoTryQuestionMarkSaveRemains() throws {
        XCTAssertFalse(try source.contains("try? context.save()"))
    }

    /// All five `-> Bool` functions must now return `false` on a genuine save
    /// failure, not unconditionally `true`.
    func testFiveDoCatchCheckpointsReturnFalseOnSaveFailure() throws {
        let text = try source
        let doCatchCount = text.components(separatedBy: "do {\n            try context.save()\n        } catch {\n            return false\n        }").count - 1
        XCTAssertEqual(doCatchCount, 5,
                       "expected all 5 snapshot-writer functions (capture, recordAdHocExerciseAdded/Removed/Edited, recordSetCountChange) to return false on a save failure")
    }
}
