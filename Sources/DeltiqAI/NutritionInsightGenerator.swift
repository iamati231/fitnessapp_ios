import Foundation
import NaturalLanguage

// Privacy: the input values and the generated insight text may contain
// nutrition data — never print/debugPrint/log them anywhere in this module.

/// Already-computed facts for ONE day, handed in by the caller (`DeltiqUI`,
/// from `NutritionDayAggregator.dailyTotal` + `UserBodyProfile`'s goal
/// fields). Deliberately plain `Double?`/`Int?` instead of `NutrientValues`/
/// `UserBodyProfile` — `DeltiqAI` has no dependency on `DeltiqCore`/
/// `DeltiqData` on purpose (see `Package.swift`), and this struct is the
/// seam: the AI never sees, and can never reach back into, SwiftData.
///
/// A `nil` goal means "not set, user never configured it" — never "zero" or
/// "not reached". See `NutritionInsightGenerator.prompt(for:)`.
public struct NutritionInsightInput: Sendable, Equatable {
    /// OFF-01: `nil` bedeutet **unbekannt** (mindestens eine Position des
    /// Tages hat fuer diese Dimension keinen Wert, z. B. ein online
    /// importiertes Open-Food-Facts-Lebensmittel ohne Fett-Angabe). Der
    /// Prompt schreibt dann "unknown" statt einer erfundenen 0 und laesst
    /// Prozent/Restmenge fuer diese Dimension weg — das Modell soll daraus
    /// keine Aussage ableiten.
    public let totalKcal: Double?
    public let totalProteinG: Double?
    public let totalCarbsG: Double?
    public let totalFatG: Double?
    public let calorieGoalKcal: Int?
    public let proteinGoalG: Double?
    public let carbGoalG: Double?
    public let fatGoalG: Double?
    public let calorieGoalProgress: GoalProgress?
    public let proteinGoalProgress: GoalProgress?
    public let carbGoalProgress: GoalProgress?
    public let fatGoalProgress: GoalProgress?

    /// Deterministic percent-of-goal + remaining-amount for ONE nutrient,
    /// pre-computed by the caller (`NutritionDayView`, via the single shared
    /// `NutritionCalculations.goalProgress` that also drives the progress-bar
    /// UI — `DeltiqAI` has no dependency on `DeltiqCore` on purpose,
    /// see the doc comment above, so this plain DTO carries only the two
    /// numbers across, never the calculation itself). `nil` exactly when the
    /// corresponding goal is `nil` — a model must never see a percentage for
    /// a goal that was never set.
    public struct GoalProgress: Sendable, Equatable {
        public let percent: Int
        /// Floored at 0; use `overage` for the exceeded amount.
        public let remaining: Double
        /// How much current exceeds the goal (current − goal); 0 when not exceeded.
        public let overage: Double

        public init(percent: Int, remaining: Double, overage: Double = 0) {
            self.percent = percent
            self.remaining = remaining
            self.overage = overage
        }
    }

    /// Hour of day (0–23) for the selected date; `nil` for past days.
    /// Tells the model whether the day is still in progress so it doesn't
    /// evaluate a mid-afternoon snapshot as an end-of-day result.
    public let timeOfDayHour: Int?

    public init(
        totalKcal: Double?,
        totalProteinG: Double?,
        totalCarbsG: Double?,
        totalFatG: Double?,
        calorieGoalKcal: Int?,
        proteinGoalG: Double?,
        carbGoalG: Double?,
        fatGoalG: Double?,
        calorieGoalProgress: GoalProgress? = nil,
        proteinGoalProgress: GoalProgress? = nil,
        carbGoalProgress: GoalProgress? = nil,
        fatGoalProgress: GoalProgress? = nil,
        timeOfDayHour: Int? = nil
    ) {
        self.totalKcal = totalKcal
        self.totalProteinG = totalProteinG
        self.totalCarbsG = totalCarbsG
        self.totalFatG = totalFatG
        self.calorieGoalKcal = calorieGoalKcal
        self.proteinGoalG = proteinGoalG
        self.carbGoalG = carbGoalG
        self.fatGoalG = fatGoalG
        self.calorieGoalProgress = calorieGoalProgress
        self.proteinGoalProgress = proteinGoalProgress
        self.carbGoalProgress = carbGoalProgress
        self.fatGoalProgress = fatGoalProgress
        self.timeOfDayHour = timeOfDayHour
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
        let raw = try await service.generateText(instructions: Self.instructions(for: locale), prompt: Self.prompt(for: input, locale: locale))
        guard Self.onlyContainsVerifiedNumbers(raw, input: input) else {
            throw NutritionAIError.generationFailed
        }
        // Device-Bugreport ("KI-Analyse bleibt auf Englisch"): reject wrong-language output.
        guard Self.matchesRequestedLanguage(raw, locale: locale) else {
            throw NutritionAIError.generationFailed
        }
        // Rejects "over goal" language when no goal was actually exceeded (Cases A/B).
        guard Self.matchesDirection(raw, input: input, locale: locale) else {
            throw NutritionAIError.generationFailed
        }
        // Strip any residual markdown the model inserted despite instructions.
        return Self.stripMarkdown(raw)
    }

