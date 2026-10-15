#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// UI-Refactor (Korrektur, Punkt 5): gezielte Tests fuer die Capture/Apply/
/// Equatable-Vertraege der vier Editor-Snapshot-Structs (`ExerciseSnapshot`,
/// `TrainingDaySnapshot`, `PlanMetaSnapshot`, `ProfileMetaSnapshot`) — der
/// Kern der neuen Discard-Logik. Diese Structs sind `internal` (nicht
/// `public`), deshalb `@testable import FitnessAppUI`.
///
/// Diese Datei ist wie ihre Produktionsdateien `#if canImport(SwiftUI) &&
/// canImport(SwiftData)`-gegated und existiert auf Linux schlicht nicht
/// (die Bedingung ist dort `false`) — sie kompiliert und laeuft NUR auf
/// einem Apple-Runner (z.B. dem macOS-CI-Runner, der dieses Package schon
/// heute baut, siehe Kommentare in DayEditorView.swift/PlanEditorView.swift
/// zu `Mindestversion macOS 14`). Linux-`swift test` ist fuer diese Datei
/// keine Verifikation — das gilt fuer alle SwiftUI-gegateten Dateien dieses
/// Pakets, nicht nur fuer diese.
///
/// Was hier NICHT getestet wird (braucht einen echten View-/UI-Test-
/// Harness, den dieses Repo nicht hat): die View-seitige Verdrahtung
/// (DeltiqHeader-Chevron/Checkmark, Discard-Dialog, `.onChange`-
/// Unterdrueckung waehrend eines Reverts, `.interactiveDismissDisabled`/
/// `.deltiqSwipeBackEnabled`) sowie die Cross-Entity-Seiteneffekte, die
/// NICHT im Snapshot-Struct selbst liegen (Custom-Template-Ruecksync in
/// `ExerciseEditorView.revertToSnapshot()`, Reaktivierung des anderen Plans
/// in `PlanEditorView.revertToSnapshot()`). Diese bleiben nur per echtem
/// Geraete-/Simulator-Test verifizierbar.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class EditorDiscardSnapshotTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - ExerciseSnapshot

    func testExerciseSnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let exercise = Exercise(name: "Bankdrücken", sets: 4, repsMin: 6, repsMax: 10, notes: "locker")
        ctx.insert(exercise)

        let snapshot = ExerciseSnapshot.capture(from: exercise)
        snapshot.apply(to: exercise)

        XCTAssertEqual(exercise.sets, 4)
        XCTAssertEqual(exercise.repsMin, 6)
        XCTAssertEqual(exercise.repsMax, 10)
        XCTAssertEqual(exercise.notes, "locker")
    }

    func testExerciseSnapshotDetectsFieldChange() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let exercise = Exercise(name: "Kniebeuge", sets: 3)
        ctx.insert(exercise)

        let snapshot = ExerciseSnapshot.capture(from: exercise)
        exercise.sets = 5
        XCTAssertNotEqual(snapshot, ExerciseSnapshot.capture(from: exercise))
    }

    /// Kernvertrag von `revertToSnapshot()`: mehrere Felder gleichzeitig
    /// geaendert (inkl. Custom-Metadaten), ein einziges `apply(to:)` muss
    /// ALLE wieder auf den Ausgangszustand bringen — kein Teil-Rollback.
    func testExerciseSnapshotApplyRevertsMultipleFieldsAtOnce() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let exercise = Exercise(
            name: "Eigene Übung", sets: 3, repsMin: 8, repsMax: 12,
            isCardio: false, isCompound: false,
            primaryMuscle: .chest, equipment: .bodyweight
        )
        ctx.insert(exercise)
        let snapshot = ExerciseSnapshot.capture(from: exercise)

        exercise.sets = 10
        exercise.isCardio = true
        exercise.isCompound = true
        exercise.primaryMuscle = .back
        exercise.equipment = .barbell
        exercise.notes = "geändert"
        XCTAssertNotEqual(snapshot, ExerciseSnapshot.capture(from: exercise))

        snapshot.apply(to: exercise)
        XCTAssertEqual(exercise.sets, 3)
        XCTAssertFalse(exercise.isCardio)
        XCTAssertFalse(exercise.isCompound)
        XCTAssertEqual(exercise.primaryMuscle, .chest)
        XCTAssertEqual(exercise.equipment, .bodyweight)
        XCTAssertNil(exercise.notes)
        XCTAssertEqual(snapshot, ExerciseSnapshot.capture(from: exercise))
    }

    // MARK: - TrainingDaySnapshot

    func testTrainingDaySnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day = TrainingDay(name: "Push Day", weekday: 2, type: .custom, nextIntensity: .heavy)
        ctx.insert(day)

        let snapshot = TrainingDaySnapshot.capture(from: day)
        snapshot.apply(to: day)

        XCTAssertEqual(day.weekday, 2)
        XCTAssertEqual(day.type, .custom)
        XCTAssertEqual(day.nextIntensity, .heavy)
    }

    /// `metaSection`-Scope (siehe Doc-Kommentar am Struct): Typ-Wechsel auf
    /// `.rest` und zurueck ist das zentrale Szenario fuer die
    /// Ruhetag-Darstellung — muss vollstaendig revertierbar sein.
    func testTrainingDaySnapshotRevertsTypeAndTimeFormatChange() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day = TrainingDay(name: "Montag", weekday: 2, type: .custom)
        ctx.insert(day)
        let snapshot = TrainingDaySnapshot.capture(from: day)

        day.type = .rest
        day.timeFormat = .amrap
        day.timeCapMinutes = 20
        XCTAssertNotEqual(snapshot, TrainingDaySnapshot.capture(from: day))

        snapshot.apply(to: day)
        XCTAssertEqual(day.type, .custom)
        XCTAssertNil(day.timeFormat)
        XCTAssertNil(day.timeCapMinutes)
    }

    // MARK: - PlanMetaSnapshot

    func testPlanMetaSnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Mein Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        ctx.insert(plan)

        let snapshot = PlanMetaSnapshot.capture(from: plan)
        snapshot.apply(to: plan)

        XCTAssertEqual(plan.weeks, 8)
        XCTAssertTrue(plan.isActive)
        XCTAssertEqual(plan.targetEnvironment, .gym)
    }

    /// Kernvertrag der Korrektur: `targetEnvironment` UND `isActive` sind
    /// jetzt Teil des Snapshots (vorher bewusst ausgeschlossen) — ein
    /// einziges `apply(to:)` muss beide zusammen mit den einfachen Feldern
    /// zuruecksetzen.
    func testPlanMetaSnapshotRevertsEnvironmentAndActiveFlagTogether() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let plan = TrainingPlan(name: "Plan A", weeks: 12, isActive: false, targetEnvironment: .gym)
        ctx.insert(plan)
        let snapshot = PlanMetaSnapshot.capture(from: plan)

        plan.weeks = 4
        plan.isActive = true
        plan.targetEnvironment = .homeGym
        XCTAssertNotEqual(snapshot, PlanMetaSnapshot.capture(from: plan))

        snapshot.apply(to: plan)
        XCTAssertEqual(plan.weeks, 12)
        XCTAssertFalse(plan.isActive)
        XCTAssertEqual(plan.targetEnvironment, .gym)
        XCTAssertEqual(snapshot, PlanMetaSnapshot.capture(from: plan))
    }

    // MARK: - ProfileMetaSnapshot

    func testProfileMetaSnapshotCaptureThenApplyIsNoOp() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            trainingGoal: .hybrid
        )
        ctx.insert(profile)

        let snapshot = ProfileMetaSnapshot.capture(from: profile)
        snapshot.apply(to: profile)

        XCTAssertEqual(profile.heightCm, 180)
        XCTAssertEqual(profile.profile, .male)
        XCTAssertEqual(profile.trainingGoal, .hybrid)
    }

    /// Szenario aus `ProfileEditorView.revertToSnapshot()`s Doc-Kommentar:
    /// Cardio-Felder gemeinsam geaendert, ein `apply(to:)` muss alle
    /// zuruecksetzen (der `fiveKReferenceText`-Puffer-Resync selbst ist
    /// View-State und bleibt hier unteilbar ungetestet, siehe Datei-Header).
    func testProfileMetaSnapshotRevertsCardioFieldsTogether() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 170, profile: .female,
            cardioCoachingEnabled: false, cardioGoal: .generalFitness
        )
        ctx.insert(profile)
        let snapshot = ProfileMetaSnapshot.capture(from: profile)

        profile.cardioCoachingEnabled = true
        profile.cardioGoal = .marathon
        profile.current5kReferenceSeconds = 1500
        profile.weeklyWorkoutGoal = 6
        XCTAssertNotEqual(snapshot, ProfileMetaSnapshot.capture(from: profile))

        snapshot.apply(to: profile)
        XCTAssertFalse(profile.cardioCoachingEnabled)
        XCTAssertEqual(profile.cardioGoal, .generalFitness)
        XCTAssertNil(profile.current5kReferenceSeconds)
        XCTAssertEqual(profile.weeklyWorkoutGoal, 1)
    }
}
#endif
