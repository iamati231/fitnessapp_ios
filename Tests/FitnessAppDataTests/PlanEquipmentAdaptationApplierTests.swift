#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P5.1 (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md): beweist END-TO-END (echter
/// `ModelContext`), dass `PlanEquipmentAdaptationApplier` dieselbe
/// `PlanEquipmentChecker`/`ExerciseSubstitutionEngine`-Logik, die
/// `TemplatePreviewView` bereits VOR der Instanziierung nutzt, jetzt auch auf
/// einen bereits existierenden, live gespeicherten `TrainingPlan` anwenden
/// kann — die Luecke, die P5.1 schliesst (vorher gab es dafuer ueberhaupt
/// keinen Pfad, siehe Datei-Dokumentation des Typs).
///
/// Linux-Hinweis: wie jeder `FitnessAppDataTests`-Test (SwiftData) in diesem
/// Projekt nur kompiliert, nicht lokal ausgefuehrt — laeuft auf dem naechsten
/// Codemagic-Build (macOS).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanEquipmentAdaptationApplierTests: XCTestCase {

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

    @discardableResult
    private func makePlan(exercises: [(name: String, repsMax: Int)]) -> TrainingPlan {
        let plan = TrainingPlan(name: "Test", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .legs, plan: plan)
        day.generatorSequenceIndex = 1
        context.insert(day)
        for (index, item) in exercises.enumerated() {
            let exercise = Exercise(
                name: item.name, sets: 3, repsMin: 8, repsMax: item.repsMax,
                restSeconds: 90, orderIndex: index, day: day
            )
            context.insert(exercise)
        }
        return plan
    }

    private var kettlebellOnlyProfile: UserEquipmentProfile {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()
        return profile
    }

    // MARK: - check(plan:against:)

    func testCheckReturnsAvailableWhenProfileSupportsEveryExercise() {
        let plan = makePlan(exercises: [(name: "Goblet Squat", repsMax: 12)])
        let status = PlanEquipmentAdaptationApplier.check(plan: plan, against: kettlebellOnlyProfile)
        XCTAssertTrue(status.isAvailable)
    }

    func testCheckReturnsUnavailableWhenAnExerciseIsMissingRequiredEquipment() {
        let plan = makePlan(exercises: [(name: "Kniebeuge", repsMax: 12)])
        let status = PlanEquipmentAdaptationApplier.check(plan: plan, against: kettlebellOnlyProfile)
        XCTAssertTrue(status.isUnavailable)
    }

    // MARK: - preview(...) + apply(...)

    /// Kernfall: "Kniebeuge" (Langhantel) passt nicht zum Kettlebell-only-
    /// Profil, hat aber eine reviewte Regel ("Kniebeuge" -> "Goblet Squat" bei
    /// Nicht-Kraft-Ziel + repsMax >= 10) — `apply` muss sie TATSAECHLICH im
    /// `ModelContext` archivieren + ersetzen, nicht nur in einer Vorschau.
    func testApplyArchivesTheOriginalAndInsertsAReviewedReplacement() throws {
        let plan = makePlan(exercises: [(name: "Kniebeuge", repsMax: 12)])
        let profile = kettlebellOnlyProfile
        let context_ = SubstitutionContext(goal: .hypertrophy, experienceTrack: nil)

        let draft = PlanEquipmentAdaptationApplier.preview(plan: plan, against: profile, context: context_)
        XCTAssertFalse(draft.replacements.isEmpty, "Vorbedingung: die Regel muss hier tatsaechlich greifen")

        let applied = PlanEquipmentAdaptationApplier.apply(plan: plan, draft: draft, modelContext: context)
        XCTAssertEqual(applied, 1)

        let day = try XCTUnwrap(plan.days.first)
        let original = try XCTUnwrap(day.exercises.first { $0.name == "Kniebeuge" })
        XCTAssertTrue(original.isArchived, "Original darf NICHT geloescht, nur archiviert werden (Historie bleibt dran)")

        let replacement = try XCTUnwrap(day.activeExercises.first { $0.name == "Goblet Squat" })
        XCTAssertTrue(replacement.swappedFromOriginal === original)
        XCTAssertEqual(replacement.orderIndex, original.orderIndex, "Anzeige-Reihenfolge muss erhalten bleiben")
        XCTAssertEqual(day.activeExercises.count, 1, "Die archivierte Original-Uebung darf nicht mehr als aktiv zaehlen")
    }

    /// P3.3-Prinzip ("Vorschau und Instanziierung duerfen nie auseinander-
    /// laufen") uebertragen auf P5.1: `apply` darf AUSSCHLIESSLICH die in
    /// `draft.replacements` benannten Slots anfassen — jede andere Uebung
    /// (inkl. einer bereits individuell editierten) bleibt exakt dasselbe
    /// Objekt.
    func testApplyLeavesUnrelatedExercisesUntouched() throws {
        let plan = makePlan(exercises: [
            (name: "Kniebeuge", repsMax: 12),
            (name: "Goblet Squat", repsMax: 12)
        ])
        let profile = kettlebellOnlyProfile
        let context_ = SubstitutionContext(goal: .hypertrophy, experienceTrack: nil)

        let day = try XCTUnwrap(plan.days.first)
        let untouchedOriginal = try XCTUnwrap(day.exercises.first { $0.name == "Goblet Squat" })

        let draft = PlanEquipmentAdaptationApplier.preview(plan: plan, against: profile, context: context_)
        PlanEquipmentAdaptationApplier.apply(plan: plan, draft: draft, modelContext: context)

        let stillThere = try XCTUnwrap(day.activeExercises.first { $0.name == "Goblet Squat" && $0.persistentModelID == untouchedOriginal.persistentModelID })
        XCTAssertFalse(stillThere.isArchived)
        XCTAssertNil(stillThere.swappedFromOriginal, "Die bereits kompatible Uebung darf nie als 'ersetzt' markiert werden")
    }

    func testApplyDoesNothingWhenEverythingIsAlreadyAvailable() throws {
        let plan = makePlan(exercises: [(name: "Goblet Squat", repsMax: 12)])
        let profile = kettlebellOnlyProfile
        let context_ = SubstitutionContext(goal: .hypertrophy, experienceTrack: nil)

        let draft = PlanEquipmentAdaptationApplier.preview(plan: plan, against: profile, context: context_)
        XCTAssertTrue(draft.replacements.isEmpty)

        let applied = PlanEquipmentAdaptationApplier.apply(plan: plan, draft: draft, modelContext: context)
        XCTAssertEqual(applied, 0)

        let day = try XCTUnwrap(plan.days.first)
        XCTAssertEqual(day.exercises.count, 1, "Keine neue Uebung darf ohne echten Replacement-Eintrag entstehen")
    }
}
#endif
