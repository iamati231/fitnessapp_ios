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

    // MARK: - Indirekte Verschiebung (Audit-Korrektur)

    func testMoveDayFailsWhenItWouldIndirectlyDisplaceAPositionFixedDay() {
        // A – B(fixiert) – C; A ans Ende verschieben darf B nicht indirekt
        // auf einen anderen Platz verschieben. Die GESAMTE Operation muss
        // verworfen werden, nicht nur B "gerettet" und der Rest trotzdem
        // angewendet.
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let idOfA = draft.days[0].id
        let idOfB = draft.days[1].id
        draft.setPositionFixed(true, for: idOfB)

        let moved = draft.moveDay(idOfA, toIndex: 2)

        XCTAssertFalse(moved)
        XCTAssertEqual(draft.days.map(\.name), ["A", "B", "C"], "unveraendert - auch A bleibt an Ort und Stelle")
        XCTAssertEqual(draft.index(of: idOfB), 1)
    }

    func testMoveDayFailsWhenAnEarlierDayWouldDisplaceAPositionFixedDay() {
        // Gleiche Invariante aus der anderen Richtung: C nach vorne vor B
        // verschieben wuerde B ebenso indirekt verdraengen.
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let idOfB = draft.days[1].id
        let idOfC = draft.days[2].id
        draft.setPositionFixed(true, for: idOfB)

        XCTAssertFalse(draft.moveDay(idOfC, toIndex: 0))
        XCTAssertEqual(draft.days.map(\.name), ["A", "B", "C"])
    }

    func testMoveDaySucceedsWhenItDoesNotCrossAnyPositionFixedDay() {
        // Eine Verschiebung, die vollstaendig VOR oder NACH dem fixierten Tag
        // bleibt, veraendert dessen Index nicht und muss weiterhin gelingen.
        var draft = PlanDraft(generated: [
            day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3), day("D", sequenceIndex: 4)
        ])
        let idOfB = draft.days[1].id
        let idOfD = draft.days[3].id
        draft.setPositionFixed(true, for: idOfB)

        XCTAssertTrue(draft.moveDay(idOfD, toIndex: 2))
        XCTAssertEqual(draft.days.map(\.name), ["A", "B", "D", "C"])
        XCTAssertEqual(draft.index(of: idOfB), 1, "B bleibt unberuehrt, da die Verschiebung erst NACH seiner Position stattfindet")
    }

    // MARK: - reorder(to:) — gemeinsamer Pfad fuer Drag & Drop UND Neuverteilung

    func testReorderSucceedsWhenAllPositionFixedDaysKeepTheirIndex() {
        var draft = PlanDraft(generated: [
            day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3), day("D", sequenceIndex: 4)
        ])
        let ids = draft.days.map(\.id)
        draft.setPositionFixed(true, for: ids[1])

        XCTAssertTrue(draft.reorder(to: [ids[0], ids[1], ids[3], ids[2]]))
        XCTAssertEqual(draft.days.map(\.name), ["A", "B", "D", "C"])
    }

    func testReorderFailsWhenAPositionFixedDayWouldMove() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let ids = draft.days.map(\.id)
        draft.setPositionFixed(true, for: ids[1])

        XCTAssertFalse(draft.reorder(to: [ids[1], ids[0], ids[2]]))
        XCTAssertEqual(draft.days.map(\.name), ["A", "B", "C"])
    }

    func testReorderFailsForNonPermutationInput() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        let ids = draft.days.map(\.id)

        XCTAssertFalse(draft.reorder(to: [ids[0]]), "zu kurz")
        XCTAssertFalse(draft.reorder(to: [ids[0], ids[0]]), "Duplikat statt echter Permutation")
        XCTAssertFalse(draft.reorder(to: [ids[0], DraftDayID()]), "unbekannte ID")
        XCTAssertEqual(draft.days.map(\.name), ["A", "B"], "jeder ungueltige Versuch laesst den Entwurf unveraendert")
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

    // MARK: - hasAnyFixation (#206 Bestaetigungs-Gate)

    func testHasAnyFixationIsFalseWhenNothingIsFixed() {
        let draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        XCTAssertFalse(draft.hasAnyFixation)
    }

    func testHasAnyFixationIsTrueForContentFixation() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1)])
        draft.setContentFixed(true, for: draft.days[0].id)
        XCTAssertTrue(draft.hasAnyFixation)
    }

    func testHasAnyFixationIsTrueForPositionFixation() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1)])
        draft.setPositionFixed(true, for: draft.days[0].id)
        XCTAssertTrue(draft.hasAnyFixation)
    }

    // MARK: - redistributeUnfixedDays (#205 "Woche anders verteilen")

    func testRedistributeReplacesContentOfEveryUnfixedDayInOrderWithoutChangingPositionOrID() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let ids = draft.days.map(\.id)
        let freshDays = [
            day("A2", sequenceIndex: 1, exercises: [exercise("Neu 1")]),
            day("B2", sequenceIndex: 2, exercises: [exercise("Neu 2")]),
            day("C2", sequenceIndex: 3, exercises: [exercise("Neu 3")])
        ]

        let result = draft.redistributeUnfixedDays(using: freshDays)

        XCTAssertTrue(result)
        XCTAssertEqual(draft.days.map(\.name), ["A2", "B2", "C2"])
        XCTAssertEqual(draft.days.map(\.id), ids, "stabile IDs bleiben trotz Inhaltswechsel erhalten")
    }

    func testRedistributeLeavesContentFixedDayCompletelyUntouchedButFillsOthersFromThePool() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let idOfB = draft.days[1].id
        draft.setContentFixed(true, for: idOfB)
        // Nur 2 frische Tage noetig (A und C sind nicht fixiert, B ist es).
        let freshDays = [
            day("A2", sequenceIndex: 1, exercises: [exercise("Neu 1")]),
            day("C2", sequenceIndex: 3, exercises: [exercise("Neu 2")])
        ]

        XCTAssertTrue(draft.redistributeUnfixedDays(using: freshDays))

        XCTAssertEqual(draft.days.map(\.name), ["A2", "B", "C2"], "B (content-fixiert) bleibt unveraendert, A und C bekommen den Pool der Reihe nach")
        XCTAssertEqual(draft.days[1].id, idOfB)
    }

    func testRedistributeAllowsNewContentOnAPositionFixedButNotContentFixedDay() {
        // Identische Fixierungssemantik wie replaceContent: isPositionFixed
        // allein schuetzt den INHALT nicht.
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        let idOfA = draft.days[0].id
        draft.setPositionFixed(true, for: idOfA)
        let freshDays = [
            day("A2", sequenceIndex: 1, exercises: [exercise("Neu 1")]),
            day("B2", sequenceIndex: 2, exercises: [exercise("Neu 2")])
        ]

        XCTAssertTrue(draft.redistributeUnfixedDays(using: freshDays))

        XCTAssertEqual(draft.days.map(\.name), ["A2", "B2"])
        XCTAssertEqual(draft.days[0].id, idOfA)
        XCTAssertTrue(draft.days[0].isPositionFixed, "Positions-Fixierung bleibt von einem Inhalts-Austausch unberuehrt")
    }

    func testRedistributeFailsAndLeavesDraftUnchangedWhenAllDaysAreContentFixed() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2)])
        draft.setContentFixed(true, for: draft.days[0].id)
        draft.setContentFixed(true, for: draft.days[1].id)
        let before = draft

        let result = draft.redistributeUnfixedDays(using: [day("X", sequenceIndex: 1), day("Y", sequenceIndex: 2)])

        XCTAssertFalse(result, "nichts zu verteilen ist ein sichtbarer Konflikt, kein stiller Erfolg")
        XCTAssertEqual(draft, before)
    }

    func testRedistributeFailsAndLeavesDraftUnchangedWhenNotEnoughFreshDaysAreProvided() {
        var draft = PlanDraft(generated: [day("A", sequenceIndex: 1), day("B", sequenceIndex: 2), day("C", sequenceIndex: 3)])
        let before = draft

        // Nur 1 frischer Tag fuer 3 nicht-fixierte Tage - zu wenig.
        let result = draft.redistributeUnfixedDays(using: [day("X", sequenceIndex: 1)])

        XCTAssertFalse(result)
        XCTAssertEqual(draft, before)
    }
}
