import Foundation

// Privacy: the input values and the generated insight text may contain
// nutrition data — never print/debugPrint/log them anywhere in this module.

/// Already-computed facts for ONE day, handed in by the caller (`FitnessAppUI`,
/// from `NutritionDayAggregator.dailyTotal` + `UserBodyProfile`'s goal
/// fields). Deliberately plain `Double?`/`Int?` instead of `NutrientValues`/
/// `UserBodyProfile` — `FitnessAppAI` has no dependency on `FitnessAppCore`/
/// `FitnessAppData` on purpose (see `Package.swift`), and this struct is the
/// seam: the AI never sees, and can never reach back into, SwiftData.
///
/// A `nil` goal means "not set, user never configured it" — never "zero" or
/// "not reached". See `NutritionInsightGenerator.prompt(for:)`.
public struct NutritionInsightInput: Sendable, Equatable {
    public let totalKcal: Double
    public let totalProteinG: Double
    public let totalCarbsG: Double
    public let totalFatG: Double
    public let calorieGoalKcal: Int?
    public let proteinGoalG: Double?
    public let carbGoalG: Double?
    public let fatGoalG: Double?

    public init(
        totalKcal: Double,
        totalProteinG: Double,
        totalCarbsG: Double,
        totalFatG: Double,
        calorieGoalKcal: Int?,
        proteinGoalG: Double?,
        carbGoalG: Double?,
        fatGoalG: Double?
    ) {
        self.totalKcal = totalKcal
        self.totalProteinG = totalProteinG
        self.totalCarbsG = totalCarbsG
        self.totalFatG = totalFatG
        self.calorieGoalKcal = calorieGoalKcal
        self.proteinGoalG = proteinGoalG
        self.carbGoalG = carbGoalG
        self.fatGoalG = fatGoalG
    }
}

/// Builds a general, non-medical coaching text from an already-computed day
/// (`NutritionInsightInput`) via `NutritionAIService`. Pure over its input —
/// no SwiftData access, no nutrient recomputation: every number the model is
/// given comes straight from the caller, and a goal that was never set is
/// marked "not set" in the prompt instead of being omitted or turned into a
/// number, so the model can't invent or imply one.
public struct NutritionInsightGenerator: Sendable {
    private let service: NutritionAIService

    public init(service: NutritionAIService = NutritionAIService()) {
        self.service = service
    }

    public func availability() -> NutritionAIAvailability {
        service.availability()
    }

    /// Throws `NutritionAIError.unavailable(_)` (propagated from `service`,
    /// without calling the model) when `availability()` isn't `.available`.
    public func generateInsight(for input: NutritionInsightInput) async throws -> String {
        try await service.generateText(instructions: Self.instructions, prompt: Self.prompt(for: input))
    }

    static let instructions = """
    You summarize one day's already-computed nutrition numbers for the user \
    in their own language. Use ONLY the numbers given to you below — never \
    calculate, estimate, convert, or guess any number yourself. Some goals \
    are marked "not set": for those, never state a number and never say the \
    goal was reached or missed — simply don't mention that goal at all. Give \
    only brief, general, non-medical observations and encouragement. Never \
    give a diagnosis, a treatment recommendation, or any other medical advice.
    """

    /// Deterministic, side-effect-free prompt text — the single place that
    /// decides what the model is allowed to see. A `nil` goal always becomes
    /// the literal marker below, never a number (Step 1 test asserts this).
    static func prompt(for input: NutritionInsightInput) -> String {
        """
        Today's totals:
        Calories: \(Int(input.totalKcal)) kcal
        Protein: \(Int(input.totalProteinG)) g
        Carbs: \(Int(input.totalCarbsG)) g
        Fat: \(Int(input.totalFatG)) g

        Goals:
        Calorie goal: \(goalText(input.calorieGoalKcal.map(Double.init), unit: "kcal"))
        Protein goal: \(goalText(input.proteinGoalG, unit: "g"))
        Carb goal: \(goalText(input.carbGoalG, unit: "g"))
        Fat goal: \(goalText(input.fatGoalG, unit: "g"))
        """
    }

    private static let notSetMarker = "not set"

    private static func goalText(_ value: Double?, unit: String) -> String {
        guard let value else { return notSetMarker }
        return "\(Int(value)) \(unit)"
    }
}
