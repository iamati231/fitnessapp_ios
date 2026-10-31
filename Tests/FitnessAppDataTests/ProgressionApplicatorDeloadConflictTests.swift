#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// F08 (docs/specifications/04_TESTS_UND_ABNAHME.md, Kernabnahme Dok. 03 §5:
/// "nicht dieselbe Übung gleichzeitig steigern und reduzieren") — deckt das
/// Zusammenspiel von `ProgressionApplicator` (laufende Übungsprogression)
/// und `DeloadManager` (Overreaching-Deload) ab, die bisher unabhängig
/// voneinander auf dasselbe `Exercise.suggestedWeight` schreiben.
///
/// **Gefundener Konflikt:** `DeloadManager.startDeload` halbiert bewusst das
/// Arbeitsgewicht und sichert das Original in `deloadOriginalWeight`, damit
/// `endDeload` es später wiederherstellen kann. Weil das reduzierte Gewicht
/// leichter ist, trifft der Nutzer in der Deload-Woche die obere
/// Wiederholungsgrenze mit sicherem RIR besonders leicht — `ProgressionApplicator`
/// kannte `deloadOriginalWeight` bisher nicht und schrieb `.increaseWeight`
/// trotzdem direkt auf `suggestedWeight`. Zwei Folgen, beide ein echter
/// Verstoß gegen Dok. 03 §5:
///   1. Dieselbe Übung wird in derselben Woche gleichzeitig reduziert
///      (Deload) und gesteigert (Progression) — ein widersprüchlicher
///      Vorschlag.
///   2. Der während der Deload-Woche erarbeitete Fortschritt geht beim
///      nächsten `endDeload()` stillschweigend verloren, weil dieser
///      unverändert den VOR dem Deload eingefrorenen `deloadOriginalWeight`
///      zurückschreibt — eine echte Datenverlust-Regression, kein reiner
///      Anzeige-Fehler.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ProgressionApplicatorDeloadConflictTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - DeloadManager.startDeload factor validation (DEL-Audit)

    /// factor >= 1 wuerde Gewichte ERHOEHEN — guard muss das stumm ablehnen.
    func testStartDeloadWithFactorAboveOneChangesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 100, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        try context.save()

        let adjusted = try DeloadManager.startDeload(in: context, factor: 1.5)
        XCTAssertEqual(adjusted, 0, "factor > 1 darf keine Uebungen veraendern")
        XCTAssertEqual(squat.suggestedWeight, 100, "Gewicht muss unveraendert bleiben")
        XCTAssertNil(squat.deloadOriginalWeight, "kein Snapshot bei ungueltigem Faktor")
    }

    func testStartDeloadWithFactorOneChangesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 80, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        try context.save()

        let adjusted = try DeloadManager.startDeload(in: context, factor: 1.0)
        XCTAssertEqual(adjusted, 0, "factor == 1 ist keine Reduktion")
        XCTAssertNil(squat.deloadOriginalWeight)
    }

    func testStartDeloadWithZeroFactorChangesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 60, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        try context.save()

        let adjusted = try DeloadManager.startDeload(in: context, factor: 0)
        XCTAssertEqual(adjusted, 0, "factor == 0 waere Nullgewicht — Guard muss ablehnen")
        XCTAssertNil(squat.deloadOriginalWeight)
    }

    func testStartDeloadWithNaNChangesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 60, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        try context.save()

        let adjusted = try DeloadManager.startDeload(in: context, factor: .nan)
        XCTAssertEqual(adjusted, 0, "NaN darf keine Uebungen veraendern")
        XCTAssertNil(squat.deloadOriginalWeight)
    }

    /// Gegenprobe: der Standard-Faktor 0.5 laeuft weiterhin durch.
    func testStartDeloadWithDefaultFactorReducesWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 100, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        try context.save()

        let adjusted = try DeloadManager.startDeload(in: context)
        XCTAssertEqual(adjusted, 1)
        XCTAssertEqual(squat.suggestedWeight, 50)
        XCTAssertEqual(squat.deloadOriginalWeight, 100)
    }

    func testIncreaseWeightIsVetoedToHoldWhileAnExerciseHasAPendingDeloadSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 50, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)

        // Aktiver Deload: `startDeload` haette hier `deloadOriginalWeight = 100`
        // gesetzt und `suggestedWeight` auf 50 halbiert — direkt konstruiert,
        // um `DeloadManager` nicht ein zweites Mal zu testen.
        squat.deloadOriginalWeight = 100
        squat.suggestedWeight = 50

        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        context.insert(session)

        // Obere Wiederholungsgrenze (10) mit sicherem RIR (>= 2) getroffen —
        // das leichtere Deload-Gewicht macht genau das wahrscheinlich.
        let log = ExerciseLog(setIndex: 0, weight: 50, reps: 10, rir: 3, exercise: squat, session: session)
        context.insert(log)
        try context.save()

        let outcomes = ProgressionApplicator.apply(to: session, in: context)

        XCTAssertTrue(
            outcomes.isEmpty,
            "waehrend eine Uebung auf ihre Deload-Rueckstellung wartet, darf Progression keine Steigerung feiern: \(outcomes)"
        )
        XCTAssertEqual(
            squat.suggestedWeight, 50,
            "das reduzierte Deload-Gewicht darf nicht durch eine gleichzeitige Progressions-Steigerung ueberschrieben werden"
        )
        XCTAssertEqual(squat.deloadOriginalWeight, 100, "der eingefrorene Originalwert bleibt fuer endDeload unveraendert")
    }

    /// Gegenprobe: ohne aktiven Deload (Normalfall) bleibt die Steigerung
    /// unveraendert moeglich — kein pauschales Veto, nur fuer Uebungen mit
    /// tatsaechlich offenem Deload-Snapshot.
    func testIncreaseWeightStillAppliesNormallyWithoutAnActiveDeload() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 100, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        context.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 100, reps: 10, rir: 3, exercise: squat, session: session)
        context.insert(log)
        try context.save()

        let outcomes = ProgressionApplicator.apply(to: session, in: context)

        XCTAssertEqual(outcomes.count, 1)
        guard case .increaseWeight = outcomes.first?.action else {
            return XCTFail("ohne Deload-Konflikt muss die normale Steigerung weiterhin greifen: \(outcomes)")
        }
        XCTAssertEqual(squat.suggestedWeight, 102.5)
    }

    /// `evaluateOnly` (WorkoutSummary-Replay) muss dieselbe Vetoregel zeigen
    /// wie `apply` — sonst wuerde die Celebration-Anzeige einen Erfolg
    /// feiern, den `apply` tatsaechlich gar nicht geschrieben hat.
    func testEvaluateOnlyMirrorsTheSameDeloadVetoAsApply() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let squat = Exercise(
            name: "Kniebeuge", exerciseTemplateID: UUID(), sets: 1, repsMin: 8, repsMax: 10,
            suggestedWeight: 50, orderIndex: 0, targetRir: 2, isCompound: true, day: day
        )
        context.insert(squat)
        squat.deloadOriginalWeight = 100
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        context.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 50, reps: 10, rir: 3, exercise: squat, session: session)
        context.insert(log)
        try context.save()

        let outcomes = ProgressionApplicator.evaluateOnly(for: session)
        XCTAssertTrue(outcomes.isEmpty, "Replay-Anzeige darf keine Steigerung zeigen, die `apply` ebenfalls verweigert: \(outcomes)")
    }
}
#endif
