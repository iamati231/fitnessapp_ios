#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppData
@testable import FitnessAppUI

/// TestingBot-Regressionscheck (Deltiq-Abnahme, Block C): 2/2 reproduziert —
/// eine Uebung im Day-Editor per Swipe geloescht, die App stuerzte sofort ab.
/// Root Cause: der Re-Index-Schritt nach `modelContext.delete(...)` fragte
/// `orderedExercises` (liest `day.activeExercises` LIVE) erneut ab, statt die
/// VOR dem Loeschen erfasste Momentaufnahme zu nutzen. SwiftData aktualisiert
/// die In-Memory-Relationship nach `delete()` nicht garantiert synchron vor
/// dem `save()` — die gerade geloeschte Uebung konnte dadurch nochmal in der
/// Liste auftauchen, und das Setzen von `orderIndex` auf einem bereits zum
/// Loeschen vorgemerkten Objekt crasht den Prozess.
///
/// Testet `DayEditorView.remainingAfterDeletion(_:removing:)`, die reine
/// Index-Logik hinter dem Fix, direkt — ohne `modelContext`, da diese
/// Funktion absichtlich nur auf der uebergebenen Momentaufnahme rechnet.
@available(iOS 17.0, macOS 14.0, *)
final class DayEditorDeleteReindexTests: XCTestCase {
    @MainActor
    private func makeExercises(_ names: [String]) -> [Exercise] {
        let day = TrainingDay(name: "Tag", weekday: 2, type: .custom)
        return names.enumerated().map { i, name in
            Exercise(name: name, orderIndex: i, day: day)
        }
    }

    @MainActor
    func testRemovesOnlyTheDeletedIndexFromTheSnapshot() {
        let exercises = makeExercises(["Back Squat", "Split Squat", "Nordic Curl", "Calf Raise", "Plank"])
        let remaining = DayEditorView.remainingAfterDeletion(exercises, removing: IndexSet(integer: 2))
        XCTAssertEqual(remaining.map(\.name), ["Back Squat", "Split Squat", "Calf Raise", "Plank"],
                        "die geloeschte Uebung (Index 2) muss verschwinden, alle anderen bleiben in Reihenfolge")
    }

    @MainActor
    func testNeverReturnsTheJustDeletedExerciseEvenAsItsOwnObject() {
        let exercises = makeExercises(["A", "B", "C"])
        let deleted = exercises[1]
        let remaining = DayEditorView.remainingAfterDeletion(exercises, removing: IndexSet(integer: 1))
        XCTAssertFalse(remaining.contains(where: { $0 === deleted }),
                        "die geloeschte Instanz darf nie wieder auftauchen — genau das liess frueher orderIndex auf einem bereits geloeschten Objekt setzen und crashte")
    }

    @MainActor
    func testSupportsMultipleOffsetsInOneDelete() {
        let exercises = makeExercises(["A", "B", "C", "D"])
        let remaining = DayEditorView.remainingAfterDeletion(exercises, removing: IndexSet([0, 2]))
        XCTAssertEqual(remaining.map(\.name), ["B", "D"])
    }
}
#endif
