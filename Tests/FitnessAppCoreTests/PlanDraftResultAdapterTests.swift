import XCTest
@testable import FitnessAppCore

final class PlanDraftResultAdapterTests: XCTestCase {

    private func input(_ kind: TrainingTypeKind, days: Int) -> PlanGeneratorInput {
        PlanGeneratorInput(
            selections: [PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: 45, experience: .intermediate)],
            equipmentPreferences: [],
            usesFixedWeekdays: false,
            fixedWeekdays: []
        )
    }

    private func loadLevels(for draft: PlanDraft, matching generated: PlanGenerator.Result) -> [DraftDayID: PlanLoadLevel] {
        let sortedGenerated = generated.days.sorted { $0.spec.sequenceIndex < $1.spec.sequenceIndex }
        return Dictionary(uniqueKeysWithValues: zip(draft.days, sortedGenerated).map { ($0.id, $1.loadLevel) })
    }

    /// Nachbesserung (Review nach P2.4): beweist, dass `makeResult` Reorder-
    /// UND Inhalts-Aenderungen am Draft VOLLSTAENDIG in die Rekonstruktion
    /// uebernimmt - nicht nur Tagesnamen, sondern die komplette Uebungsliste
    /// jedes Tages, in der tatsaechlichen (umsortierten) Reihenfolge. Das ist
    /// genau der Pfad, den `PlanBuilderView.currentResult` produktiv nutzt.
    func testMakeResultReflectsReorderAndContentChangeCompletely() throws {
        let original = PlanGenerator.generate(from: input(.barbell, days: 3))
        XCTAssertEqual(original.days.count, 3)
        let originalDays = original.days.sorted { $0.spec.sequenceIndex < $1.spec.sequenceIndex }

        var draft = PlanDraft(generated: original.days.map(\.spec))
        let levels = loadLevels(for: draft, matching: original)
        let ids = draft.days.map(\.id)

        // Tag 1 und Tag 3 vertauschen (Tag 2 bleibt in der Mitte).
        XCTAssertTrue(draft.reorder(to: [ids[2], ids[1], ids[0]]))

        // Inhalt des (jetzt an Position 0 stehenden, urspruenglich dritten)
        // Tages komplett durch einen andersartigen Trainingstag ersetzen.
        let replacement = PlanGenerator.generate(from: input(.kettlebell, days: 1)).days[0].spec
        XCTAssertFalse(replacement.exercises.isEmpty)
        XCTAssertTrue(draft.replaceContent(of: ids[2], with: replacement))

        let reconstructed = try PlanDraftResultAdapter.makeResult(from: draft, loadLevels: levels, explanationKey: "some.key")
        let days = try XCTUnwrap(reconstructed?.days)
        XCTAssertEqual(days.count, 3)

        // Position 0: der ersetzte Tag - voller Inhalt, nicht nur der Name.
        XCTAssertEqual(days[0].spec.name, replacement.name)
        XCTAssertEqual(days[0].spec.exercises, replacement.exercises)
        XCTAssertEqual(days[0].spec.sequenceIndex, 1)

        // Position 1: unveraendert der urspruengliche zweite Tag.
        XCTAssertEqual(days[1].spec.name, originalDays[1].spec.name)
        XCTAssertEqual(days[1].spec.exercises, originalDays[1].spec.exercises)
        XCTAssertEqual(days[1].spec.sequenceIndex, 2)

        // Position 2: unveraendert der urspruengliche erste Tag (nur
        // verschoben, nicht inhaltlich veraendert).
        XCTAssertEqual(days[2].spec.name, originalDays[0].spec.name)
        XCTAssertEqual(days[2].spec.exercises, originalDays[0].spec.exercises)
        XCTAssertEqual(days[2].spec.sequenceIndex, 3)

        XCTAssertEqual(reconstructed?.explanationKey, "some.key")
    }

    /// Nachbesserung: "kein stilles .medium fuer fehlende Zuordnung" - eine
    /// unvollstaendige `loadLevels`-Map muss den Adapter sichtbar scheitern
    /// lassen, nicht mit einem erfundenen Default durchlaufen.
    func testMakeResultThrowsOnMissingLoadLevelInsteadOfDefaultingSilently() {
        let original = PlanGenerator.generate(from: input(.barbell, days: 2))
        let draft = PlanDraft(generated: original.days.map(\.spec))
        let incompleteLevels = [draft.days[0].id: PlanLoadLevel.medium]

        XCTAssertThrowsError(
            try PlanDraftResultAdapter.makeResult(from: draft, loadLevels: incompleteLevels, explanationKey: nil)
        ) { error in
            XCTAssertEqual(
                error as? PlanDraftResultAdapter.AdapterError,
                .missingLoadLevel(dayID: draft.days[1].id)
            )
        }
    }

    /// Device-Bugreport ("Übungsalternative wird nicht übernommen"): the
    /// exact end-to-end mechanism `PlanBuilderView.applyExerciseAlternative`
    /// relies on - a single `replaceExercise` call must NOT break
    /// `makeResult` for the rest of the session. The actual bug was the UI
    /// handler also removing that day's `loadLevels` entry, which made this
    /// exact call throw `missingLoadLevel` (see the test above) - swallowed
    /// silently by `PlanBuilderView.currentResult`'s `try?`, so "Plan
    /// übernehmen" did nothing. The fix keeps the day's existing loadLevel
    /// entry untouched after a single-exercise swap (a far smaller change
    /// than `replaceContent`'s whole-day swap), proven here by reconstructing
    /// successfully with an UNCHANGED loadLevels map and the swapped exercise
    /// actually present.
    func testMakeResultSucceedsAfterReplaceExerciseWithUnchangedLoadLevels() throws {
        let original = PlanGenerator.generate(from: input(.barbell, days: 2))
        var draft = PlanDraft(generated: original.days.map(\.spec))
        let levels = loadLevels(for: draft, matching: original)
        let dayID = draft.days[0].id
        let exerciseID = draft.days[0].exercises[0].id
        let otherExerciseNames = draft.days[0].exercises.dropFirst().map(\.spec.name)
        let secondDayExerciseNames = draft.days[1].exercises.map(\.spec.name)
        let replacement = ExerciseSpec(name: "Ganz Erfundene Ersatzuebung", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90)

        XCTAssertTrue(draft.replaceExercise(dayID: dayID, exerciseID: exerciseID, with: replacement))

        // Bugfix-Beweis: KEINE Entfernung aus `levels` (anders als der
        // frühere, fehlerhafte `applyExerciseAlternative`-Code) - die Map
        // bleibt exakt die urspruengliche.
        let reconstructed = try PlanDraftResultAdapter.makeResult(from: draft, loadLevels: levels, explanationKey: nil)
        let days = try XCTUnwrap(reconstructed?.days)

        XCTAssertEqual(days.count, 2, "beide Tage muessen weiterhin rekonstruierbar sein, nicht nur der unveraenderte")
        XCTAssertTrue(days[0].spec.exercises.map(\.name).contains("Ganz Erfundene Ersatzuebung"), "die ausgetauschte Uebung muss im rekonstruierten Ergebnis stehen")
        XCTAssertEqual(
            Set(days[0].spec.exercises.dropFirst().map(\.name)), Set(otherExerciseNames),
            "alle anderen Uebungen desselben Tages bleiben unveraendert"
        )
        XCTAssertEqual(
            days[1].spec.exercises.map(\.name), secondDayExerciseNames,
            "der andere Tag bleibt vollstaendig unberuehrt"
        )
    }

    func testMakeResultReturnsNilForEmptyDraft() throws {
        let draft = PlanDraft(days: [])
        let result = try PlanDraftResultAdapter.makeResult(from: draft, loadLevels: [:], explanationKey: nil)
        XCTAssertNil(result)
    }

    /// Reine Umsortierung ohne Inhaltsaenderung darf keine `loadLevel`-
    /// Zuordnung "verlieren" - die Map ist ueber `DraftDayID` indiziert,
    /// nicht ueber Position.
    func testReorderAloneKeepsAllLoadLevelsResolvable() throws {
        let original = PlanGenerator.generate(from: input(.dumbbell, days: 4))
        var draft = PlanDraft(generated: original.days.map(\.spec))
        let levels = loadLevels(for: draft, matching: original)
        let ids = draft.days.map(\.id)

        XCTAssertTrue(draft.moveDay(ids[0], toIndex: 3))

        let reconstructed = try PlanDraftResultAdapter.makeResult(from: draft, loadLevels: levels, explanationKey: nil)
        XCTAssertEqual(reconstructed?.days.count, 4)
    }
}
