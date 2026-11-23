#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Modul-7-Audit: `Exercise.role` (workingSet/warmup/cooldown) existierte
/// bisher NUR auf der Plan-Uebung, nicht als Snapshot auf `ExerciseLog` -
/// nach einem Exercise-Delete (DEL-051 `.nullify`-Regel) wertete
/// `MuscleSetExtractor` das verwaiste Log faelschlich als Arbeitssatz, obwohl
/// die Rolle beim Loggen bekannt war. Dieser Test deckt den neuen
/// `exerciseRoleSnapshot`/`resolvedIsWorkingSet` ab, exakt nach demselben
/// Muster wie `exerciseCardioEquipmentSnapshot`/`resolvedCardioEquipment`
/// (live-first, Snapshot nur als Orphan-Fallback).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExerciseLogRoleSnapshotTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeExercise(role: ExerciseRole) -> Exercise {
        let day = TrainingDay(name: "Push", weekday: 2, type: .chest)
        context.insert(day)
        let exercise = Exercise(name: "Bench Press", day: day)
        exercise.role = role
        context.insert(exercise)
        day.exercises.append(exercise)
        return exercise
    }

    /// Anforderung: die Rolle wird beim ERZEUGEN des Logs aus der damaligen
    /// `Exercise` geschnappschusst, nicht erst bei Bedarf live nachgeschlagen.
    func testSnapshotIsCapturedFromExerciseAtLogCreationTime() {
        let exercise = makeExercise(role: .warmup)
        let log = ExerciseLog(setIndex: 0, weight: 20, reps: 15, rir: 4, exercise: exercise)
        context.insert(log)
        XCTAssertEqual(log.exerciseRoleSnapshot, ExerciseRole.warmup.rawValue)
        XCTAssertFalse(log.resolvedIsWorkingSet)
    }

    func testSnapshotCapturesWorkingSetDistinctly() {
        let exercise = makeExercise(role: .workingSet)
        let log = ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: exercise)
        context.insert(log)
        XCTAssertEqual(log.exerciseRoleSnapshot, ExerciseRole.workingSet.rawValue)
        XCTAssertTrue(log.resolvedIsWorkingSet)
    }

    /// Live-first: aendert der User die Rolle der Plan-Uebung NACHTRAEGLICH,
    /// soll sich das sofort auf bereits geloggte Saetze auswirken - analog
    /// zu `resolvedCardioEquipment`, das aus demselben Grund live-first liest.
    func testResolvedIsWorkingSetPrefersLiveExerciseOverStaleSnapshot() {
        let exercise = makeExercise(role: .warmup)
        let log = ExerciseLog(setIndex: 0, weight: 20, reps: 15, rir: 4, exercise: exercise)
        context.insert(log)
        XCTAssertFalse(log.resolvedIsWorkingSet, "Schnappschuss zeigt zunaechst Warmup")

        exercise.role = .workingSet
        XCTAssertTrue(log.resolvedIsWorkingSet, "Live-Aenderung muss sich sofort niederschlagen, nicht erst nach Delete")
    }

    /// Kernfall dieses Audits: nach dem Loeschen der Exercise (orphan-Log)
    /// muss die beim Loggen bekannte Rolle erhalten bleiben.
    func testResolvedIsWorkingSetFallsBackToSnapshotAfterExerciseIsDeleted() throws {
        let exercise = makeExercise(role: .warmup)
        let log = ExerciseLog(setIndex: 0, weight: 20, reps: 15, rir: 4, exercise: exercise)
        context.insert(log)
        try context.save()

        context.delete(exercise)
        try context.save()

        XCTAssertNil(log.exercise)
        XCTAssertFalse(log.resolvedIsWorkingSet, "die bekannte Warmup-Rolle darf nach dem Delete nicht verloren gehen")
    }

    /// Alt-Bestand vor diesem Feld (kein Snapshot, kein Live-Exercise) bleibt
    /// bewusst konservativ ein Arbeitssatz — vor diesem Feld gab es schlicht
    /// keine andere Information.
    func testResolvedIsWorkingSetDefaultsToTrueWithoutAnySnapshotOrLiveExercise() {
        let log = ExerciseLog(setIndex: 0, weight: 60, reps: 10, rir: 2, exercise: nil)
        context.insert(log)
        XCTAssertNil(log.exerciseRoleSnapshot)
        XCTAssertTrue(log.resolvedIsWorkingSet)
    }
}
#endif
