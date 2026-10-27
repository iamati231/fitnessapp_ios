import XCTest

/// Audit-Fund (ponytail-audit UI, Phase 2 des Save-Fehler-Tickets): drei unabhaengige
/// diskrete Save-Aktionen in `DashboardView`/`PRHistoryView`/`ExerciseLibraryView`.
/// Quelltext-Pruefung (gleiches Muster wie `BodyDataEditorRollbackTests`).
final class DashboardPRLibrarySaveErrorHandlingTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    /// `discardOtherOpenSessionsAndStartNew()`: ein fehlgeschlagener Save darf
    /// `pendingNewStart?()` NICHT ausloesen - sonst landet der User in einer neuen
    /// Session, waehrend die "verworfenen" alten Sessions unklar im Context stehen.
    func testDashboardDiscardOtherOpenSessionsReturnsBeforePendingNewStart() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("DashboardView.swift"), encoding: .utf8
        )
        XCTAssertFalse(text.contains("try? modelContext.save()"))
        XCTAssertFalse(stripLineComments(text).contains("modelContext.rollback()"))

        guard let funcStart = text.range(of: "private func discardOtherOpenSessionsAndStartNew() {") else {
            return XCTFail("discardOtherOpenSessionsAndStartNew() not found at the expected signature")
        }
        guard let funcEnd = text.range(of: "\n    }", range: funcStart.upperBound..<text.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = text[funcStart.upperBound..<funcEnd.lowerBound]
        guard let catchRange = body.range(of: "} catch {") else {
            return XCTFail("must use do/catch instead of try?")
        }
        guard let pendingCall = body.range(of: "pendingNewStart?()", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("pendingNewStart?() not found after the catch block")
        }
        XCTAssertTrue(pendingCall.lowerBound > catchRange.upperBound,
                      "pendingNewStart?() must only run AFTER the catch block, i.e. only on a successful save")
    }

    /// `rebuild()`: der Erfolgs-Toast ("N Rekorde detektiert") darf nur im TRY-Zweig
    /// zugewiesen werden, nicht unbedingt - sonst behauptet die UI einen nie
    /// gespeicherten Erfolg (schlimmer als stilles Schweigen).
    func testPRHistoryRebuildOnlyAssignsSuccessMessageInsideTry() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("History/PRHistoryView.swift"), encoding: .utf8
        )
        XCTAssertFalse(text.contains("try? modelContext.save()"))

        guard let funcStart = text.range(of: "private func rebuild() {") else {
            return XCTFail("rebuild() not found at the expected signature")
        }
        guard let funcEnd = text.range(of: "\n    }", range: funcStart.upperBound..<text.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = text[funcStart.upperBound..<funcEnd.lowerBound]

        guard let tryRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("must use do/catch instead of try?")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        let tryBranch = body[tryRange.upperBound..<catchRange.lowerBound]
        XCTAssertTrue(tryBranch.contains("message = \"\\(inserted) Rekorde detektiert\""),
                      "the success message must be assigned only in the try branch")

        guard let catchEnd = body.range(of: "\n        }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBranch = body[catchRange.upperBound..<catchEnd.lowerBound]
        XCTAssertFalse(catchBranch.contains("Rekorde detektiert"),
                       "a failed save must never claim records were detected/saved")
    }

    /// `deleteTemplate(_:)`: do/catch statt `try?`.
    func testExerciseLibraryDeleteTemplateUsesDoCatch() throws {
        let text = try String(
            contentsOf: sourcesRoot.appendingPathComponent("Settings/ExerciseLibraryView.swift"), encoding: .utf8
        )
        XCTAssertFalse(text.contains("try? modelContext.save()"))

        guard let funcStart = text.range(of: "private func deleteTemplate(_ template: ExerciseTemplate) {") else {
            return XCTFail("deleteTemplate(_:) not found at the expected signature")
        }
        guard let funcEnd = text.range(of: "\n    }", range: funcStart.upperBound..<text.endIndex) else {
            return XCTFail("function end not found")
        }
        let body = text[funcStart.upperBound..<funcEnd.lowerBound]
        XCTAssertTrue(body.contains("} catch {"), "must use do/catch instead of try?")
        XCTAssertTrue(body.contains("showTimedWorkoutSaveErrorToast"), "failure must surface via the shared toast helper")
    }
}
