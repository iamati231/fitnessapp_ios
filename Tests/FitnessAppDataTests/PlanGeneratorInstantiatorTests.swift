#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Integration tests for `PlanGeneratorInstantiator` (README 2.20 "Plan
/// bauen") against a real in-memory `ModelContainer`. `build`/`recalculate`
/// mutate a live SwiftData object graph and are order/identity-sensitive —
/// pure generator logic (day content, ordering, load levels) is covered by
/// `PlanGeneratorTests` in FitnessAppCoreTests; these tests only verify the
/// SwiftData boundary: fingerprinting, stable day identity across edits, and
/// archived-exercise preservation.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanGeneratorInstantiatorTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }

    private func selection(
        _ kind: TrainingTypeKind,
        days: Int,
        minutes: Int = 45,
        experience: DifficultyLevel = .intermediate
    ) -> PlanGeneratorTypeSelection {
        PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: minutes, experience: experience)
    }

    private func input(_ selections: [PlanGeneratorTypeSelection]) -> PlanGeneratorInput {
        PlanGeneratorInput(selections: selections, equipmentPreferences: [], usesFixedWeekdays: false)
    }

    // MARK: - build()

    func testBuildStampsFingerprintAndSequenceIndexOnEveryWorkoutDay() throws {
        let plan = try XCTUnwrap(PlanGeneratorInstantiator.build(from: input([selection(.barbell, days: 3)]), in: context))
        let workoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(workoutDays.count, 3)
        for day in workoutDays {
            XCTAssertNotNil(day.generationFingerprint)
            XCTAssertNotNil(day.generatorSequenceIndex)
            XCTAssertEqual(day.generationFingerprint, day.currentContentFingerprint)
        }
        let sequenceIndices = Set(workoutDays.compactMap(\.generatorSequenceIndex))
        XCTAssertEqual(sequenceIndices, [1, 2, 3], "jeder Tag muss einen eigenen, eindeutigen sequenceIndex bekommen")
    }

    func testBuildReturnsNilWhenGeneratorProducesNoDays() {
        // Kein Selections-Eintrag -> PlanGenerator.generate liefert leer.
        XCTAssertNil(PlanGeneratorInstantiator.build(from: input([]), in: context))
    }

    // MARK: - recalculate() Grundfaelle

    func testRecalculateIsNoOpForPlansWithoutGeneratorInput() {
        let plan = TrainingPlan(name: "Custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        XCTAssertEqual(PlanGeneratorInstantiator.recalculate(plan, in: context), 0)
    }

    func testRecalculateSkipsDayWithEditedExerciseSets() throws {
        let plan = try XCTUnwrap(PlanGeneratorInstantiator.build(from: input([selection(.barbell, days: 2)]), in: context))
        let workoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(workoutDays.count, 2)
        let editedDay = try XCTUnwrap(workoutDays.first)
        let originalExerciseCount = editedDay.activeExercises.count
        // Simuliert eine User-Aenderung ueber ExerciseEditorView.
        editedDay.activeExercises.first?.sets += 1

        let rewritten = PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(rewritten, 1, "nur der unangetastete zweite Tag darf neu geschrieben werden")
        XCTAssertEqual(editedDay.activeExercises.count, originalExerciseCount, "editierter Tag bleibt inhaltlich stehen")
    }

    // MARK: - README-2.20-Review-Fund: stabile Tag-Identitaet

    /// Regression: eine fruehere Fassung von `recalculate` matchte generierte
    /// gegen bestehende Tage rein ueber die Position in einer Montag-first-
    /// sortierten "nur Trainingstage"-Liste. Sobald ein Tag ueber
    /// `DayEditorView` zum Ruhetag gemacht (oder auf einen anderen Wochentag
    /// verschoben) wird, verschiebt das die Position JEDES NACHFOLGENDEN
    /// Tages in dieser Liste - die nachfolgenden, eigentlich unangetasteten
    /// Tage bekamen dadurch den Inhalt eines JEWEILS ANDEREN Tages
    /// zugeschrieben. `generatorSequenceIndex` macht das Matching stabil.
    func testRecalculatePreservesCorrectContentAfterEarlierDayBecomesRest() throws {
        // Drei STRUKTURELL verschiedene Trainingsarten, damit sich vertauschter
        // Inhalt zwischen Tagen zweifelsfrei nachweisen laesst.
        let mixedInput = input([
            selection(.kettlebell, days: 1),
            selection(.running, days: 1),
            selection(.cycling, days: 1)
        ])
        let plan = try XCTUnwrap(PlanGeneratorInstantiator.build(from: mixedInput, in: context))
        let workoutDaysBefore = PlanNavigator.sortByWeekdayMondayFirst(plan.days.filter { $0.type != .rest })
        XCTAssertEqual(workoutDaysBefore.count, 3)

        let nameBySequenceIndex = try Dictionary(
            uniqueKeysWithValues: workoutDaysBefore.map { (try XCTUnwrap($0.generatorSequenceIndex), $0.name) }
        )
        XCTAssertEqual(Set(nameBySequenceIndex.values).count, 3, "die drei Trainingsarten muessen unterscheidbare Tages-Namen erzeugen")

        // User macht den ERSTEN (Montag-first) Tag zum Ruhetag.
        let editedDay = workoutDaysBefore[0]
        editedDay.type = .rest

        let rewritten = PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(rewritten, 2)

        // Der bearbeitete Tag bleibt Ruhetag - sein Fingerprint (jetzt inkl.
        // `type`) passt nicht mehr, "neu rechnen" darf ihn nicht anfassen.
        XCTAssertEqual(editedDay.type, .rest)

        // Jeder VERBLEIBENDE Trainingstag muss GENAU seinen eigenen,
        // urspruenglichen Inhalt zurueckbekommen - nicht den eines
        // benachbarten Tages.
        for day in workoutDaysBefore.dropFirst() {
            let sequenceIndex = try XCTUnwrap(day.generatorSequenceIndex)
            XCTAssertEqual(day.name, nameBySequenceIndex[sequenceIndex],
                            "Tag mit sequenceIndex \(sequenceIndex) hat den falschen Inhalt bekommen")
        }
    }

    // MARK: - README-2.20-Review-Fund: archivierte Uebungen ueberleben

    /// Regression: eine fruehere Fassung von `apply()` loeschte VOR dem
    /// Neu-Erzeugen die komplette `exercises`-Relationship (aktiv +
    /// archiviert) statt nur `activeExercises`. Das reisst jedes archivierte
    /// Original mit, auf das `PlanEnvironmentMigrator.restoreOriginals` beim
    /// Verlassen des Urlaubs-Modus angewiesen ist.
    ///
    /// Testet gezielt NUR `apply()`s Loesch-Verhalten, nicht das reale
    /// Zusammenspiel mit `PlanEnvironmentMigrator` (dessen genaue Swap-/
    /// Restore-Mechanik ist nicht Gegenstand dieser Datei): der Fingerprint
    /// wird nach dem Archivieren bewusst manuell neu gesetzt, um genau den
    /// Zustand herzustellen, in dem `recalculate` den Tag als unangetastet
    /// einstuft und `apply()` tatsaechlich aufruft.
    func testApplyPreservesArchivedExercisesWhenOverwritingAnUntouchedDay() throws {
        let plan = try XCTUnwrap(PlanGeneratorInstantiator.build(from: input([selection(.barbell, days: 1)]), in: context))
        let day = try XCTUnwrap(plan.days.first { $0.type != .rest })

        let archived = try XCTUnwrap(day.activeExercises.first)
        archived.isArchived = true
        day.generationFingerprint = day.currentContentFingerprint

        let rewritten = PlanGeneratorInstantiator.recalculate(plan, in: context)
        XCTAssertEqual(rewritten, 1)
        XCTAssertTrue(day.archivedExercises.contains(where: { $0 === archived }),
                       "archivierte Uebung darf beim Neu-Rechnen nicht verloren gehen")
    }
}
#endif
