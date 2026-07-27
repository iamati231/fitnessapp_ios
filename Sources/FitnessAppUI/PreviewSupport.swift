#if DEBUG && canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// In-memory ModelContainer factories for SwiftUI previews. The `isStoredInMemoryOnly`
/// flag keeps preview data out of the simulator's persistent store, so live-coding a
/// view doesn't pollute the dev database.
@MainActor
public enum PreviewSeed {

    /// Container with a single male UserBodyProfile (32 yrs, 180 cm).
    public static let maleProfileContainer: ModelContainer = makeContainer { ctx in
        ctx.insert(UserBodyProfile(
            birthDate: Self.birthDate(yearsAgo: 32),
            heightCm: 180,
            profile: .male,
            goalWeightKg: 78,
            environment: .gym
        ))
    }

    /// Container with a single female UserBodyProfile (28 yrs, 168 cm).
    public static let femaleProfileContainer: ModelContainer = makeContainer { ctx in
        ctx.insert(UserBodyProfile(
            birthDate: Self.birthDate(yearsAgo: 28),
            heightCm: 168,
            profile: .female,
            goalWeightKg: 60,
            environment: .gym
        ))
    }

    /// Container with no profile — exercises the empty-state branch in MeasurementView.
    public static let emptyContainer: ModelContainer = makeContainer { _ in }

    /// Realistic dashboard demo: male profile + 6 weekly measurements with a slight
    /// downward trend (~0.5 kg/week) and Navy KFA filled in + an active PPL plan +
    /// 3 prior completed Push/Pull/Legs sessions over the last 2 weeks. Drives the
    /// trend chart, forecast, plan-day card, and recent-workouts list.
    public static let dashboardContainer: ModelContainer = makeContainer { ctx in
        let profile = UserBodyProfile(
            birthDate: Self.birthDate(yearsAgo: 32),
            heightCm: 180,
            profile: .male,
            goalWeightKg: 76,
            environment: .gym
        )
        ctx.insert(profile)

        // Weeks-ago, weight, neck, waist — slight cut, neck stays, waist trims down.
        let series: [(weeksAgo: Int, weightKg: Double, neckCm: Double, waistCm: Double)] = [
            (6, 80.5, 38.0, 89.0),
            (5, 80.0, 38.0, 88.5),
            (4, 79.4, 38.0, 88.0),
            (3, 78.9, 38.0, 87.5),
            (2, 78.4, 38.0, 87.0),
            (1, 77.8, 38.0, 86.5)
        ]
        for entry in series {
            let date = Calendar.current.date(byAdding: .weekOfYear, value: -entry.weeksAgo, to: Date())
                       ?? Date()
            let measurement = BodyMeasurement.makeDerived(
                date: date,
                ageYears: 32,
                weightKg: entry.weightKg,
                heightCm: 180,
                profile: .male,
                neckCm: entry.neckCm,
                waistCm: entry.waistCm
            )
            ctx.insert(measurement)
        }

        // PPL plan + a chain of recent completed sessions to populate Recent-Workouts.
        let plan = seedSamplePlan(in: ctx)
        seedSampleTemplates(in: ctx)
        // Sequence: 12 days ago Push, 10 ago Pull, 7 ago Legs, 5 ago Push, 3 ago Pull.
        // Modulo logic makes "Legs" the next scheduled day (5 completed % 3 days = index 2 = Legs).
        let scheduled: [(daysAgo: Int, dayName: String)] = [
            (12, "Push"), (10, "Pull"), (7, "Legs"), (5, "Push"), (3, "Pull")
        ]
        for entry in scheduled {
            guard let day = plan.days.first(where: { $0.name == entry.dayName }) else { continue }
            seedCompletedSession(for: day, daysAgo: entry.daysAgo, in: ctx)
        }
    }

    /// Single-measurement scenario — proves the insufficient-data branch
    /// (`projectWeightTrend` returns nil with < 3 samples).
    public static let singleMeasurementContainer: ModelContainer = makeContainer { ctx in
        let profile = UserBodyProfile(
            birthDate: Self.birthDate(yearsAgo: 32),
            heightCm: 180,
            profile: .male,
            goalWeightKg: 76,
            environment: .gym
        )
        ctx.insert(profile)
        ctx.insert(BodyMeasurement.makeDerived(
            ageYears: 32,
            weightKg: 80.0,
            heightCm: 180,
            profile: .male,
            neckCm: 38, waistCm: 89
        ))
    }

