import XCTest

/// Audit-Fund (Modul (e), WorkoutSummaryView+Health-Export): `deleteSets(of:indices:)`
/// loeschte ExerciseLogs und rief `session.recomputeTotals()` auf, aber nie
/// `modelContext.save()` - jede andere mutierende Funktion in dieser Datei
/// (`removeExerciseFromSession`, `addSet`, `assignGear`, etc.) speichert
/// explizit mit do/catch + `showSaveErrorToast()`. Ohne das haengt der
/// geloeschte Satz allein am impliziten SwiftData-Autosave; ein App-Kill
/// kurz nach dem Loeschen kann ihn nach Neustart wiederauferstehen lassen.
/// Quelltext-Pruefung, da `deleteSets` `private` ist und reines
/// SwiftUI-View-Verhalten ohne Test-Seam fuer einen echten Save-Fehlschlag.
final class WorkoutSummaryDeleteSetsSaveTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift"),
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

    func testDeleteSetsSavesAfterRecomputingTotals() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private func deleteSets(of exercise: Exercise, indices: IndexSet) {") else {
            return XCTFail("deleteSets(of:indices:) not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of deleteSets(of:indices:) not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let recomputeRange = body.range(of: "session.recomputeTotals()") else {
            return XCTFail("session.recomputeTotals() call not found - fix moved or removed it")
        }
        guard let saveRange = body.range(of: "modelContext.save()") else {
            return XCTFail("deleteSets(of:indices:) must call modelContext.save() - " +
                           "otherwise a deleted set can survive only in memory and resurrect after an app kill")
        }
        XCTAssertTrue(recomputeRange.upperBound < saveRange.lowerBound,
                      "save() must happen AFTER recomputeTotals(), not before, so the saved totals reflect the deletion")
        XCTAssertTrue(body.contains("catch"),
                      "a failed save must not silently leave the deletion unsaved - needs a catch branch")
        XCTAssertTrue(body.contains("showSaveErrorToast()"),
                      "a failed save must surface an error to the user via the established toast convention")
    }
}
