import XCTest

/// Audit-Fund (dritter Follow-up-UI-Audit, "ActiveWorkoutView.swift hat
/// nirgends einen expliziten modelContext.save()"): finishWorkout/
/// discardWorkout/addAdHocExercise/addAdHocCustomExercise/
/// deleteAdHocExercise hingen komplett am impliziten SwiftData-Autosave.
/// Quelltext-Pruefung, weil `save()` keinen Test-Seam fuer einen echten
/// Fehlschlag hat.
final class ActiveWorkoutSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/Workout/ActiveWorkoutView.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    private static func body(of signature: String, in cleaned: String, closingIndent: String) throws -> Substring {
        guard let funcStart = cleaned.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n\(closingIndent)}", range: funcStart.upperBound..<cleaned.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return cleaned[funcStart.upperBound..<funcEnd.lowerBound]
    }

    /// Ein fehlgeschlagener Save darf nicht zur WorkoutSummaryView navigieren
    /// (die laut eigener Doku annimmt, dass die Session bereits gespeichert ist).
    func testFinishWorkoutReturnsBeforeNavigatingOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func finishWorkout() {", in: cleaned, closingIndent: "    ")

        guard let tryRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("must use do/catch instead of relying on implicit autosave")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = body.range(of: "\n        }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("showTimedWorkoutSaveErrorToast"),
                      "a failed save must surface a visible error")
        XCTAssertTrue(catchBody.contains("return"),
                      "the catch block must return before navigating to the summary")

        guard let navigateCall = body.range(of: "navigation.workoutPath.append(SummaryRoute(session: session))", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("navigation to the summary must still happen on the success path")
        }
        XCTAssertTrue(navigateCall.lowerBound > catchEnd.upperBound,
                      "navigation must only happen AFTER the catch block, i.e. only on a successful save")
    }

    func testDiscardWorkoutSavesBeforeDismissing() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func discardWorkout() {", in: cleaned, closingIndent: "    ")

        guard let saveRange = body.range(of: "modelContext.save()") else {
            return XCTFail("discardWorkout must explicitly persist the deletion")
        }
        guard let dismissRange = body.range(of: "dismiss()", range: saveRange.upperBound..<body.endIndex) else {
            return XCTFail("dismiss() must still happen after the save attempt")
        }
        XCTAssertTrue(dismissRange.lowerBound > saveRange.upperBound)
    }

    func testAddAdHocExerciseDeletesAndTostsOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func addAdHocExercise(from template: ExerciseTemplate) {", in: cleaned, closingIndent: "    ")

        guard let tryRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("must use do/catch instead of relying on implicit autosave")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = body.range(of: "\n        }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("modelContext.delete(exercise)"),
                      "a failed save must delete the just-inserted exercise")
        XCTAssertTrue(catchBody.contains("showTimedWorkoutSaveErrorToast"))
    }

    func testAddAdHocCustomExerciseDeletesBothInsertsOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func addAdHocCustomExercise(_ draft: CustomExerciseDraft) {", in: cleaned, closingIndent: "    ")

        guard let tryRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("must use do/catch instead of relying on implicit autosave")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = body.range(of: "\n        }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("modelContext.delete(exercise)"))
        XCTAssertTrue(catchBody.contains("modelContext.delete(template)"))
        XCTAssertTrue(catchBody.contains("showTimedWorkoutSaveErrorToast"))
    }

    func testDeleteAdHocExerciseSavesAfterTheDeletes() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func deleteAdHocExercise(_ exercise: Exercise) {", in: cleaned, closingIndent: "    ")

        guard let lastDeleteRange = body.range(of: "modelContext.delete(exercise)") else {
            return XCTFail("exercise delete not found")
        }
        guard let saveRange = body.range(of: "try modelContext.save()", range: lastDeleteRange.upperBound..<body.endIndex) else {
            return XCTFail("save must happen after the exercise delete, not only inside recordAdHocExerciseRemoved")
        }
        XCTAssertTrue(saveRange.lowerBound > lastDeleteRange.upperBound)
    }
}
