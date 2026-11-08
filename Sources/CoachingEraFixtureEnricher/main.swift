// Coaching-era SQLite fixture enricher for WP1 of DEL-migration-proof ticket.
//
// Prerequisite: CoachingEraFixtureGenerator must have already written the stub
// SQLite (UserBodyProfile with coaching-era schema) at the given path.
//
// This target opens that same file with a schema that keeps the local
// UserBodyProfile shadow (historic = still has coaching columns) plus ALL other
// current DeltiqData entity types — causing SwiftData to create their tables in
// the same store. It then writes one representative record per entity type.
//
// Result: a single SQLite where
//   • UserBodyProfile has the PRE-ROLLBACK schema (coaching columns present)
//   • all 16 other entities use the CURRENT production schema
//
// When the migration test opens this file with Schema(AppSchema.types)
// (which references DeltiqData.UserBodyProfile — no coaching columns), SwiftData
// performs the lightweight migration on UserBodyProfile only and leaves every
// other entity intact.
//
// Usage: swift run CoachingEraFixtureEnricher <path>
// On Windows (SwiftData unavailable) this compiles but exits immediately.
import Foundation

#if canImport(SwiftData)
import SwiftData
import DeltiqData
import DeltiqCore

// Local mirror of DeltiqData.UserBodyProfile at the coaching era (pre-d3b387d).
// Class name must match the production class name exactly — SwiftData entity
// names equal the unqualified Swift class name, so both this local class and
// DeltiqData.UserBodyProfile map to the same SQLite entity "UserBodyProfile".
//
// This local class *shadows* DeltiqData.UserBodyProfile within this file.
// All other entity references in the Schema([...]) list resolve to their
// DeltiqData types (no shadowing for those), producing the mixed-schema fixture.
@Model
private final class UserBodyProfile {

    // MARK: - Current stored properties (unchanged from production DeltiqData)

    var birthDate: Date
    var heightCm: Double
    var profile: BodyFormulaProfile
    var goalWeightKg: Double? = nil

    var dailyCalorieGoalKcal: Int? = nil
    var dailyProteinGoalG: Double? = nil
    var dailyCarbGoalG: Double? = nil
    var dailyFatGoalG: Double? = nil

    var environment: EnvironmentType
    var firstName: String? = nil

    var coachingToneRaw: String = "analytical"
    var trainingGoalRaw: String = "hybrid"

    var activeDashboardWidgetsRaw: [String] = [
        "nextWorkout", "runCoachCard", "cardioPace", "raceProgressCard", "coachingInsight"
    ]
    var heroMetricSlotsRaw: [String] = ["weight", "bodyFat"]

    var equipmentPreferencesRaw: [String] = []
    var equipmentAvailableItemsRaw: [String] = []
    var equipmentUnavailableItemsRaw: [String] = []
    var equipmentUnknownItemsRaw: [String] = []
    var equipmentItemCountsRaw: [String] = []
    var equipmentProfileConfirmedComplete: Bool = false

    var weeklyWorkoutGoal: Int = 1
    var experienceTrackRaw: String? = nil

    var baselineDate: Date? = nil
    var baselineSourceRaw: String? = nil
    var baselineSafetyStatusRaw: String? = nil
    var baselineVersion: Int? = nil
    var baselinePushUpVariantRaw: String? = nil
    var baselinePushUpCleanReps: Int? = nil
    var baselineChairSquatCleanReps: Int? = nil
    var baselineChairSquatDurationSeconds: Int? = nil
    var baselinePullVariantRaw: String? = nil
    var baselinePullCleanReps: Int? = nil
    var baselinePullLoadKg: Double? = nil
    var baselinePullRir: Double? = nil
    var baselinePlankSeconds: Int? = nil
    var baselineCardioAnswerRaw: String? = nil
    var baselinePushSelfAssessmentRaw: String? = nil
    var baselineLegsSelfAssessmentRaw: String? = nil
    var baselinePullSelfAssessmentRaw: String? = nil
    var baselineDesiredFirstWeekIntensityRaw: String? = nil

    var mealPlanDietaryStyleRaw: String = "omnivor"
    var mealPlanRequiresHalal: Bool = false
    var mealPlanAllergenExclusionsRaw: [String] = []
    var mealPlanExcludedRecipeIDsRaw: [String] = []

    // MARK: - Coaching properties removed in rollback d3b387d

    var cardioCoachingEnabled: Bool = false
    var cardioWidgetUserConfigured: Bool = false
    var cardioGoalRaw: String = "generalFitness"
    var cardioRaceDate: Date? = nil
    var current5kReferenceSeconds: Int? = nil
    var weeklyBaseVolumeKm: Double? = nil
    var maxHeartRateBpm: Int? = nil
    var cardioFeasibilityDismissedFingerprint: String? = nil
    var cardioPlanAdjustmentFingerprint: String? = nil
    var missedRunHintDismissedFingerprint: String? = nil
    var cardioAdjustmentCardDismissedFingerprint: String? = nil
    var cardioCoachingEnabledAt: Date? = nil
    var raceProgressLastAnalyzedAt: Date? = nil
    var raceProgressLastAnalyzedConfigurationFingerprint: String? = nil
    var raceProgressDismissedFingerprint: String? = nil

