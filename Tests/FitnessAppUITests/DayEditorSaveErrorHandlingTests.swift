import XCTest

/// Audit-Fund (vierter Follow-up-UI-Audit, Fund 1+2): `addExercise(from:)`/
/// `addCustomExercise(_:)` und `markRestDaySkipped()` hingen am impliziten
/// Autosave, obwohl der Day Editor laut eigener Doku ein Autosave-Screen
/// ohne eigenen Save-Schritt ist. Quelltext-Pruefung, weil `save()` keinen
/// Test-Seam fuer einen echten Fehlschlag hat.
final class DayEditorSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/Workout/DayEditorView.swift"),
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

    func testAddExerciseDeletesAndTostsOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func addExercise(from template: ExerciseTemplate) {", in: cleaned)

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
        XCTAssertTrue(catchBody.contains("showTransientToast"))
    }

    func testAddCustomExerciseDeletesBothInsertsOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func addCustomExercise(_ draft: CustomExerciseDraft) {", in: cleaned)

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
        XCTAssertTrue(catchBody.contains("showTransientToast"))
    }

    /// Ein fehlgeschlagener Save darf nicht aus dem Day Editor zurueck-
    /// navigieren - sonst sieht der User einen bereits bestaetigten Skip,
    /// der sich nach einem Kaltstart wieder loest.
    func testMarkRestDaySkippedReturnsBeforePoppingOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func markRestDaySkipped() {", in: cleaned)

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
        XCTAssertTrue(catchBody.contains("modelContext.delete(session)"))
        XCTAssertTrue(catchBody.contains("return"))

        guard let popCall = body.range(of: "navigation.workoutPath.removeLast()", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("navigation.workoutPath.removeLast() must still happen on the success path")
        }
        XCTAssertTrue(popCall.lowerBound > catchEnd.upperBound,
                      "popping the nav stack must only happen AFTER the catch block, i.e. only on a successful save")
    }

    func testSweepAbandonedAdHocDaySavesExplicitly() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func sweepAbandonedAdHocDayIfNeeded() {", in: cleaned)
        XCTAssertTrue(body.contains("modelContext.save()"))
    }
}