    /// Realistic Push/Pull/Legs sample for the Workout flow: profile + plan + 3 days
    /// + a handful of exercises per day + ExerciseTemplates seeded into the library so
    /// the picker has content.
    public static let workoutContainer: ModelContainer = makeContainer { ctx in
        seedDefaultProfile(in: ctx)
        seedSamplePlan(in: ctx)
        seedSampleTemplates(in: ctx)
    }

    /// Same as `workoutContainer` plus:
    ///  - one PRIOR completed Push session 7 days ago with full set logs (so the
    ///    "Letztes: ..." hints in `SetRow` have content),
    ///  - one in-flight (isCompleted=false) Push session started 22 min ago.
    public static let activeSessionContainer: ModelContainer = makeContainer { ctx in
        seedDefaultProfile(in: ctx)
        let plan = seedSamplePlan(in: ctx)
        seedSampleTemplates(in: ctx)

        guard let pushDay = plan.days.first(where: { $0.name == "Push" }) else { return }

        // 1) Prior completed session — gives the SetRow Previous-Hints data.
        seedCompletedSession(for: pushDay, daysAgo: 7, in: ctx)

        // 2) Live in-progress session that the preview lands on.
        let active = WorkoutSession(
            startTime: Date().addingTimeInterval(-22 * 60),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: pushDay.exercises.count,
            isCompleted: false,
            dayName: pushDay.name,
            day: pushDay
        )
        ctx.insert(active)
    }

    // MARK: Internals

