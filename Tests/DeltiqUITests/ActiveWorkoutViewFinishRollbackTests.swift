import XCTest

/// Audit-Fund (Modul 19, aktives Training). `finishWorkout()` mutierte
/// `session.isCompleted`/Timing/Totals/`Exercise.suggestedWeight` und fuegte
/// `PersonalRecordEntry`-Zeilen ein, BEVOR `modelContext.save()` lief. Schlug
/// der Save fehl, blieb all das im Speicher stehen (nur ein Fehler-Toast,
/// keine der Mutationen wurde zurueckgenommen) - widerspricht dem Muster im
/// selben File (`addAdHocExercise`/`addAdHocCustomExercise` machen ihren
/// eigenen Insert im catch-Block explizit rueckgaengig).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class ActiveWorkoutViewFinishRollbackTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ActiveWorkoutView.swift"),
                encoding: .utf8
            )
        }
    }

    private var finishWorkoutBody: Substring {
        get throws {
            let text = try source
            guard let start = text.range(of: "private func finishWorkout() {") else {
                XCTFail("finishWorkout() not found at the expected signature")
                return Substring("")
            }
            guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
                XCTFail("end of finishWorkout() not found")
                return Substring("")
            }
            return text[start.upperBound..<end.lowerBound]
        }
    }

    func testPreMutationStateIsSnapshottedBeforeAnyMutation() throws {
        let body = try finishWorkoutBody
        guard let snapshotRange = body.range(of: "let priorInsertedIDs"),
              let saveRange = body.range(of: "try modelContext.save()")
        else {
            return XCTFail("expected both the snapshot and the save call in finishWorkout()")
        }
        XCTAssertTrue(snapshotRange.lowerBound < saveRange.lowerBound,
                      "the rollback snapshot must be taken before modelContext.save(), not after")
    }

    func testCatchBlockRestoresSessionFieldsAndIsCompleted() throws {
        let body = try finishWorkoutBody
        guard let catchRange = body.range(of: "} catch {") else {
            return XCTFail("finishWorkout() must have a catch block around modelContext.save()")
        }
        let catchBody = body[catchRange.upperBound...]

        XCTAssertTrue(catchBody.contains("session.isCompleted = false"),
                      "a failed save must revert isCompleted, not leave the session marked completed in memory")
        XCTAssertTrue(catchBody.contains("session.startTime = priorStartTime"))
        XCTAssertTrue(catchBody.contains("session.endTime = priorEndTime"))
        XCTAssertTrue(catchBody.contains("session.durationMinutes = priorDurationMinutes"))
        XCTAssertTrue(catchBody.contains("session.totalSets = priorTotalSets"))
        XCTAssertTrue(catchBody.contains("session.totalVolumeKg = priorTotalVolumeKg"))
        XCTAssertTrue(catchBody.contains("session.exerciseCount = priorExerciseCount"))
    }

    func testCatchBlockRestoresSuggestedWeightsAndDeletesNewlyInsertedModels() throws {
        let body = try finishWorkoutBody
        guard let catchRange = body.range(of: "} catch {") else {
            return XCTFail("finishWorkout() must have a catch block around modelContext.save()")
        }
        let catchBody = body[catchRange.upperBound...]

        XCTAssertTrue(catchBody.contains("exercise.suggestedWeight = weight"),
                      "Exercise.suggestedWeight changes from ProgressionApplicator.apply must be reverted on a failed save")
        XCTAssertTrue(catchBody.contains("modelContext.delete(inserted)"),
                      "PersonalRecordEntry rows inserted by PersonalRecordSync.recordPRs must be deleted on a failed save")
        XCTAssertFalse(catchBody.contains("modelContext.rollback()"),
                       "must not use a blanket rollback() - it would also discard independent, unrelated pending changes elsewhere in the shared context (repo convention)")
    }
}
