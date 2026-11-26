import XCTest

/// Audit-Fund (Modul 19, ActiveWorkoutView). `maybeAutoAdvance` plante den
/// Seitenwechsel per `DispatchQueue.main.asyncAfter`, ohne beim Feuern zu
/// pruefen, ob `currentPageIndex` inzwischen manuell geaendert wurde oder ob
/// `nextIndex` angesichts der aktuellen `resolvedExercises`-Liste noch
/// gueltig ist - ein laengst veralteter Closure konnte so eine manuelle
/// Navigation ueberschreiben oder nach einer Loeschung auf eine nicht mehr
/// existente Seite springen.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class ActiveWorkoutViewAutoAdvanceStaleTests: XCTestCase {
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

    func testMaybeAutoAdvanceRevalidatesBeforeApplyingTheDelayedPageChange() throws {
        let text = try source
        guard let start = text.range(of: "private func maybeAutoAdvance(after exercise: Exercise,") else {
            return XCTFail("maybeAutoAdvance(after:targetSets:currentIndex:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of maybeAutoAdvance not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("pageNavigationGeneration == expectedGeneration"),
                      "a delayed auto-advance must check it is still the most recent scheduled navigation before applying it")
        XCTAssertTrue(body.contains("nextIndex <= resolvedExercises.count"),
                      "a delayed auto-advance must re-validate nextIndex against the current exercise list before applying it")
    }

    func testCurrentPageIndexChangesInvalidatePendingAutoAdvance() throws {
        let text = try source
        XCTAssertTrue(text.contains(".onChange(of: currentPageIndex) { _, _ in pageNavigationGeneration += 1 }"),
                      "any change to currentPageIndex (manual swipe included) must invalidate a pending delayed auto-advance")
    }
}
