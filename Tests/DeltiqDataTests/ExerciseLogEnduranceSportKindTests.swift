#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 1, Architektur-Luecke (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase1-implementation.md, Abschnitt 0):
/// `Exercise.enduranceSportKind` existierte bisher NUR auf der Plan-Uebung,
/// nicht als Snapshot auf `ExerciseLog` - nach einem Exercise-Delete (DEL-051
/// `.nullify`-Regel) war die geloggte Sportart fuer ALTE Laeufe dauerhaft
/// nicht mehr rekonstruierbar, obwohl sie beim Loggen eindeutig war. Dieser
/// Test deckt den neuen `exerciseEnduranceSportKindSnapshot`/
/// `resolvedEnduranceSportKind` ab, exakt nach demselben Muster wie
/// `exerciseCardioEquipmentSnapshot`/`resolvedCardioEquipment`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExerciseLogEnduranceSportKindTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeCardioExercise(sportKind: TrainingTypeKind?) -> Exercise {
        let day = TrainingDay(name: "Run", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Easy Run", isCardio: true, day: day)
        exercise.enduranceSportKind = sportKind
        context.insert(exercise)
        day.exercises.append(exercise)
        return exercise
    }

    /// Anforderung 1: die Sportart wird beim ERZEUGEN des Logs aus der
    /// damaligen `Exercise` geschnappschusst, nicht erst bei Bedarf live
    /// nachgeschlagen.
    func testSnapshotIsCapturedFromExerciseAtLogCreationTime() {
        let exercise = makeCardioExercise(sportKind: .running)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 0, exercise: exercise)
        context.insert(log)
        XCTAssertEqual(log.exerciseEnduranceSportKindSnapshot, TrainingTypeKind.running.rawValue)
        XCTAssertEqual(log.resolvedEnduranceSportKind, .running)
    }

    func testSnapshotCapturesCyclingDistinctly() {
        let exercise = makeCardioExercise(sportKind: .cycling)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 0, exercise: exercise)
        context.insert(log)
        XCTAssertEqual(log.resolvedEnduranceSportKind, .cycling)
    }

    /// Anforderung 3: eine Cardio-Uebung ohne gepflegte Sportart darf NIE als
    /// Laufen angenommen werden - der Snapshot bleibt explizit `nil`
    /// ("unbekannt"), nicht geraten.
    func testUnsetSportKindOnACardioExerciseSnapshotsAsNilNeverGuessedAsRunning() {
        let exercise = makeCardioExercise(sportKind: nil)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 0, exercise: exercise)
        context.insert(log)
        XCTAssertNil(log.exerciseEnduranceSportKindSnapshot)
        XCTAssertNil(log.resolvedEnduranceSportKind)
    }

    /// Ein Strength-Log (keine Cardio-Uebung) traegt nie einen Sportart-Snapshot.
    func testStrengthExerciseNeverSnapshotsASportKind() {
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs)
        context.insert(day)
        let exercise = Exercise(name: "Squat", isCardio: false, day: day)
        context.insert(exercise)
        day.exercises.append(exercise)
        let log = ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: exercise)
        context.insert(log)
        XCTAssertNil(log.exerciseEnduranceSportKindSnapshot)
        XCTAssertNil(log.resolvedEnduranceSportKind)
    }

    /// Anforderung 4/5 (zentraler Fund): nach dem Loeschen der `Exercise`
    /// muss die geloggte Sportart erhalten bleiben - eine Plan-Aenderung
    /// (z.B. eine Coach-Plananpassung) darf die Klassifikation bereits
    /// absolvierter Einheiten NICHT veraendern.
    func testResolvedEnduranceSportKindSurvivesExerciseDeletion() throws {
        let exercise = makeCardioExercise(sportKind: .running)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 0, exercise: exercise)
        context.insert(log)
        try context.save()

        context.delete(exercise)
        try context.save()

        XCTAssertNil(log.exercise, "Nullify-Regel: die Live-Referenz ist weg")
        XCTAssertEqual(log.resolvedEnduranceSportKind, .running, "die Sportart muss trotz geloeschter Exercise erhalten bleiben")
    }

    /// Anforderung 4 (Kehrseite): ein nachtraegliches Aendern der Sportart
    /// auf der NOCH LEBENDEN `Exercise` darf einen bereits geschnappschussten
    /// Log nicht nachtraeglich umklassifizieren - der Snapshot ist eine
    /// Tatsache des damaligen Loggens, kein live editierbares Feld.
    func testChangingLiveExerciseSportKindAfterLoggingDoesNotRetroactivelyReclassifyTheLog() {
        let exercise = makeCardioExercise(sportKind: .running)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 0, exercise: exercise)
        context.insert(log)

        exercise.enduranceSportKind = .cycling

        XCTAssertEqual(log.resolvedEnduranceSportKind, .running, "bereits geloggte Einheiten duerfen durch eine spaetere Aenderung an der Plan-Uebung nicht umklassifiziert werden")
    }

    /// Anforderung 2/3 (Migration): ein Alt-Log aus der Zeit vor diesem Feld
    /// hat `exerciseNameSnapshot == nil` (kein DEL-051-Snapshot ueberhaupt) -
    /// `resolvedEnduranceSportKind` faellt dann auf die Live-Exercise zurueck,
    /// genau wie `resolvedIsCardio`/`resolvedIsTimeBased` es bereits tun.
    /// Existiert auch die Live-Exercise nicht mehr, bleibt das Ergebnis `nil`
    /// ("unbekannt") - niemals als Laufen angenommen.
    func testLegacyLogWithoutAnySnapshotFallsBackToLiveExerciseThenToUnknown() throws {
        let exercise = makeCardioExercise(sportKind: .running)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 1, rir: 0, exercise: exercise)
        context.insert(log)
        // Alt-Bestand simulieren: kein DEL-051-Snapshot ueberhaupt vorhanden.
        log.exerciseNameSnapshot = nil
        log.exerciseEnduranceSportKindSnapshot = nil

        XCTAssertEqual(log.resolvedEnduranceSportKind, .running, "ohne Snapshot faellt auf die noch lebende Exercise zurueck")

        try context.save()
        context.delete(exercise)
        try context.save()

        XCTAssertNil(log.resolvedEnduranceSportKind, "ohne Snapshot UND ohne lebende Exercise ist die Sportart unbekannt, nie geraten")
    }
}
#endif
