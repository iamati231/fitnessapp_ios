import XCTest

/// Audit-Fund (fuenfter Follow-up-UI-Audit, Fund 1+2): `beginTimedAdHocWorkout`
/// und `markRestDaySkipped` hingen am impliziten Autosave - Fund 2 ist ein
/// zweiter, separater Entry-Point fuer denselben Bug, der bei
/// `DayEditorView.markRestDaySkipped()` schon gefixt wurde. Quelltext-
/// Pruefung, weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class DashboardViewSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/DashboardView.swift"),
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

    private static func body(of signature: String, in cleaned: String) throws -> Substring {
        guard let funcStart = cleaned.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return cleaned[funcStart.upperBound..<funcEnd.lowerBound]
    }

    /// A failed save must not navigate into DayEditorView for a day that
    /// was never actually persisted.
    func testBeginTimedAdHocWorkoutReturnsBeforeNavigatingOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func beginTimedAdHocWorkout(format: WorkoutTimeFormat) {", in: cleaned)

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
        XCTAssertTrue(catchBody.contains("modelContext.delete(adHocDay)"),
                      "a failed save must delete the just-inserted day")
        XCTAssertTrue(catchBody.contains("return"),
                      "the catch block must return before the navigation below")

        guard let navigateCall = body.range(of: "navigation.workoutPath.append(adHocDay)", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("navigation.workoutPath.append(adHocDay) must still happen on the success path")
        }
        XCTAssertTrue(navigateCall.lowerBound > catchEnd.upperBound,
                      "navigation must only happen AFTER the catch block, i.e. only on a successful save")
    }

    func testMarkRestDaySkippedSavesExplicitly() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func markRestDaySkipped(plan: TrainingPlan, day: TrainingDay) {", in: cleaned)

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
        XCTAssertTrue(catchBody.contains("modelContext.delete(session)"),
                      "a failed save must delete the just-inserted session")
        XCTAssertTrue(catchBody.contains("showTimedWorkoutSaveErrorToast"))
    }
}
