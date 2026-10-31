import XCTest

/// Audit-Fund (dritter Follow-up-UI-Audit): `createNewPlan()` und
/// `duplicatePlan(_:)` inserten einen neuen Plan (Fund 4) bzw. eine
/// Tiefkopie (Fund 3), ohne je explizit zu speichern. Quelltext-Pruefung,
/// weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class PlansListSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/FitnessAppUI/Workout/PlansListView.swift"),
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

    func testCreateNewPlanDeletesAndReturnsBeforeNavigatingOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func createNewPlan() {") else {
            return XCTFail("createNewPlan() not found at the expected signature")
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
        XCTAssertTrue(catchBody.contains("modelContext.delete(plan)"),
                      "a failed save must delete the just-inserted plan")
        XCTAssertTrue(catchBody.contains("return"),
                      "the catch block must return before the navigation-append below")

        guard let navigateCall = body.range(of: "navigation.workoutPath.append(plan)", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("navigation.workoutPath.append(plan) must still happen on the success path")
        }
        XCTAssertTrue(navigateCall.lowerBound > catchEnd.upperBound,
                      "navigation must only happen AFTER the catch block, i.e. only on a successful save")
    }

    func testDuplicatePlanDeletesTheCopyOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func duplicatePlan(_ source: TrainingPlan) {") else {
            return XCTFail("duplicatePlan(_:) not found at the expected signature")
        }
        guard let tryRange = cleaned.range(of: "try modelContext.save()", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("must use do/catch instead of relying on implicit autosave")
        }
        guard let catchRange = cleaned.range(of: "} catch {", range: tryRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let catchEnd = cleaned.range(of: "\n        }", range: catchRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = cleaned[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertTrue(catchBody.contains("modelContext.delete(copy)"),
                      "a failed save must delete the deep-copied plan (cascades to its days/exercises)")
    }
}