    private static let baseInstructions = """
    You summarize one day's already-computed nutrition numbers for the user. \
    These totals are ACTUAL consumed amounts — what was logged and eaten, not \
    planned or target values. \
    Use ONLY the numbers given to you — never calculate, estimate, convert, or \
    guess any number yourself. Any value stated as "unknown" means the data is \
    incomplete: never treat it as zero, never mention a number for it, never \
    claim the goal was reached or missed. \
    Goals marked "not set": never mention a number or outcome for them. \
    DIRECTION RULES (critical — read carefully): \
    A line marked [NOT_MET] means the user is UNDER the target — they have NOT \
    yet reached the goal. NEVER use "over goal", "exceeded", "above target", or \
    any above-direction language for a [NOT_MET] line. \
    A line marked [EXCEEDED] means the user is OVER the target — they consumed \
    MORE than the goal. NEVER say "not reached" for an [EXCEEDED] line. \
    The phrase after "over goal" tells you exactly by how much the goal was \
    exceeded — repeat that number only. \
    When a progress line gives a percentage, that percentage — never your own \
    judgment — decides tone: below ~50% with meaningful amount remaining, \
    describe as in-progress; at/above 100% a positive tone is appropriate. \
    If the prompt includes a "Day context" line saying the day is still in \
    progress (morning or afternoon), do not evaluate unmet goals as failures — \
    say "so far" or "at this point" instead of implying the day is over. \
    Give exactly 1 key observation and at most 2 short practical tips — \
    1 to 3 sentences total. Do not list or repeat all four nutrient values in \
    sequence. Do not use phrases like "great job", "super", "excellent", \
    "fantastic", "amazing" for routine progress. \
    No markdown — do not use **, *, #, ##, or any other markdown formatting. \
    Give only brief, general, non-medical observations. Never give a diagnosis, \
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

    /// Only the app's three supported languages (Deutsch/Englisch/Tuerkisch,
    /// see Global Constraints) are ever named explicitly - any other locale
    /// falls back to English, matching `NutritionAIAvailability`'s own
    /// supported-language gate (unsupported locales never reach this call in
    /// the first place) and `NutritionAIService.extractionInstructions`'s
    /// identical convention for the meal-text extractor.
    static func targetLanguageCode(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        return ["de", "tr"].contains(code) ? code : "en"
    }

    static func languageDirective(for locale: Locale) -> String {
        let code = targetLanguageCode(for: locale)
        let languageName = Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
        // For German: also enforce informal "du" — small on-device models default to "Sie".
        let extra = code == "de" ? " Verwende 'du' (nicht 'Sie')." : ""
        return "Respond only in \(languageName).\(extra)"
    }

    /// Device-Bugreport ("KI-Analyse bleibt auf Englisch"): robust, code-level
    /// check that the generated text is actually written in the requested
    /// language - the last line of defence described at the `generateInsight`
    /// call site above. `NLLanguageRecognizer` needs no network/model access
    /// and is deterministic enough for the short paragraphs this generator
    /// produces. A `nil`/undetermined result (very short or ambiguous text)
    /// is let through rather than blocked - this guard exists to catch a
    /// clearly wrong language, not to second-guess every borderline case.
    static func matchesRequestedLanguage(_ text: String, locale: Locale) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let detected = recognizer.dominantLanguage else { return true }
        return detected.rawValue == targetLanguageCode(for: locale)
    }

    // MARK: Direction guard — rejects "over goal" language for under-goal results

    /// Returns false when the generated text uses exceeded-direction words (e.g.
    /// "über Ziel") but no goal was actually exceeded. This catches the P0 regression
    /// where the on-device model reversed the direction of an under-goal nutrient.
    static func matchesDirection(_ text: String, input: NutritionInsightInput, locale: Locale) -> Bool {
        let hasExceededGoal = [input.calorieGoalProgress, input.proteinGoalProgress,
                               input.carbGoalProgress, input.fatGoalProgress]
            .compactMap { $0 }.contains { $0.overage > 0 }
        guard !hasExceededGoal else { return true }
        let overGoalWord = PromptStrings.forLanguageCode(targetLanguageCode(for: locale)).overGoal
        return !text.localizedCaseInsensitiveContains(overGoalWord)
    }

    /// Strips residual markdown that small on-device models occasionally insert
    /// despite the "No markdown" instruction. Operates on the already-validated text.
    static func stripMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "# ", with: "")
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
        // OFF-01: eine unbekannte Tagessumme steht im Prompt als "unknown",
        // taucht also nicht als Zahl auf — sie gehoert nicht in die Menge der
        // erlaubten Zahlen (sonst waere eine erfundene 0 "zulaessig").
        var numbers: Set<Int> = Set(
            [safeInt(input.totalKcal), safeInt(input.totalProteinG),
             safeInt(input.totalCarbsG), safeInt(input.totalFatG)].compactMap { $0 }
        )
        if let goal = input.calorieGoalKcal { numbers.insert(goal) }
        if let goal = input.proteinGoalG.map(safeInt) { numbers.insert(goal) }
        if let goal = input.carbGoalG.map(safeInt) { numbers.insert(goal) }
        if let goal = input.fatGoalG.map(safeInt) { numbers.insert(goal) }
        // The percent/remaining/overage facts stated in the "Progress toward goals"
        // block are real, pre-computed numbers too — the model repeating one
        // back verbatim is not a fabrication (see `prompt(for:)` below).
        for progress in [input.calorieGoalProgress, input.proteinGoalProgress, input.carbGoalProgress, input.fatGoalProgress] {
            guard let progress else { continue }
            numbers.insert(progress.percent)
            numbers.insert(safeInt(progress.remaining))
            if progress.overage > 0 { numbers.insert(safeInt(progress.overage)) }
        }
        return numbers
    }

    private static func numbers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    /// Device-Bugreport ("KI-Analyse bleibt auf Englisch"): the prompt's own
    /// words used to be hardcoded English regardless of `locale` - a far
    /// stronger signal to a small on-device model than the one-line
    /// "Respond only in X" instruction above, since models tend to mirror
    /// the dominant language of their input context. Every label is now
    /// drawn from `PromptStrings.forLanguageCode`, keyed by the SAME target
    /// language the instructions already use (`targetLanguageCode`), so the
    /// whole prompt - not just the instruction - is consistently in the
    /// requested language.
    private struct PromptStrings {
        let totalsHeading, calories, protein, carbs, fat: String
        let goalsHeading, calorieGoal, proteinGoal, carbGoal, fatGoal: String
        let progressHeading, of, goalWord, reached, remaining, overGoal: String
        let unknown, notSet: String
        // Status label appended to a progress line when the goal was exceeded
        // (percent >= 100) — makes the fact unambiguous for the model.
        let exceeded: String
        // Symmetric counterpart to `exceeded` — appended when goal is NOT yet reached.
        let notMet: String
        // Time-of-day context labels (no times/numbers — avoids allowedNumbers clash).
        let dayContextHeading, dayMorning, dayMidday, dayAfternoon, dayEvening: String

        static func forLanguageCode(_ code: String) -> PromptStrings {
            switch code {
            case "de":
                return PromptStrings(
                    totalsHeading: "Heutige Summen:", calories: "Kalorien", protein: "Protein",
                    carbs: "Kohlenhydrate", fat: "Fett",
                    goalsHeading: "Ziele:", calorieGoal: "Kalorienziel", proteinGoal: "Proteinziel",
                    carbGoal: "Kohlenhydratziel", fatGoal: "Fettziel",
                    progressHeading: "Fortschritt zu den Zielen:", of: "von", goalWord: "Ziel",
                    reached: "erreicht", remaining: "verbleibend", overGoal: "über Ziel",
                    unknown: "unbekannt", notSet: "nicht gesetzt",
                    exceeded: "EXCEEDED", notMet: "NICHT_ERREICHT",
                    dayContextHeading: "Tageskontext:",
                    dayMorning: "Morgen — Tag noch in Gange",
                    dayMidday: "Mittag — Tag noch in Gange",
                    dayAfternoon: "Nachmittag — Tag noch in Gange",
                    dayEvening: "Abend — Tag fast abgeschlossen"
                )
            case "tr":
                return PromptStrings(
                    totalsHeading: "Bugünün toplamları:", calories: "Kalori", protein: "Protein",
                    carbs: "Karbonhidrat", fat: "Yağ",
                    goalsHeading: "Hedefler:", calorieGoal: "Kalori hedefi", proteinGoal: "Protein hedefi",
                    carbGoal: "Karbonhidrat hedefi", fatGoal: "Yağ hedefi",
                    progressHeading: "Hedeflere doğru ilerleme:", of: "/", goalWord: "hedef",
                    reached: "ulaşıldı", remaining: "kaldı", overGoal: "hedef üstünde",
                    unknown: "bilinmiyor", notSet: "belirlenmedi",
                    exceeded: "EXCEEDED", notMet: "ULAŞILMADI",
                    dayContextHeading: "Gün bağlamı:",
                    dayMorning: "Sabah — gün devam ediyor",
                    dayMidday: "Öğle — gün devam ediyor",
                    dayAfternoon: "Öğleden sonra — gün devam ediyor",
                    dayEvening: "Akşam — gün neredeyse bitti"
                )
            default:
                return PromptStrings(
                    totalsHeading: "Today's totals:", calories: "Calories", protein: "Protein",
                    carbs: "Carbs", fat: "Fat",
                    goalsHeading: "Goals:", calorieGoal: "Calorie goal", proteinGoal: "Protein goal",
                    carbGoal: "Carb goal", fatGoal: "Fat goal",
                    progressHeading: "Progress toward goals:", of: "of", goalWord: "goal",
                    reached: "reached", remaining: "remaining", overGoal: "over goal",
                    unknown: "unknown", notSet: "not set",
                    exceeded: "EXCEEDED", notMet: "NOT_MET",
                    dayContextHeading: "Day context:",
                    dayMorning: "Morning — day still in progress",
                    dayMidday: "Midday — day still in progress",
                    dayAfternoon: "Afternoon — day still in progress",
                    dayEvening: "Evening — day nearly complete"
                )
            }
        }
    }

    /// Deterministic, side-effect-free prompt text — the single place that
    /// decides what the model is allowed to see. A `nil` goal always becomes
    /// the literal marker below, never a number (Step 1 test asserts this).
    static func prompt(for input: NutritionInsightInput, locale: Locale) -> String {
        let s = PromptStrings.forLanguageCode(targetLanguageCode(for: locale))
        var text = """
        \(s.totalsHeading)
        \(s.calories): \(totalText(input.totalKcal, unit: "kcal", strings: s))
        \(s.protein): \(totalText(input.totalProteinG, unit: "g", strings: s))
        \(s.carbs): \(totalText(input.totalCarbsG, unit: "g", strings: s))
        \(s.fat): \(totalText(input.totalFatG, unit: "g", strings: s))

