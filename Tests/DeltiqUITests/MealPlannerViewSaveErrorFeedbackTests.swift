import XCTest

/// Audit-Fund (Modul-17-Folge-Task, try?-Fehlerverschlucken in MealPlannerView):
/// sechs Mutations-Pfade (Portion anpassen, Rezept tauschen, Zuweisung entfernen,
/// neu generieren, Rezept ausschliessen, Optimierung anwenden) verschluckten einen
/// Save-Fehlschlag komplett per `try?` - der Nutzer sah weder eine Rueckmeldung,
/// noch (fuer diese reinen Edit/Delete-Pfade bewusst, siehe
/// `PlansListView.deletePlans`/`ExerciseCard.unlogSet`) einen Rollback-Versuch.
/// Quelltext-Pruefung (gleiches Muster wie `ExerciseCardSaveErrorHandlingTests`),
/// weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class MealPlannerViewSaveErrorFeedbackTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Nutrition/MealPlannerView.swift"),
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

    private func body(ofFunctionStartingWith signature: String, in cleaned: String) throws -> Substring {
        guard let funcStart = cleaned.range(of: signature) else {
            XCTFail("\(signature) not found at the expected signature")
            return cleaned[cleaned.startIndex..<cleaned.startIndex]
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            XCTFail("end of \(signature) not found")
            return cleaned[cleaned.startIndex..<cleaned.startIndex]
        }
        return cleaned[funcStart.upperBound..<funcEnd.lowerBound]
    }

    func testNoTryQuestionMarkModelContextSaveRemains() throws {
        XCTAssertFalse(try source.contains("try? modelContext.save()"))
    }

    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(Self.stripLineComments(try source).contains("modelContext.rollback()"))
    }

    func testAdjustPortionSurfacesSaveError() throws {
        let cleaned = Self.stripLineComments(try source)
        let b = try body(ofFunctionStartingWith: "private func adjustPortion(_ assignment: PlannedMealAssignment, by delta: Double) {", in: cleaned)
        XCTAssertTrue(b.contains("} catch {"), "adjustPortion must use do/catch instead of try?")
        XCTAssertTrue(b.contains("saveErrorMessage = "), "a failed save must surface an error")
    }

    func testSwapAssignmentSurfacesSaveError() throws {
        let cleaned = Self.stripLineComments(try source)
        let b = try body(ofFunctionStartingWith: "private func swapAssignment(_ assignment: PlannedMealAssignment, to newRecipe: Recipe) {", in: cleaned)
        XCTAssertTrue(b.contains("} catch {"), "swapAssignment must use do/catch instead of try?")
        XCTAssertTrue(b.contains("saveErrorMessage = "), "a failed save must surface an error")
    }

    func testRemoveAssignmentSurfacesSaveErrorWithoutUndoingTheDelete() throws {
        let cleaned = Self.stripLineComments(try source)
        let b = try body(ofFunctionStartingWith: "private func removeAssignment(_ assignment: PlannedMealAssignment) {", in: cleaned)
        XCTAssertTrue(b.contains("} catch {"), "removeAssignment must use do/catch instead of try?")
        XCTAssertTrue(b.contains("saveErrorMessage = "), "a failed save must surface an error")
        // delete() wirkt schon vor dem Save auf den Live-Graphen - kein Re-Insert-Versuch.
        XCTAssertFalse(b.contains("modelContext.insert("), "removeAssignment must not attempt to re-insert the deleted assignment")
    }

    func testRegenerateAssignmentSurfacesSaveError() throws {
        let cleaned = Self.stripLineComments(try source)
        let b = try body(ofFunctionStartingWith: "private func regenerateAssignment(_ assignment: PlannedMealAssignment) {", in: cleaned)
        XCTAssertTrue(b.contains("} catch {"), "regenerateAssignment must use do/catch instead of try?")
        XCTAssertTrue(b.contains("saveErrorMessage = "), "a failed save must surface an error")
    }

    func testApplyOptimizationSurfacesSaveError() throws {
        let cleaned = Self.stripLineComments(try source)
        let b = try body(ofFunctionStartingWith: "private func applyOptimization(_ proposal: OptimizedPlanProposal) {", in: cleaned)
        XCTAssertTrue(b.contains("} catch {"), "applyOptimization must use do/catch instead of try?")
        XCTAssertTrue(b.contains("saveErrorMessage = "), "a failed save must surface an error")
    }

    func testExcludeActionNoLongerSavesTwiceBeforeRemoving() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let appendCall = cleaned.range(of: "mealPlanExcludedRecipeIDsRaw.append(assignment.recipeID)") else {
            return XCTFail("exclude action not found at the expected call site")
        }
        guard let removeCall = cleaned.range(of: "removeAssignment(assignment)", range: appendCall.upperBound..<cleaned.endIndex) else {
            return XCTFail("exclude action must still remove the assignment")
        }
        let between = cleaned[appendCall.upperBound..<removeCall.lowerBound]
        XCTAssertFalse(between.contains("modelContext.save()"),
                        "the exclude action must rely on removeAssignment's own save instead of saving twice")
    }

    func testSaveErrorMessageStateAndDisplayExist() throws {
        let cleaned = Self.stripLineComments(try source)
        XCTAssertTrue(cleaned.contains("@State private var saveErrorMessage: String?"))
        XCTAssertTrue(cleaned.contains("if let saveErrorMessage {"))
    }
}