    init(birthDate: Date, heightCm: Double, profile: BodyFormulaProfile, environment: EnvironmentType) {
        self.birthDate = birthDate
        self.profile = profile
        self.heightCm = heightCm
        self.environment = environment
    }
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/deltiq_legacy_fixture.sqlite"

guard FileManager.default.fileExists(atPath: outputPath) else {
    print("CoachingEraFixtureEnricher: stub not found at \(outputPath) — run CoachingEraFixtureGenerator first.")
    exit(1)
}

do {
    let url = URL(fileURLWithPath: outputPath)

    // Schema mixes the LOCAL UserBodyProfile (historic = coaching columns present)
    // with all other entities from DeltiqData (current production schema).
    // SwiftData opens the existing stub and creates tables for missing entities.
    let schema = Schema([
        UserBodyProfile.self,       // local class = historic schema
        BodyMeasurement.self,
        TrainingPlan.self,
        TrainingDay.self,
        Exercise.self,
        ExerciseLog.self,
        WorkoutSession.self,
        ExerciseTemplate.self,
        WaterEntry.self,
        PersonalRecordEntry.self,
        Gear.self,
        PeriodicCheckIn.self,
        FoodCatalogEntry.self,
        MealEntry.self,
        MealItem.self,
        DailyMealPlan.self,
        PlannedMealAssignment.self
    ])
    let config = ModelConfiguration(url: url)
    let container = try ModelContainer(for: schema, configurations: config)
    let ctx = ModelContext(container)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let now = formatter.date(from: "2024-06-15T10:00:00Z")!

    // --- TrainingPlan + TrainingDay + Exercise + WorkoutSession + ExerciseLog ---
    let plan = TrainingPlan(
        name: "Hypertrophie 12 Wochen",
        programType: "strength",
        weeks: 12,
        isActive: true,
        targetEnvironment: .gym
    )
    ctx.insert(plan)

    let day = TrainingDay(name: "Push A", weekday: 1, type: .custom, plan: plan)
    ctx.insert(day)

    let exercise = Exercise(
        name: "Bankdrücken",
        sets: 4,
        repsMin: 6,
        repsMax: 10,
        day: day
    )
    ctx.insert(exercise)

    let session = WorkoutSession(
        startTime: now,
        endTime: now.addingTimeInterval(3600),
        isCompleted: true,
        day: day
    )
    ctx.insert(session)

    let log = ExerciseLog(
        setIndex: 0,
        weight: 100.0,
        reps: 8,
        rir: 2,
        exercise: exercise,
        session: session
    )
    ctx.insert(log)

    // --- ExerciseTemplate ---
    let template = ExerciseTemplate(
        name: "Bankdrücken",
        equipment: .barbell,
        primaryMuscle: .chest
    )
    ctx.insert(template)

    // --- BodyMeasurement ---
    let measurement = BodyMeasurement(
        ageYearsAtMeasurement: 34,
        weightKg: 80.0,
        waistCm: 85.0
    )
    ctx.insert(measurement)

    // --- MealEntry + MealItem ---
    let meal = MealEntry(date: now, mealType: .lunch)
    ctx.insert(meal)

    let nutrients = NutrientValues(kcal: 350, proteinG: 30, carbsG: 10, fatG: 15)
    let item = MealItem(
        catalogID: "chicken_breast_raw",
        nameSnapshot: "Hähnchenbrust",
        quantity: 200,
        unit: .gram,
        nutrients: nutrients,
        meal: meal
    )
    ctx.insert(item)

    // --- WaterEntry ---
    let water = WaterEntry(date: now, amountMl: 500)
    ctx.insert(water)

    // --- PersonalRecordEntry ---
    let pr = PersonalRecordEntry(
        date: now,
        exerciseName: "Bankdrücken",
        exerciseTemplateID: nil,
        kindRaw: "heaviestWeight",
        value: 100.0,
        previousValue: 95.0,
        weightKg: 100.0,
        reps: 8,
        session: session
    )
    ctx.insert(pr)

    // --- Gear ---
    let gear = Gear(name: "Nike Metcon 9", type: .shoe)
    ctx.insert(gear)

    // --- PeriodicCheckIn ---
    let checkIn = PeriodicCheckIn(date: now)
    ctx.insert(checkIn)

    // --- DailyMealPlan + PlannedMealAssignment ---
    let mealPlan = DailyMealPlan(date: now, generatorWarning: nil)
    ctx.insert(mealPlan)

    let assignment = PlannedMealAssignment(
        recipeID: "test-recipe-001",
        mealType: .lunch,
        portionMultiplier: 1.0
    )
    ctx.insert(assignment)

    try ctx.save()
    print("CoachingEraFixtureEnricher: all 17 entity types written to \(outputPath)")
} catch {
    print("CoachingEraFixtureEnricher error: \(error)")
    exit(1)
}
#else
print("SwiftData unavailable on this platform — no enrichment performed.")
#endif
