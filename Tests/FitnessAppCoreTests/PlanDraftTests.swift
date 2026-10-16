import XCTest
@testable import FitnessAppCore

/// Planung-&-Trainingsbegleitung-Epic, P2.0: `PlanDraft`/`DraftDay` — die
/// neue "Entwurf"-Schicht mit stabilen Identitaeten statt volatiler Indizes
/// (docs/PLANUNG_BEGLEITUNG_AUDIT.md, Abschnitt "P2.0 ... PlanDraft ist
/// bewusst NICHT TrainingDay").
final class PlanDraftTests: XCTestCase {

    private func exercise(_ name: String) -> ExerciseSpec {
        ExerciseSpec(name: name, sets: 3, repsMin: 8, repsMax: 12)
    }

    private func day(_ name: String, sequenceIndex: Int, type: DayType = .push, exercises: [ExerciseSpec]? = nil) -> DaySpec {
        DaySpec(
            name: name,
            type: type,
            sequenceIndex: sequenceIndex,
            exercises: exercises ?? [exercise("\(name) Uebung 1")]
        )
    }

    // MARK: - init(generated:)

    func testInitGeneratedSortsBySequenceIndexAndAssignsStableIDs() {
        let draft = PlanDraft(generated: [day("Pull A", sequenceIndex: 2), day("Push A", sequenceIndex: 1)])
        XCTAssertEqual(draft.days.map(\.name), ["Push A", "Pull A"])
        XCTAssertEqual(Set(draft.days.map(\.id)).count, 2, "jeder Tag muss eine eigene, eindeutige ID bekommen")
    }

    func testInitGeneratedPreservesExerciseContent() {
        let specs = [exercise("Bankdruecken"), exercise("Rudern")]
        let draft = PlanDraft(generated: [day("Push A", sequenceIndex: 1, exercises: specs)])
        XCTAssertEqual(draft.days[0].exercises.map(\.spec), specs)
        XCTAssertEqual(Set(draft.days[0].exercises.map(\.id)).count, 2, "jede Uebung muss eine eigene, eindeutige ID bekommen")
    }

    // MARK: - resolvedDaySpecs

    func testResolvedDaySpecsRenumbersSequenceIndexFromCurrentArrayPosition() {
        // Bewusst mit "falschen" Original-sequenceIndex-Werten (5, 9) -
        // die Projektion darf sich NICHT auf den urspruenglichen Wert
        // verlassen, nur auf die aktuelle Array-Position (1-basiert).
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 5), day("B", sequenceIndex: 9)])
        XCTAssertEqual(draft.resolvedDaySpecs.map(\.sequenceIndex), [1, 2])

        draft.days.swapAt(0, 1)
        XCTAssertEqual(draft.resolvedDaySpecs.map(\.name), ["B", "A"])
        XCTAssertEqual(draft.resolvedDaySpecs.map(\.sequenceIndex), [1, 2])
    }

    func testResolvedDaySpecsPreservesAllContentFields() {
        let draft = PlanDraft(generated: [
            DaySpec(
                name: "Zirkel", localizationKey: "plan.day.circuit", type: .fullBody, sequenceIndex: 1,
                exercises: [exercise("Kettlebell Swing")], timeFormat: .circuit, timeCapMinutes: 20,
                circuitRounds: 5, circuitRestSeconds: 90, circuitMode: .toFailure
            )
        ])
        let resolved = draft.resolvedDaySpecs[0]
        XCTAssertEqual(resolved.name, "Zirkel")
        XCTAssertEqual(resolved.localizationKey, "plan.day.circuit")
        XCTAssertEqual(resolved.type, .fullBody)
        XCTAssertEqual(resolved.timeFormat, .circuit)
        XCTAssertEqual(resolved.timeCapMinutes, 20)
        XCTAssertEqual(resolved.circuitRounds, 5)
        XCTAssertEqual(resolved.circuitRestSeconds, 90)
        XCTAssertEqual(resolved.circuitMode, .toFailure)
    }

    // MARK: - moveDay (Reorder)

    func testMoveDayReordersAndPreservesStableID() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let idOfA = draft.days[0].id

        let moved = draft.moveDay(idOfA, toIndex: 2)

        XCTAssertTrue(moved)
        XCTAssertEqual(draft.days.map(\.name), ["B", "C", "A"])
        XCTAssertEqual(draft.days.last?.id, idOfA, "die ID begleitet den Tag, nicht die urspruengliche Position")
    }

    func testMoveDayClampsOutOfRangeIndices() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        let idOfA = draft.days[0].id

        XCTAssertTrue(draft.moveDay(idOfA, toIndex: 999))
        XCTAssertEqual(draft.days.map(\.name), ["B", "A"])
    }

    func testMoveDayFailsForPositionFixedDay() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        let idOfA = draft.days[0].id
        draft.setPositionFixed(true, for: idOfA)

        let moved = draft.moveDay(idOfA, toIndex: 1)

        XCTAssertFalse(moved)
        XCTAssertEqual(draft.days.map(\.name), ["A", "B"], "Entwurf bleibt bei einer abgelehnten Verschiebung unveraendert")
    }

    func testMoveDayFailsForUnknownID() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1)])
        XCTAssertFalse(draft.moveDay(DraftDayID(), toIndex: 0))
    }

    // MARK: - replaceContent (gezielte Alternative)

    func testReplaceContentSwapsExercisesButKeepsIDAndFlags() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1)])
        let idOfA = draft.days[0].id
        draft.setPositionFixed(true, for: idOfA)
        let alternative = day("A (Alternative)", sequenceIndex: 1, exercises: [exercise("Kreuzheben")])

        let replaced = draft.replaceContent(of: idOfA, with: alternative)

        XCTAssertTrue(replaced)
        XCTAssertEqual(draft.days[0].id, idOfA)
        XCTAssertEqual(draft.days[0].name, "A (Alternative)")
        XCTAssertEqual(draft.days[0].exercises.map(\.spec.name), ["Kreuzheben"])
        XCTAssertTrue(draft.days[0].isPositionFixed, "Positions-Fixierung bleibt von einem Inhalts-Austausch unberuehrt")
    }

    func testReplaceContentFailsForContentFixedDay() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1)])
        let idOfA = draft.days[0].id
        draft.setContentFixed(true, for: idOfA)
        let originalExerciseNames = draft.days[0].exercises.map(\.spec.name)

        let replaced = draft.replaceContent(of: idOfA, with: day("A (Alternative)", sequenceIndex: 1, exercises: [exercise("Kreuzheben")]))

        XCTAssertFalse(replaced)
        XCTAssertEqual(draft.days[0].exercises.map(\.spec.name), originalExerciseNames)
    }

    // MARK: - Fixierungen sind unabhaengig voneinander

    func testContentFixationDoesNotPreventReordering() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        let idOfA = draft.days[0].id
        draft.setContentFixed(true, for: idOfA)

        XCTAssertTrue(draft.moveDay(idOfA, toIndex: 1))
        XCTAssertEqual(draft.days.map(\.name), ["B", "A"])
    }

    func testPositionFixationDoesNotPreventContentReplacement() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1)])
        let idOfA = draft.days[0].id
        draft.setPositionFixed(true, for: idOfA)

        XCTAssertTrue(draft.replaceContent(of: idOfA, with: day("A (Alternative)", sequenceIndex: 1)))
    }
}
