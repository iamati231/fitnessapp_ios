#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UIKit)
import XCTest
import SwiftData
import DeltiqData
@testable import DeltiqUI

/// Audit-Fund Modul 21: `toggleSupersetWithPrevious(at:)` trennte beim Unlink
/// eines mittleren Mitglieds eines 3er-Supersets (A-B-C) nur, wenn insgesamt
/// `remaining.count <= 1` war — nicht, ob die verbleibenden Mitglieder noch
/// benachbart sind. Trennt man B, bleiben A und C (count 2, nicht <= 1) mit
/// derselben `supersetId` verbunden, obwohl sie nicht mehr nebeneinander
/// liegen — die Klammer wirkt optisch unterbrochen.
///
/// Testet `DayEditorView.exercisesToUnlinkAfterSupersetSplit(_:groupID:)`,
/// die reine Index-Logik hinter dem Fix, direkt — gleiches Muster wie
/// `DayEditorDeleteReindexTests`/`remainingAfterDeletion`.
@available(iOS 17.0, macOS 14.0, *)
final class DayEditorSupersetUnlinkContiguityTests: XCTestCase {
    @MainActor
    private func makeExercises(_ names: [String], supersetId: UUID?) -> [Exercise] {
        let day = TrainingDay(name: "Tag", weekday: 2, type: .custom)
        return names.enumerated().map { i, name in
            let exercise = Exercise(name: name, orderIndex: i, day: day)
            exercise.supersetId = supersetId
            return exercise
        }
    }

    @MainActor
    func testUnlinkingTheMiddleOfThreeClearsBothRemainingNonAdjacentMembers() {
        let groupID = UUID()
        let exercises = makeExercises(["A", "B", "C"], supersetId: groupID)
        // B wurde bereits getrennt (supersetId = nil), bevor die Funktion
        // gerufen wird — genau wie im Aufrufer `toggleSupersetWithPrevious`.
        exercises[1].supersetId = nil

        let toUnlink = DayEditorView.exercisesToUnlinkAfterSupersetSplit(exercises, groupID: groupID)

        XCTAssertEqual(Set(toUnlink.map(\.name)), ["A", "C"],
                        "A und C sind nach dem Trennen von B nicht mehr benachbart und muessen beide entkoppelt werden, auch wenn insgesamt noch 2 Mitglieder uebrig sind")
    }

    @MainActor
    func testUnlinkingAnEndOfThreeKeepsTheStillAdjacentPairLinked() {
        let groupID = UUID()
        let exercises = makeExercises(["A", "B", "C"], supersetId: groupID)
        exercises[0].supersetId = nil

        let toUnlink = DayEditorView.exercisesToUnlinkAfterSupersetSplit(exercises, groupID: groupID)

        XCTAssertTrue(toUnlink.isEmpty,
                       "B und C bleiben benachbart und sollen verbunden bleiben, wenn nur das aeussere Element A getrennt wird")
    }

    @MainActor
    func testUnlinkingDownToOneRemainingMemberClearsIt() {
        let groupID = UUID()
        let exercises = makeExercises(["A", "B"], supersetId: groupID)
        exercises[0].supersetId = nil

        let toUnlink = DayEditorView.exercisesToUnlinkAfterSupersetSplit(exercises, groupID: groupID)

        XCTAssertEqual(toUnlink.map(\.name), ["B"],
                        "ein 'Superset of 1' macht keinen Sinn und muss ebenfalls entkoppelt werden")
    }
}
#endif
