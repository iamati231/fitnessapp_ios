import XCTest
@testable import FitnessAppAI

/// Bugfix (writing-block.md 7.1, "tuerkische Eingaben funktionieren
/// unzuverlaessig"): `locale` reached `NutritionAIService` already (see
/// `AddMealView.mealTextExtractor`) but was previously used ONLY for the
/// availability check — the instructions sent to the model never named the
/// expected input language at all. These tests prove the instructions now
/// name the right language for each of the app's three supported locales
/// (see Global Constraints: Deutsch/Englisch/Tuerkisch), and fall back to
/// English rather than silently omitting the hint for anything else.
final class NutritionAIServiceLanguageTests: XCTestCase {

    private struct FixedAvailability: NutritionAIAvailabilityChecking {
        func availability(for locale: Locale) -> NutritionAIAvailability { .available }
    }

    private actor InstructionsSpy: NutritionAIMealExtracting {
        private(set) var capturedInstructions: String?
        func extractMealCandidates(instructions: String, prompt: String) async throws -> [MealTextCandidate] {
            capturedInstructions = instructions
            return []
        }
    }

    private func capturedInstructions(forLocaleIdentifier identifier: String) async throws -> String {
        let spy = InstructionsSpy()
        let service = NutritionAIService(
            availabilityChecker: FixedAvailability(),
            mealExtractor: spy,
            locale: Locale(identifier: identifier)
        )
        _ = try await service.extractMealCandidates(from: "irrelevant")
        let captured = await spy.capturedInstructions
        return try XCTUnwrap(captured)
    }

    func testGermanLocaleNamesGermanAsTheExpectedLanguage() async throws {
        let instructions = try await capturedInstructions(forLocaleIdentifier: "de")
        XCTAssertTrue(instructions.contains("German"))
    }

    func testTurkishLocaleNamesTurkishAsTheExpectedLanguage() async throws {
        let instructions = try await capturedInstructions(forLocaleIdentifier: "tr")
        XCTAssertTrue(instructions.contains("Turkish"))
    }

    func testEnglishLocaleNamesEnglishAsTheExpectedLanguage() async throws {
        let instructions = try await capturedInstructions(forLocaleIdentifier: "en")
        XCTAssertTrue(instructions.contains("English"))
    }

    func testUnsupportedLocaleFallsBackToEnglishRatherThanOmittingTheLanguage() async throws {
        let instructions = try await capturedInstructions(forLocaleIdentifier: "fr")
        XCTAssertTrue(instructions.contains("English"))
    }
}