        \(s.goalsHeading)
        \(s.calorieGoal): \(goalText(input.calorieGoalKcal.map(Double.init), unit: "kcal", strings: s))
        \(s.proteinGoal): \(goalText(input.proteinGoalG, unit: "g", strings: s))
        \(s.carbGoal): \(goalText(input.carbGoalG, unit: "g", strings: s))
        \(s.fatGoal): \(goalText(input.fatGoalG, unit: "g", strings: s))
        """
        let progressLines = progressLines(for: input, strings: s)
        if !progressLines.isEmpty {
            text += "\n\n\(s.progressHeading)\n" + progressLines.joined(separator: "\n")
        }
        if let hour = input.timeOfDayHour {
            text += "\n\n\(s.dayContextHeading) \(dayContextLabel(hour: hour, strings: s))"
        }
        return text
    }

    private static func totalText(_ value: Double?, unit: String, strings: PromptStrings) -> String {
        guard let value else { return strings.unknown }
        return "\(safeInt(value)) \(unit)"
    }

    private static func goalText(_ value: Double?, unit: String, strings: PromptStrings) -> String {
        guard let value else { return strings.notSet }
        return "\(safeInt(value)) \(unit)"
    }

    /// One plain-stated fact per nutrient that has BOTH a goal and a
    /// pre-computed progress (the two are always set together by the
    /// caller — see `NutritionInsightInput.GoalProgress`'s doc comment) —
    /// e.g. "Protein: 40 g of 150 g goal (27% reached, 110 g remaining)".
    /// The model is handed the percentage and the remaining amount as given
    /// facts so it never has to judge "is 40 of 150 good progress" itself —
    /// see `baseInstructions`'s tone-calibration rule below.
    private static func progressLines(for input: NutritionInsightInput, strings: PromptStrings) -> [String] {
        [
            progressLine(label: strings.calories, current: safeInt(input.totalKcal), goal: input.calorieGoalKcal, unit: "kcal", progress: input.calorieGoalProgress, strings: strings),
            progressLine(label: strings.protein, current: safeInt(input.totalProteinG), goal: input.proteinGoalG.map(safeInt), unit: "g", progress: input.proteinGoalProgress, strings: strings),
            progressLine(label: strings.carbs, current: safeInt(input.totalCarbsG), goal: input.carbGoalG.map(safeInt), unit: "g", progress: input.carbGoalProgress, strings: strings),
            progressLine(label: strings.fat, current: safeInt(input.totalFatG), goal: input.fatGoalG.map(safeInt), unit: "g", progress: input.fatGoalProgress, strings: strings)
        ].compactMap { $0 }
    }

    /// OFF-01: `current` ist `nil`, sobald die Tagessumme dieser Dimension
    /// unbekannt ist — dann keine Prozent-/Rest-Aussage (auch dann nicht,
    /// wenn ein Ziel gesetzt waere).

    private static func progressLine(label: String, current: Int?, goal: Int?, unit: String, progress: NutritionInsightInput.GoalProgress?, strings: PromptStrings) -> String? {
        guard let current, let goal, let progress else { return nil }
        if progress.percent >= 100 {
            // Show overage instead of "0 remaining" — the clamped `remaining`
            // field is 0 by design for exceeded goals, which misleads the model.
            let overageStr = progress.overage > 0 ? ", \(safeInt(progress.overage)) \(unit) \(strings.overGoal)" : ""
            return "\(label): \(current) \(unit) \(strings.of) \(goal) \(unit) \(strings.goalWord) (\(progress.percent)% \(strings.reached)\(overageStr)) [\(strings.exceeded)]"
        }
        // [NOT_MET] label is the symmetric counterpart to [EXCEEDED] — prevents the model
        // from using "over goal" direction language for an under-goal line.
        return "\(label): \(current) \(unit) \(strings.of) \(goal) \(unit) \(strings.goalWord) (\(progress.percent)% \(strings.reached), \(safeInt(progress.remaining)) \(unit) \(strings.remaining)) [\(strings.notMet)]"
    }

    private static func dayContextLabel(hour: Int, strings: PromptStrings) -> String {
        switch hour {
        case 0..<11: return strings.dayMorning
        case 11..<14: return strings.dayMidday
        case 14..<19: return strings.dayAfternoon
        default: return strings.dayEvening
        }
    }

    /// M1 fix: `Int(Double)` traps on NaN/infinity/out-of-range magnitudes.
    /// Goals/quantities have no enforced upper bound elsewhere in the app, so
    /// an extreme value must not crash the day view. Mirrors the EXACT guard
    /// `Double.formattedRIR` already uses in `DoubleFormatting.swift` (not
    /// reused directly since `DeltiqAI` deliberately has no dependency on
    /// `DeltiqCore` — see `NutritionInsightInput`'s doc comment above).
    /// `Double(Int.max)` itself rounds UP to 2^63 (not exactly representable),
    /// so clamping a value via `Int(min(value, Double(Int.max)))` would still
    /// crash — the bound must only ever be used as a comparison, never
    /// converted back to `Int`.
    private static func safeInt(_ value: Double) -> Int {
        guard value.isFinite, abs(value) < Double(Int.max) else { return 0 }
        return Int(value)
    }

    /// OFF-01: unbekannte Summe → `nil` (kein Zahlenwert im Prompt), sonst
    /// unveraendert der bisherige, overflow-sichere Weg.
    private static func safeInt(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return safeInt(value)
    }
}
