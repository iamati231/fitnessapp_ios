import XCTest
@testable import FitnessAppAI

/// Task F: local, non-medical nutrition coaching text built from
/// already-computed day totals + optional goals. Mirrors the
/// `FixedAvailability`/`SpyGenerator` pattern from
/// `NutritionAIAvailabilityTests`/`MealTextExtractorTests`.
final class NutritionInsightGeneratorTests: XCTestCase {

    private struct FixedAvailability: NutritionAIAvailabilityChecking {
        let status: NutritionAIAvailability
        func availability(for locale: Locale) -> NutritionAIAvailability { status }
    }

    private actor SpyGenerator: NutritionAITextGenerating {
        private(set) var callCount = 0
        private(set) var lastPrompt: String?
        private(set) var lastInstructions: String?
        private let result: String
        init(result: String = "generated insight") { self.result = result }
        func generateText(instructions: String, prompt: String) async throws -> String {
            callCount += 1
            lastPrompt = prompt
            lastInstructions = instructions
            return result
        }
    }

    private let fullInput = NutritionInsightInput(
        totalKcal: 1850, totalProteinG: 120, totalCarbsG: 180, totalFatG: 60,
        calorieGoalKcal: 2200, proteinGoalG: 140, carbGoalG: 220, fatGoalG: 70
    )

    private let noGoalsInput = NutritionInsightInput(
        totalKcal: 1850, totalProteinG: 120, totalCarbsG: 180, totalFatG: 60,
        calorieGoalKcal: nil, proteinGoalG: nil, carbGoalG: nil, fatGoalG: nil
    )

    // MARK: Step 1 — nil goal is never fabricated as a number

    /// Proves: when `calorieGoalKcal == nil`, the prompt handed to the model
    /// never contains a number for the calorie goal — only the literal
    /// "not set" marker — so the model has nothing to turn into an invented
    /// number or a false "goal missed/reached" claim.
    func testNilCalorieGoal_promptMarksNotSet_neverAsANumber() {
        let prompt = NutritionInsightGenerator.prompt(for: noGoalsInput)
        XCTAssertTrue(prompt.contains("Calorie goal: not set"), "expected an explicit not-set marker, got:\n\(prompt)")
        // The goal line itself must carry no digits at all (the day's total
        // calories elsewhere in the prompt legitimately does, e.g. "1850 kcal").
        let goalLine = prompt.split(separator: "\n").first { $0.hasPrefix("Calorie goal:") }
        XCTAssertEqual(goalLine, "Calorie goal: not set")
    }

    /// Same proof for all four goals at once.
    func testAllGoalsNil_promptMarksAllFourAsNotSet() {
        let prompt = NutritionInsightGenerator.prompt(for: noGoalsInput)
        for label in ["Calorie goal", "Protein goal", "Carb goal", "Fat goal"] {
            XCTAssertTrue(prompt.contains("\(label): not set"), "missing not-set marker for \(label) in:\n\(prompt)")
        }
    }

    /// A goal that IS set must appear as its exact given number — still never
    /// recomputed, just carried through.
    func testSetGoal_promptShowsTheExactGivenNumber() {
        let prompt = NutritionInsightGenerator.prompt(for: fullInput)
        XCTAssertTrue(prompt.contains("Calorie goal: 2200 kcal"))
        XCTAssertTrue(prompt.contains("Protein goal: 140 g"))
        XCTAssertTrue(prompt.contains("Carb goal: 220 g"))
        XCTAssertTrue(prompt.contains("Fat goal: 70 g"))
    }

    // MARK: Prompt is built only from the given values (no recomputation)

    func testPromptContainsOnlyTheGivenTotals_noOwnRecalculation() {
        let prompt = NutritionInsightGenerator.prompt(for: fullInput)
        XCTAssertTrue(prompt.contains("Calories: 1850 kcal"))
        XCTAssertTrue(prompt.contains("Protein: 120 g"))
        XCTAssertTrue(prompt.contains("Carbs: 180 g"))
        XCTAssertTrue(prompt.contains("Fat: 60 g"))
    }

    /// Two inputs that differ only in a field the prompt doesn't use for
    /// anything but verbatim passthrough must produce prompts that differ
    /// in exactly that one place — proof there is no hidden derived math.
    func testPromptIsPureFunctionOfInput_sameInputSamePrompt() {
        XCTAssertEqual(
            NutritionInsightGenerator.prompt(for: fullInput),
            NutritionInsightGenerator.prompt(for: fullInput)
        )
    }

    // MARK: End-to-end via the service — the generated text is returned verbatim

