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
    // I2: the locale actually driving what language the model is told to
    // answer in — same explicit-locale reasoning as `NutritionAIService`
    // itself (see its doc comment), so the UI's `\.environment(\.locale)`
    // always wins over `.current`.
    private let locale: Locale

    public init(service: NutritionAIService = NutritionAIService(), locale: Locale = .current) {
        self.service = service
        self.locale = locale
    }

    public func availability() -> NutritionAIAvailability {
        service.availability()
    }

    /// Throws `NutritionAIError.unavailable(_)` (propagated from `service`,
    /// without calling the model) when `availability()` isn't `.available`.
    /// I5 safety net: also throws `.generationFailed` when the generated text
    /// contains any number that doesn't exactly match one of the real input
    /// numbers (totals + any goals that were actually set) — a fabricated
    /// number is treated as a failed generation, never shown.
    public func generateInsight(for input: NutritionInsightInput) async throws -> String {
        let text = try await service.generateText(instructions: Self.instructions(for: locale), prompt: Self.prompt(for: input))
        guard Self.onlyContainsVerifiedNumbers(text, input: input) else {
            throw NutritionAIError.generationFailed
        }
        return text
    }

    private static let baseInstructions = """
    You summarize one day's already-computed nutrition numbers for the user. \
    Use ONLY the numbers given to you below — never calculate, estimate, \
    convert, or guess any number yourself. Some goals are marked "not set": \
    for those, never state a number and never say the goal was reached or \
    missed — simply don't mention that goal at all. Give only brief, general, \
    non-medical observations and encouragement. Never give a diagnosis, a \
    treatment recommendation, or any other medical advice.
    """

    /// I2 fix: a plain "respond in the user's language" instruction left the
    /// actual target language to the model to infer, and the `Locale` passed
    /// into this type/`NutritionAIService` was previously used only for the
    /// availability check, never told to the model — so a DE/TR user could
    /// get an English paragraph. This states the language explicitly, by
    /// name, derived from the real locale.
    static func instructions(for locale: Locale) -> String {
        "\(languageDirective(for: locale)) \(baseInstructions)"
    }

    static func languageDirective(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        let languageName = Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
        return "Respond only in \(languageName)."
    }

    // MARK: I5 — code-level check that no number was invented

    /// Every integer that appears in `text` must be one of the real input
    /// numbers (the four totals, plus any goal that was actually set) — the
    /// only hard guarantee that the model didn't fabricate or hallucinate a
    /// nutrient value or a not-set goal, on top of the instructions above.
    static func onlyContainsVerifiedNumbers(_ text: String, input: NutritionInsightInput) -> Bool {
        let allowed = allowedNumbers(for: input)
        return numbers(in: text).allSatisfy { allowed.contains($0) }
    }

    private static func allowedNumbers(for input: NutritionInsightInput) -> Set<Int> {
        var numbers: Set<Int> = [
            safeInt(input.totalKcal), safeInt(input.totalProteinG),
            safeInt(input.totalCarbsG), safeInt(input.totalFatG)
        ]
        if let goal = input.calorieGoalKcal { numbers.insert(goal) }
        if let goal = input.proteinGoalG { numbers.insert(safeInt(goal)) }
        if let goal = input.carbGoalG { numbers.insert(safeInt(goal)) }
        if let goal = input.fatGoalG { numbers.insert(safeInt(goal)) }
        return numbers
    }

    private static func numbers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    /// Deterministic, side-effect-free prompt text — the single place that
    /// decides what the model is allowed to see. A `nil` goal always becomes
    /// the literal marker below, never a number (Step 1 test asserts this).
    static func prompt(for input: NutritionInsightInput) -> String {
        """
        Today's totals:
        Calories: \(safeInt(input.totalKcal)) kcal
        Protein: \(safeInt(input.totalProteinG)) g
        Carbs: \(safeInt(input.totalCarbsG)) g
        Fat: \(safeInt(input.totalFatG)) g

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
        return "\(safeInt(value)) \(unit)"
    }

    /// M1 fix: `Int(Double)` traps on NaN/infinity/out-of-range magnitudes.
    /// Goals/quantities have no enforced upper bound elsewhere in the app, so
    /// an extreme value must not crash the day view. Mirrors the EXACT guard
    /// `Double.formattedRIR` already uses in `DoubleFormatting.swift` (not
    /// reused directly since `FitnessAppAI` deliberately has no dependency on
    /// `FitnessAppCore` — see `NutritionInsightInput`'s doc comment above).
    /// `Double(Int.max)` itself rounds UP to 2^63 (not exactly representable),
    /// so clamping a value via `Int(min(value, Double(Int.max)))` would still
    /// crash — the bound must only ever be used as a comparison, never
    /// converted back to `Int`.
    private static func safeInt(_ value: Double) -> Int {
        guard value.isFinite, abs(value) < Double(Int.max) else { return 0 }
        return Int(value)
    }
}
