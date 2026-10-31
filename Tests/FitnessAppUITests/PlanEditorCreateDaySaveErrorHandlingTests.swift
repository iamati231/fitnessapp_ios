import XCTest

/// Audit-Fund (Follow-up-UI-Audit, "Adding a rest day to a plan is never
/// saved"): `createNewDay(type:)` inserted den neuen Tag ohne Save - die
/// direkt danebenliegende `deleteDays(at:)` hat denselben Bug-Typ schon
/// dokumentiert gefixt, `createNewDay` wurde uebersehen. Quelltext-Pruefung,
/// weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class PlanEditorCreateDaySaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/Workout/PlanEditorView.swift"),
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

    /// Ein fehlgeschlagener Save darf weder in den `DayEditorView` navigieren
    /// noch den neu inserteten Tag im Context belassen.
    func testCreateNewDayDeletesDayAndReturnsBeforeNavigatingOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func createNewDay(type: DayType) {") else {
            return XCTFail("createNewDay(type:) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

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
        XCTAssertTrue(catchBody.contains("modelContext.delete(day)"),
                      "a failed save must delete the just-inserted day")
        XCTAssertTrue(catchBody.contains("return"),
                      "the catch block must return before the navigation-append below")

        guard let navigateCall = body.range(of: "navigation.workoutPath.append(day)", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("navigation.workoutPath.append(day) must still happen on the success path")
        }
        XCTAssertTrue(navigateCall.lowerBound > catchEnd.upperBound,
                      "navigation must only happen AFTER the catch block, i.e. only on a successful save")
    }
}