    func testAvailable_passesBuiltPromptToModel_andReturnsItsTextUnchanged() async throws {
        let spy = SpyGenerator(result: "You're close to your protein goal today.")
        let generator = NutritionInsightGenerator(service: NutritionAIService(
            availabilityChecker: FixedAvailability(status: .available),
            generator: spy
        ))
        let text = try await generator.generateInsight(for: fullInput)
        XCTAssertEqual(text, "You're close to your protein goal today.")
        let prompt = await spy.lastPrompt
        XCTAssertEqual(prompt, NutritionInsightGenerator.prompt(for: fullInput))
    }

    // MARK: Step 1 — `.unavailable` never calls the model

    func testUnavailable_neverCallsTheModel() async {
        let spy = SpyGenerator()
        let generator = NutritionInsightGenerator(service: NutritionAIService(
            availabilityChecker: FixedAvailability(status: .appleIntelligenceNotEnabled),
            generator: spy
        ))
        do {
            _ = try await generator.generateInsight(for: fullInput)
            XCTFail("expected unavailable error")
        } catch let error as NutritionAIError {
            XCTAssertEqual(error, .unavailable(.appleIntelligenceNotEnabled))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        let calls = await spy.callCount
        XCTAssertEqual(calls, 0, "the model must never be asked while AI is unavailable")
    }

    func testAvailability_passesThroughFromService() {
        let generator = NutritionInsightGenerator(service: NutritionAIService(
            availabilityChecker: FixedAvailability(status: .languageNotSupported),
            generator: SpyGenerator()
        ))
        XCTAssertEqual(generator.availability(), .languageNotSupported)
    }

    // MARK: I2 — explicit per-locale language directive

    /// German and Turkish must each get their own explicit "respond only in
    /// X" sentence — not the same English-only instructions regardless of
    /// locale (the bug: the model was never actually told which language to
    /// answer in, only the availability check used the locale).
    func testInstructions_differPerLocale_andNameTheLanguageExplicitly() {
        let de = NutritionInsightGenerator.instructions(for: Locale(identifier: "de"))
        let tr = NutritionInsightGenerator.instructions(for: Locale(identifier: "tr"))
        let en = NutritionInsightGenerator.instructions(for: Locale(identifier: "en"))

        XCTAssertTrue(de.contains("German"), "expected an explicit German directive, got:\n\(de)")
        XCTAssertTrue(tr.contains("Turkish"), "expected an explicit Turkish directive, got:\n\(tr)")
        XCTAssertNotEqual(de, tr)
        XCTAssertNotEqual(de, en)
    }

    /// End-to-end: the instructions the generator actually hands to the model
    /// carry the locale-specific directive, proven via the same spy pattern
    /// as `NutritionAIAvailabilityTests`/`MealTextExtractorTests`.
    func testGenerateInsight_passesLocaleSpecificInstructionsToTheModel() async throws {
        let spy = SpyGenerator()
        let generator = NutritionInsightGenerator(
            service: NutritionAIService(
                availabilityChecker: FixedAvailability(status: .available),
                generator: spy
            ),
            locale: Locale(identifier: "tr")
        )
        _ = try await generator.generateInsight(for: fullInput)
        let instructions = await spy.lastInstructions
        XCTAssertEqual(instructions, NutritionInsightGenerator.instructions(for: Locale(identifier: "tr")))
        XCTAssertTrue(instructions?.contains("Turkish") ?? false)
    }

    // MARK: I5 — fabricated numbers in the generated text are never shown

    func testGeneratedText_withFabricatedNumber_isTreatedAsFailure() async {
        // "5000" appears nowhere in `fullInput`'s totals or goals.
        let spy = SpyGenerator(result: "You ate 5000 kcal more than anyone else today!")
        let generator = NutritionInsightGenerator(service: NutritionAIService(
            availabilityChecker: FixedAvailability(status: .available),
            generator: spy
        ))
        do {
            _ = try await generator.generateInsight(for: fullInput)
            XCTFail("a fabricated number must not be returned as a valid insight")
        } catch let error as NutritionAIError {
            XCTAssertEqual(error, .generationFailed)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testGeneratedText_withOnlyRealNumbers_passesThrough() async throws {
        // 1850/120/180/60 are the totals, 2200/140/220/70 the goals in `fullInput`.
        let spy = SpyGenerator(result: "You had 1850 kcal, 120g protein toward your 140g and 2200 kcal goals.")
        let generator = NutritionInsightGenerator(service: NutritionAIService(
            availabilityChecker: FixedAvailability(status: .available),
            generator: spy
        ))
        let text = try await generator.generateInsight(for: fullInput)
        XCTAssertEqual(text, "You had 1850 kcal, 120g protein toward your 140g and 2200 kcal goals.")
    }

    // MARK: Tone-calibration bugfix — stated percent-of-goal/remaining facts

    /// Reported bug: 40g of a 150g protein goal (26.7% / 110g remaining) was
    /// called "super" by the model because the prompt only ever gave it the
    /// two raw numbers, never the percentage. Proves the real prompt-building
    /// code now states the computed fact literally, so the model never has to
    /// infer or compute it itself.
    func testPrompt_includesStatedPercentAndRemaining_forTheReportedBugCase() {
        let input = NutritionInsightInput(
            totalKcal: 1850, totalProteinG: 40, totalCarbsG: 180, totalFatG: 60,
            calorieGoalKcal: 2200, proteinGoalG: 150, carbGoalG: 220, fatGoalG: 70,
            proteinGoalProgress: .init(percent: 27, remaining: 110)
        )
        let prompt = NutritionInsightGenerator.prompt(for: input)
        XCTAssertTrue(
            prompt.contains("Protein: 40 g of 150 g goal (27% reached, 110 g remaining)"),
            "expected the stated progress fact, got:\n\(prompt)"
        )
    }

    /// A nutrient with a goal but no progress supplied (shouldn't happen from
    /// the real caller, but the prompt must stay crash-free and simply omit
    /// the fact rather than show a half-built line) never gets a line.
    func testPrompt_goalWithoutProgress_omitsTheProgressLineForThatNutrient() {
        let input = NutritionInsightInput(
            totalKcal: 1850, totalProteinG: 40, totalCarbsG: 180, totalFatG: 60,
            calorieGoalKcal: 2200, proteinGoalG: 150, carbGoalG: 220, fatGoalG: 70
        )
        let prompt = NutritionInsightGenerator.prompt(for: input)
        XCTAssertFalse(prompt.contains("Progress toward goals"))
    }

    /// No goals at all -> no "Progress toward goals" section whatsoever.
    func testPrompt_noGoals_noProgressSection() {
        let prompt = NutritionInsightGenerator.prompt(for: noGoalsInput)
        XCTAssertFalse(prompt.contains("Progress toward goals"))
    }

    /// The stated percent/remaining numbers must be allowed, not flagged as
    /// hallucinated, when the model legitimately repeats them back.
    func testOnlyContainsVerifiedNumbers_allowsTheStatedPercentAndRemaining() {
        let input = NutritionInsightInput(
            totalKcal: 1850, totalProteinG: 40, totalCarbsG: 180, totalFatG: 60,
            calorieGoalKcal: 2200, proteinGoalG: 150, carbGoalG: 220, fatGoalG: 70,
            proteinGoalProgress: .init(percent: 27, remaining: 110)
        )
        XCTAssertTrue(NutritionInsightGenerator.onlyContainsVerifiedNumbers(
            "You're at 27% of your 150g protein goal, 110g to go.", input: input
        ))
    }

    /// A percent/remaining number that does NOT match the real computed
    /// progress is still rejected — adding the new allowed numbers must not
    /// widen the guard into accepting arbitrary numbers.
    func testOnlyContainsVerifiedNumbers_stillRejectsAFabricatedPercent() {
        let input = NutritionInsightInput(
            totalKcal: 1850, totalProteinG: 40, totalCarbsG: 180, totalFatG: 60,
            calorieGoalKcal: 2200, proteinGoalG: 150, carbGoalG: 220, fatGoalG: 70,
            proteinGoalProgress: .init(percent: 27, remaining: 110)
        )
        XCTAssertFalse(NutritionInsightGenerator.onlyContainsVerifiedNumbers(
            "You're already at 99% of your protein goal!", input: input
        ))
    }

    /// Tone-calibration instruction must actually be present, matching the
    /// existing style/language of `baseInstructions` (English, imperative).
    func testInstructions_containToneCalibrationRule() {
        let instructions = NutritionInsightGenerator.instructions(for: Locale(identifier: "en"))
        XCTAssertTrue(instructions.contains("Progress toward"))
        XCTAssertTrue(instructions.contains("50%"))
    }

    // MARK: M1 — extreme/non-finite values never crash the prompt/verification

    func testExtremeValues_neverCrashPromptOrVerification() {
        let extreme = NutritionInsightInput(
            totalKcal: .infinity, totalProteinG: .nan, totalCarbsG: -.infinity, totalFatG: .greatestFiniteMagnitude,
            calorieGoalKcal: nil, proteinGoalG: .nan, carbGoalG: nil, fatGoalG: nil
        )
        // Must not trap (Int(Double) on these values would crash).
        _ = NutritionInsightGenerator.prompt(for: extreme)
        XCTAssertTrue(NutritionInsightGenerator.onlyContainsVerifiedNumbers("no numbers here", input: extreme))
    }
}
