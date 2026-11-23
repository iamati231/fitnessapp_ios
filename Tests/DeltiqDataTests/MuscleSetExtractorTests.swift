#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// DEL-Progress-02C: MuscleSetExtractor data-layer integration tests.
/// Covers the muscle-lookup path (custom override, template fallback, nil),
/// warmup exclusion, orphaned-log handling, and session-timestamp accuracy.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MuscleSetExtractorTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - 1. Template fallback when exercise has no primaryMuscle override

    func test_templateFallbackWhenExerciseLacksMuscle() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let templateID = UUID()
        let template = ExerciseTemplate(id: templateID, name: "Bench Press",
                                        equipment: .barbell, primaryMuscle: .chest)
        ctx.insert(template)

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .chest, plan: plan)
        ctx.insert(day)
        let ex = Exercise(name: "Bench Press", exerciseTemplateID: templateID,
                          orderIndex: 0, day: day)
        // primaryMuscle is nil (not overridden)
        ctx.insert(ex)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        ctx.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2,
                              exercise: ex, session: session)
        ctx.insert(log)
        try ctx.save()

        let result = MuscleSetExtractor.extract(from: [session], templates: [template])
        XCTAssertEqual(result.count, 1)
        let set1 = try XCTUnwrap(result.first)
        XCTAssertEqual(set1.muscleGroup, .chest, "should fall back to template's primaryMuscle")
    }

    // MARK: - 2. Exercise primaryMuscle override takes priority over template

    func test_exerciseOverrideTakesPriorityOverTemplate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let templateID = UUID()
        let template = ExerciseTemplate(id: templateID, name: "Pull-Up",
                                        equipment: .bodyweight, primaryMuscle: .back)
        ctx.insert(template)

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Pull", weekday: 3, type: .back, plan: plan)
        ctx.insert(day)
        let ex = Exercise(name: "Pull-Up", exerciseTemplateID: templateID,
                          orderIndex: 0, day: day)
        ex.primaryMuscle = .biceps  // custom override
        ctx.insert(ex)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        ctx.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 8, rir: 1,
                              exercise: ex, session: session)
        ctx.insert(log)
        try ctx.save()

        let result = MuscleSetExtractor.extract(from: [session], templates: [template])
        let set2 = try XCTUnwrap(result.first)
        XCTAssertEqual(set2.muscleGroup, .biceps, "exercise override should win over template")
    }

    // MARK: - 3. Warmup sets excluded

    func test_warmupSetsExcluded() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .chest, plan: plan)
        ctx.insert(day)

        let warmup = Exercise(name: "Warmup Bench", orderIndex: 0, day: day)
        warmup.role = .warmup
        warmup.primaryMuscle = .chest
        ctx.insert(warmup)

        let working = Exercise(name: "Bench Press", orderIndex: 1, day: day)
        working.primaryMuscle = .chest
        ctx.insert(working)

        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        ctx.insert(session)

        ctx.insert(ExerciseLog(setIndex: 0, weight: 20, reps: 15, rir: 4, exercise: warmup, session: session))
        ctx.insert(ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: working, session: session))
        try ctx.save()

        let result = MuscleSetExtractor.extract(from: [session], templates: [])
        XCTAssertEqual(result.count, 1, "warmup set must be excluded")
        XCTAssertEqual(result.first?.exerciseName, "Bench Press")
    }

    // MARK: - 3b. Modul-7-Audit: a deleted warmup's orphaned log must stay excluded

    /// Vorher fehlte `ExerciseLog` ein Snapshot fuer `Exercise.role` - ein
    /// geloeschtes Warmup wurde danach (`exercise == nil`) faelschlich als
    /// Arbeitssatz gezaehlt, obwohl die Rolle beim Loggen bekannt war.
    func test_orphanedWarmupLogStaysExcludedAfterExerciseIsDeleted() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .chest, plan: plan)
        ctx.insert(day)

        let warmup = Exercise(name: "Warmup Bench", orderIndex: 0, day: day)
        warmup.role = .warmup
        warmup.primaryMuscle = .chest
        ctx.insert(warmup)

        let working = Exercise(name: "Bench Press", orderIndex: 1, day: day)
        working.primaryMuscle = .chest
        ctx.insert(working)

        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        ctx.insert(session)

        let warmupLog = ExerciseLog(setIndex: 0, weight: 20, reps: 15, rir: 4, exercise: warmup, session: session)
        ctx.insert(warmupLog)
        ctx.insert(ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: working, session: session))
        try ctx.save()
        XCTAssertEqual(warmupLog.exerciseRoleSnapshot, ExerciseRole.warmup.rawValue)

        // Nutzer loescht die Warmup-Uebung manuell aus dem Plan - der Log
        // ueberlebt als Orphan (DEL-051 `.nullify`), die Rolle-Snapshot bleibt.
        ctx.delete(warmup)
        try ctx.save()
        XCTAssertNil(warmupLog.exercise)
        XCTAssertEqual(warmupLog.exerciseRoleSnapshot, ExerciseRole.warmup.rawValue,
                       "der Snapshot darf vom Delete nicht beruehrt werden")

        let result = MuscleSetExtractor.extract(from: [session], templates: [])
        XCTAssertEqual(result.count, 1, "das verwaiste Warmup-Log muss weiterhin ausgeschlossen bleiben")
        XCTAssertEqual(result.first?.exerciseName, "Bench Press")
    }

    // MARK: - 4. Orphaned log (exercise == nil) included with nil muscleGroup

    func test_orphanedLogIncludedWithNilMuscle() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .chest, plan: plan)
        ctx.insert(day)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        ctx.insert(session)

        let log = ExerciseLog(setIndex: 0, weight: 60, reps: 10, rir: 2,
                              exercise: nil, session: session)
        log.exerciseNameSnapshot = "Deleted Exercise"
        ctx.insert(log)
        try ctx.save()

        let result = MuscleSetExtractor.extract(from: [session], templates: [])
        XCTAssertEqual(result.count, 1, "orphaned log must be included")
        XCTAssertNil(result.first?.muscleGroup)
    }

    // MARK: - 5. Two sessions on the same day carry different sessionTimestamps

    func test_twoSessionsSameDayDistinctTimestamps() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .chest, plan: plan)
        ctx.insert(day)

        let ex = Exercise(name: "Squat", orderIndex: 0, day: day)
        ex.primaryMuscle = .quads
        ctx.insert(ex)

        let morning = Date()
        let evening = morning.addingTimeInterval(8 * 3600)
        let s1 = WorkoutSession(startTime: morning, endTime: morning.addingTimeInterval(3600),
                                isCompleted: true, day: day)
        let s2 = WorkoutSession(startTime: evening, endTime: evening.addingTimeInterval(3600),
                                isCompleted: true, day: day)
        ctx.insert(s1); ctx.insert(s2)
        ctx.insert(ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: ex, session: s1))
        ctx.insert(ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: ex, session: s2))
        try ctx.save()

        let result = MuscleSetExtractor.extract(from: [s1, s2], templates: [])
        XCTAssertEqual(result.count, 2)
        XCTAssertNotEqual(result[0].sessionTimestamp, result[1].sessionTimestamp,
                          "same-day sessions must carry distinct sessionTimestamps")
    }
}
#endif
