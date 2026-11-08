// Coaching-era SQLite fixture generator for WP1 of DEL-migration-proof ticket.
// Creates a real SwiftData store with the pre-rollback UserBodyProfile schema
// (all current properties + 15 coaching properties that were removed in d3b387d)
// so the production schema can prove lightweight migration via WP2/WP3 tests.
//
// Usage: swift run CoachingEraFixtureGenerator <output-path>
// On Windows (SwiftData unavailable) this compiles but exits immediately.
import Foundation

#if canImport(SwiftData)
import SwiftData
import DeltiqCore

// Mirror of DeltiqData.UserBodyProfile at the coaching era (pre-d3b387d).
// Class name must match production — SwiftData entity names are unqualified.
// This target does NOT import DeltiqData to avoid the naming conflict;
// DeltiqCore is imported for BodyFormulaProfile / EnvironmentType so the
// SQLite column encoding is identical to the production schema.
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

    // Coaching-era widget list (includes removed runCoachCard / raceProgressCard)
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
    // Verified against git show a83c3b8:Sources/DeltiqData/UserBodyProfile.swift
    // All 16 properties present: 15 cardio/race + enduranceModalityRaw

    var enduranceModalityRaw: String? = nil          // EnduranceModality.rawValue
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
        self.heightCm = heightCm
        self.profile = profile
        self.environment = environment
    }
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/deltiq_legacy_fixture.sqlite"

do {
    let url = URL(fileURLWithPath: outputPath)
    // Start fresh — generator is idempotent
    try? FileManager.default.removeItem(at: url)

    let schema = Schema([UserBodyProfile.self])
    let config = ModelConfiguration(url: url)
    let container = try ModelContainer(for: schema, configurations: config)
    let ctx = ModelContext(container)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let profile = UserBodyProfile(
        birthDate: formatter.date(from: "1990-01-15T00:00:00Z")!,
        heightCm: 178.0,
        profile: .male,
        environment: .gym
    )
    profile.firstName = "Max"
    profile.goalWeightKg = 80.0
    profile.weeklyWorkoutGoal = 3
    profile.experienceTrackRaw = "intermediate"

    // Coaching fields: representative coaching-era values (all 16 removed properties)
    profile.enduranceModalityRaw = "running"
    profile.cardioCoachingEnabled = true
    profile.cardioGoalRaw = "race"
    profile.cardioRaceDate = formatter.date(from: "2027-04-30T00:00:00Z")
    profile.current5kReferenceSeconds = 1800
    profile.weeklyBaseVolumeKm = 25.0
    profile.maxHeartRateBpm = 185

    ctx.insert(profile)
    try ctx.save()
    print("Legacy coaching-era fixture created at \(outputPath)")
} catch {
    print("CoachingEraFixtureGenerator error: \(error)")
    exit(1)
}
#else
print("SwiftData unavailable on this platform — no fixture created.")
#endif
