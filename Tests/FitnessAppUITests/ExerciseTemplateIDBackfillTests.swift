#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppUI

/// Settings-Epic Phase 6 (EXLIB-07/09): `ExerciseTemplateIDBackfill` lebt in
/// `FitnessAppUI` (gleicher Ort wie das Vorbild `ExerciseNameBackfill`,
/// gleicher Aufruf-Ort `RootView`), deshalb liegt dieser Test hier und nicht
/// in `FitnessAppDataTests` — er braucht beide Module.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExerciseTemplateIDBackfillTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Kernvertrag der Migration: eindeutiger Namens-Treffer wird verknüpft,
    /// ein mehrdeutiger (zwei Vorlagen teilen denselben Namen) wird bewusst
    /// NICHT geraten, und ein Eintrag ganz ohne Treffer bleibt unangetastet.
    /// Zweiter Lauf findet nichts mehr (Idempotenz).
    func testBackfillConnectsOnlyUniqueNameMatches() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let unique = ExerciseTemplate(name: "Kreuzheben", equipment: .barbell, primaryMuscle: .back)
        ctx.insert(unique)
        let ambiguousA = ExerciseTemplate(name: "Rudern", equipment: .cable, primaryMuscle: .back, isCustom: true)
        let ambiguousB = ExerciseTemplate(name: "Rudern", equipment: .dumbbell, primaryMuscle: .back, isCustom: true)
        ctx.insert(ambiguousA)
        ctx.insert(ambiguousB)

        // Alt-Zeilen wie vor Phase 6: `name`/Snapshot gesetzt, ID noch nil.
        let exerciseUnique = Exercise(name: "Kreuzheben", sets: 3)
        ctx.insert(exerciseUnique)
        let exerciseAmbiguous = Exercise(name: "Rudern", sets: 3)
        ctx.insert(exerciseAmbiguous)
        let exerciseOrphan = Exercise(name: "Laengst Verschwunden", sets: 3)
        ctx.insert(exerciseOrphan)

        let logUnique = ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: exerciseUnique)
        ctx.insert(logUnique)

        let prAmbiguous = PersonalRecordEntry(
            date: Date(), exerciseName: "Rudern",
            kindRaw: PersonalRecord.Kind.heaviestWeight.rawValue,
            value: 50, previousValue: 45, weightKg: 50, reps: 8
        )
        ctx.insert(prAmbiguous)
        try ctx.save()

        XCTAssertNil(exerciseUnique.exerciseTemplateID)
        XCTAssertNil(exerciseAmbiguous.exerciseTemplateID)
        XCTAssertNil(exerciseOrphan.exerciseTemplateID)
        XCTAssertNil(logUnique.exerciseTemplateIDSnapshot)
        XCTAssertNil(prAmbiguous.exerciseTemplateID)

        let fixedFirstRun = ExerciseTemplateIDBackfill.runIfNeeded(in: ctx)

        XCTAssertEqual(exerciseUnique.exerciseTemplateID, unique.id, "Eindeutiger Namens-Treffer muss verknüpft werden")
        XCTAssertEqual(logUnique.exerciseTemplateIDSnapshot, unique.id, "Log-Snapshot folgt demselben eindeutigen Treffer")
        XCTAssertNil(exerciseAmbiguous.exerciseTemplateID, "Mehrdeutiger Namens-Treffer darf NICHT geraten werden")
        XCTAssertNil(prAmbiguous.exerciseTemplateID, "Mehrdeutiger Namens-Treffer darf auch bei PRs NICHT geraten werden")
        XCTAssertNil(exerciseOrphan.exerciseTemplateID, "Ohne jeden Namens-Treffer bleibt es nil")
        XCTAssertGreaterThan(fixedFirstRun, 0)

        let fixedSecondRun = ExerciseTemplateIDBackfill.runIfNeeded(in: ctx)
        XCTAssertEqual(fixedSecondRun, 0, "Zweiter Lauf muss idempotent nichts mehr finden")
    }

    /// System-Übungen sind read-only (nie umbenennbar) — ihr Name ist laut
    /// Bibliotheks-Katalog kollisionsfrei, der Backfill muss sie deshalb
    /// IMMER eindeutig verknüpfen können, nie als "mehrdeutig" einstufen.
    func testBackfillConnectsSystemExerciseByName() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let system = ExerciseTemplate(
            name: "Bankdruecken", equipment: .barbell, primaryMuscle: .chest,
            isCustom: false, isSystemCompound: true
        )
        ctx.insert(system)
        let exercise = Exercise(name: "Bankdruecken", sets: 3)
        ctx.insert(exercise)
        try ctx.save()

        ExerciseTemplateIDBackfill.runIfNeeded(in: ctx)

        XCTAssertEqual(exercise.exerciseTemplateID, system.id)
    }

    // MARK: - Bugfix (Geraetetest): repairDuplicateTemplateIDsIfNeeded

    /// Absicherung gegen ein (aus dieser Session heraus nicht an echtem
    /// Apple-SwiftData verifizierbares, aber von Entwicklern berichtetes)
    /// Lightweight-Migrations-Risiko: zwei VERSCHIEDENE Vorlagen mit
    /// zufaellig derselben `id` (hier direkt erzwungen, da auf dem
    /// In-Memory-Store ueber `ExerciseTemplate.init` nie zwei echte
    /// Zufalls-UUIDs kollidieren) muessen nach dem Reparatur-Lauf
    /// unterschiedliche IDs tragen.
    func testRepairDuplicateTemplateIDsAssignsFreshIDToCollidingTemplate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let sharedID = UUID()
        let first = ExerciseTemplate(id: sharedID, name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest)
        let second = ExerciseTemplate(id: sharedID, name: "Kniebeuge", equipment: .barbell, primaryMuscle: .quads)
        ctx.insert(first)
        ctx.insert(second)
        try ctx.save()

        let repaired = ExerciseTemplateIDBackfill.repairDuplicateTemplateIDsIfNeeded(in: ctx)

        XCTAssertEqual(repaired, 1, "von zwei kollidierenden Vorlagen behaelt genau eine ihre ID")
        XCTAssertNotEqual(first.id, second.id)
    }

    func testRepairDuplicateTemplateIDsIsIdempotent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let sharedID = UUID()
        ctx.insert(ExerciseTemplate(id: sharedID, name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest))
        ctx.insert(ExerciseTemplate(id: sharedID, name: "Kniebeuge", equipment: .barbell, primaryMuscle: .quads))
        try ctx.save()

        _ = ExerciseTemplateIDBackfill.repairDuplicateTemplateIDsIfNeeded(in: ctx)
        let secondPass = ExerciseTemplateIDBackfill.repairDuplicateTemplateIDsIfNeeded(in: ctx)

        XCTAssertEqual(secondPass, 0, "zweiter Lauf findet keine Kollision mehr")
    }

    /// Konsistenz-Check in `runIfNeeded`: eine bereits gesetzte
    /// `exerciseTemplateID`, die zu KEINER Vorlage mit demselben Namen mehr
    /// passt (z.B. weil `LibrarySeeder.deduplicateTemplatesIfNeeded` genau
    /// die Vorlage geloescht hat, auf die diese ID zeigte), muss
    /// zurueckgesetzt und ueber den normalen eindeutigen Namens-Treffer neu
    /// aufgeloest werden — nicht dauerhaft auf einer ins Leere zeigenden ID
    /// stehen bleiben.
    func testRunIfNeededHealsExerciseWithStaleTemplateIDPointingToDeletedDuplicate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let staleID = UUID()
        let survivor = ExerciseTemplate(name: "Bankdrücken", equipment: .barbell, primaryMuscle: .chest, isCustom: true)
        ctx.insert(survivor)
        // Simuliert: die Exercise zeigte urspruenglich auf ein Duplikat, das
        // inzwischen geloescht wurde — `staleID` existiert auf keiner
        // aktuellen Vorlage mehr.
        let exercise = Exercise(name: "Bankdrücken", exerciseTemplateID: staleID, sets: 3)
        ctx.insert(exercise)
        try ctx.save()
        XCTAssertNotEqual(exercise.exerciseTemplateID, survivor.id)

        ExerciseTemplateIDBackfill.runIfNeeded(in: ctx)

        XCTAssertEqual(exercise.exerciseTemplateID, survivor.id, "stale ID muss durch den eindeutigen Namens-Treffer ersetzt werden")
    }
}
#endif
