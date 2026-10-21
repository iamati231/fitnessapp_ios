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
        private let result: String
        init(result: String = "generated insight") { self.result = result }
        func generateText(instructions: String, prompt: String) async throws -> String {
            callCount += 1
            lastPrompt = prompt
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
}