    private static func makeContainer(
        seed: @MainActor (ModelContext) -> Void
    ) -> ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: UserBodyProfile.self, BodyMeasurement.self,
                     TrainingPlan.self, TrainingDay.self,
                     Exercise.self, ExerciseLog.self,
                     WorkoutSession.self, ExerciseTemplate.self,
                     WaterEntry.self,
                configurations: config
            )
            seed(container.mainContext)
            return container
        } catch {
            fatalError("Failed to build preview ModelContainer: \(error)")
        }
    }

    private static func birthDate(yearsAgo years: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: -years, to: Date()) ?? Date()
    }

    @discardableResult
    private static func seedDefaultProfile(in ctx: ModelContext) -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: birthDate(yearsAgo: 32),
            heightCm: 180,
            profile: .male,
            goalWeightKg: 78,
            environment: .gym
        )
        ctx.insert(profile)
        return profile
    }

    /// Push / Pull / Legs split, 3 days, 3-4 exercises each. Returns the plan so callers
    /// can grab a specific day for further seeding.
    @discardableResult
    private static func seedSamplePlan(in ctx: ModelContext) -> TrainingPlan {
        let plan = TrainingPlan(
            name: "Push/Pull/Legs",
            programType: "PPL",
            descriptionText: "3-Tage-Split für Hypertrophie",
            weeks: 12,
            isActive: true,
            targetEnvironment: .gym
        )
        ctx.insert(plan)

        // weekday: Calendar conv. 1=Sun, 2=Mon, ..., 7=Sat — Mon/Wed/Fri = 2/4/6
        let push = TrainingDay(name: "Push", weekday: 2, type: .push, plan: plan)
        let pull = TrainingDay(name: "Pull", weekday: 4, type: .pull, plan: plan)
        let legs = TrainingDay(name: "Legs", weekday: 6, type: .legs, plan: plan)
        ctx.insert(push); ctx.insert(pull); ctx.insert(legs)

        let pushExercises: [(String, Int, Int, Int, Int)] = [
            ("Bankdrücken",      4, 6, 10, 120),
            ("Schrägbankdrücken (KH)", 3, 8, 12, 90),
            ("Schulterdrücken",  3, 8, 12, 90),
            ("Trizeps-Pushdown",  3, 10, 15, 60)
        ]
        for (i, e) in pushExercises.enumerated() {
            ctx.insert(Exercise(name: e.0, sets: e.1, repsMin: e.2, repsMax: e.3,
                                restSeconds: e.4, orderIndex: i, day: push))
        }

        let pullExercises: [(String, Int, Int, Int, Int)] = [
            ("Kreuzheben",        3, 4, 6, 180),
            ("Klimmzüge",        4, 6, 10, 120),
            ("Langhantel-Rudern", 3, 8, 12, 90),
            ("Bizeps-Curls",      3, 10, 15, 60)
        ]
        for (i, e) in pullExercises.enumerated() {
            ctx.insert(Exercise(name: e.0, sets: e.1, repsMin: e.2, repsMax: e.3,
                                restSeconds: e.4, orderIndex: i, day: pull))
        }

        let legsExercises: [(String, Int, Int, Int, Int)] = [
            ("Kniebeuge",         4, 5, 8, 180),
            ("Rumänisches KH",   3, 8, 10, 120),
            ("Beinpresse",        3, 10, 15, 90),
            ("Wadenheben",        4, 12, 20, 60)
        ]
        for (i, e) in legsExercises.enumerated() {
            ctx.insert(Exercise(name: e.0, sets: e.1, repsMin: e.2, repsMax: e.3,
                                restSeconds: e.4, orderIndex: i, day: legs))
        }

        return plan
    }

    /// Synthesizes one fully-logged completed session for `day`. Each set gets a
    /// per-exercise weight (rough realistic values) and the rep midpoint.
    private static func seedCompletedSession(for day: TrainingDay, daysAgo: Int, in ctx: ModelContext) {
        let startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let session = WorkoutSession(
            startTime: startDate,
            endTime: startDate.addingTimeInterval(50 * 60),
            durationMinutes: 50,
            exerciseCount: day.exercises.count,
            isCompleted: true,
            dayName: day.name,
            day: day
        )
        ctx.insert(session)

        var setOffset = 0

        for exercise in day.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let weight = mockWeight(for: exercise.name)
            let reps   = (exercise.repsMin + exercise.repsMax) / 2
            for setIdx in 0..<exercise.sets {
                let log = ExerciseLog(
                    date: startDate.addingTimeInterval(Double(setOffset) * 90),
                    setIndex: setIdx,
                    weight: weight,
                    reps: reps,
                    rir: 2.0,
                    exercise: exercise,
                    session: session
                )
                ctx.insert(log)
                setOffset += 1
            }
        }
        // DEL-221: Aggregate ueber den einen Schreiber statt mitzuzaehlen.
        // Der Preview-Seed rechnete die Summen frueher parallel zum Insert-
        // Loop mit — eine sechste Kopie der Formel, die stillschweigend
        // haette abweichen koennen.
        session.recomputeTotals()
    }

    /// Rough realistic weights for the seeded PPL exercises — used only by the
    /// preview; the live app reads `Exercise.suggestedWeight` and historical logs.
    private static func mockWeight(for exerciseName: String) -> Double {
        let lower = exerciseName.lowercased()
        if lower.contains("kreuzheben")   { return 120 }
        if lower.contains("kniebeuge")    { return 100 }
        if lower.contains("rumän")       { return 80  }
        if lower.contains("bank")         { return 80  }
        if lower.contains("rudern")       { return 70  }
        if lower.contains("schulter") || lower.contains("drücken") { return 50 }
        if lower.contains("klimmzug")     { return 0   }   // bodyweight
        if lower.contains("dip")          { return 0   }
        if lower.contains("pushdown")     { return 25  }
        if lower.contains("curl")         { return 14  }
        if lower.contains("beinpresse")   { return 140 }
        if lower.contains("waden")        { return 60  }
        return 40
    }

    /// A small, opinionated subset of exercise templates so the picker isn't empty
    /// in previews. Mix of compound system lifts (`isSystemCompound: true`) and
    /// accessories — covers all major muscle groups.
    private static func seedSampleTemplates(in ctx: ModelContext) {
        let templates: [(String, Equipment, MuscleGroup, Bool)] = [
            ("Bankdrücken",      .barbell,    .chest,      true),
            ("Kniebeuge",         .barbell,    .quads,      true),
            ("Kreuzheben",        .barbell,    .back,       true),
            ("Schulterdrücken",  .barbell,    .shoulders,  true),
            ("Langhantel-Rudern", .barbell,    .back,       true),
            ("Klimmzüge",        .bodyweight, .back,       false),
            ("Dips",              .bodyweight, .triceps,    false),
            ("Bizeps-Curls",      .dumbbell,   .biceps,     false),
            ("Trizeps-Pushdown",  .cable,      .triceps,    false),
            ("Beinpresse",        .machine,    .quads,      false),
            ("Plank",             .bodyweight, .core,       false)
        ]
        for (name, equipment, muscle, isCompound) in templates {
            let template = ExerciseTemplate(
                name: name,
                equipment: equipment,
                primaryMuscle: muscle,
                isCustom: false,
                difficultyLevel: .intermediate,
                isSystemCompound: isCompound,
                isTimeBased: name == "Plank"
            )
            ctx.insert(template)
        }
    }
}
#endif
