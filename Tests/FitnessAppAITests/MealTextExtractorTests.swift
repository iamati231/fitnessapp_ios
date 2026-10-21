import XCTest
@testable import FitnessAppAI

/// Task E: typed meal-draft extraction + catalog matching. The fake backend
/// below lets every test (including the "broken model response" ones) run
/// without ever touching FoundationModels.
final class MealTextExtractorTests: XCTestCase {

    private struct FixedAvailability: NutritionAIAvailabilityChecking {
        let status: NutritionAIAvailability
        func availability(for locale: Locale) -> NutritionAIAvailability { status }
    }

    private actor FakeExtractingBackend: NutritionAIMealExtracting {
        private(set) var callCount = 0
        private let result: [MealTextCandidate]
        init(result: [MealTextCandidate]) { self.result = result }
        func extractMealCandidates(instructions: String, prompt: String) async throws -> [MealTextCandidate] {
            callCount += 1
            return result
        }
    }

    private func extractor(available: Bool = true, candidates: [MealTextCandidate]) -> (MealTextExtractor, FakeExtractingBackend) {
        let backend = FakeExtractingBackend(result: candidates)
        let service = NutritionAIService(
            availabilityChecker: FixedAvailability(status: available ? .available : .deviceNotSupported),
            mealExtractor: backend
        )
        return (MealTextExtractor(service: service), backend)
    }

    private let catalog = [
        MealTextCatalogEntry(catalogID: "chicken_breast_raw", name: "Hähnchenbrust"),
        MealTextCatalogEntry(catalogID: "rice_white_cooked", name: "Reis, weiß, gekocht"),
        MealTextCatalogEntry(catalogID: "rice_brown_cooked", name: "Reis, braun, gekocht")
    ]

    // MARK: Valid complete input

    func testValidCompleteInput_returnsOneCandidatePerFood() async throws {
        let (extractor, backend) = extractor(candidates: [
            MealTextCandidate(foodText: "Hähnchenbrust", quantity: 200, unit: .gram, mealType: .lunch),
            MealTextCandidate(foodText: "Reis", quantity: 150, unit: .gram, mealType: .lunch)
        ])
        let candidates = try await extractor.extractCandidates(from: "200g Hähnchenbrust und 150g Reis zum Mittagessen", catalog: catalog)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates[0].quantity, 200)
        XCTAssertEqual(candidates[0].matches.map(\.catalogID), ["chicken_breast_raw"])
        XCTAssertFalse(candidates[0].needsQuantity)
        XCTAssertFalse(candidates[0].isAmbiguous)
        let calls = await backend.callCount
        XCTAssertEqual(calls, 1)
    }

    // MARK: Missing quantity -> follow-up, no silent default

    func testMissingQuantity_marksNeedsQuantity_noSilentDefault() async throws {
        let (extractor, _) = extractor(candidates: [
            MealTextCandidate(foodText: "Hähnchenbrust", quantity: nil, unit: nil, mealType: .lunch)
        ])
        let candidates = try await extractor.extractCandidates(from: "Hähnchenbrust zum Mittagessen", catalog: catalog)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertNil(candidates[0].quantity)
        XCTAssertTrue(candidates[0].needsQuantity)
    }

    // MARK: Ambiguous catalog match -> manual pick, no auto-first-hit

    func testAmbiguousCatalogMatch_offersManualPick() async throws {
        let (extractor, _) = extractor(candidates: [
            MealTextCandidate(foodText: "Reis", quantity: 150, unit: .gram, mealType: .lunch)
        ])
        let candidates = try await extractor.extractCandidates(from: "150g Reis", catalog: catalog)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].isAmbiguous)
        XCTAssertEqual(Set(candidates[0].matches.map(\.catalogID)), ["rice_white_cooked", "rice_brown_cooked"])
    }

    // MARK: Broken / incomplete simulated model response -> handled safely

    func testBrokenResponse_blankFoodText_isDropped() async throws {
        let (extractor, _) = extractor(candidates: [
            MealTextCandidate(foodText: "   ", quantity: 100, unit: .gram, mealType: nil),
            MealTextCandidate(foodText: "Hähnchenbrust", quantity: 100, unit: .gram, mealType: nil)
        ])
        let candidates = try await extractor.extractCandidates(from: "irrelevant", catalog: catalog)

        XCTAssertEqual(candidates.count, 1, "the blank-name candidate must be dropped, not crash or appear as an empty row")
        XCTAssertEqual(candidates[0].foodText, "Hähnchenbrust")
    }

    func testBrokenResponse_negativeOrZeroQuantity_normalizedToNeedsQuantity() async throws {
        let (extractor, _) = extractor(candidates: [
            MealTextCandidate(foodText: "Hähnchenbrust", quantity: -5, unit: .gram, mealType: nil),
            MealTextCandidate(foodText: "Reis", quantity: 0, unit: .gram, mealType: nil)
        ])
        let candidates = try await extractor.extractCandidates(from: "irrelevant", catalog: catalog)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.allSatisfy { $0.needsQuantity }, "a negative/zero quantity must never be treated as a valid amount")
    }

    func testBrokenResponse_unrecognizedUnitOrMealTypeString_mapsToNilNotCrash() {
        // Simulates a malformed model answer that didn't match the @Guide'd
        // vocabulary — the `rawValue:` enum init just returns nil, no crash.
        XCTAssertNil(MealTextCandidateUnit(rawValue: "kg"))
        XCTAssertNil(MealTextCandidateMealType(rawValue: "brunch"))
    }

    func testBrokenResponse_emptyItemsList_returnsEmptyCandidates() async throws {
        let (extractor, _) = extractor(candidates: [])
        let candidates = try await extractor.extractCandidates(from: "nothing recognizable", catalog: catalog)
        XCTAssertTrue(candidates.isEmpty)
    }

    // MARK: No catalog hit -> empty matches, not a crash, not an auto-pick

    func testNoCatalogMatch_returnsEmptyMatches() async throws {
        let (extractor, _) = extractor(candidates: [
            MealTextCandidate(foodText: "Kiwi", quantity: 1, unit: .piece, mealType: nil)
        ])
        let candidates = try await extractor.extractCandidates(from: "eine Kiwi", catalog: catalog)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].hasNoCatalogMatch)
    }

    // MARK: Availability gate (mirrors NutritionAIAvailabilityTests)

    func testUnavailable_neverCallsTheBackend() async {
        let (extractor, backend) = extractor(available: false, candidates: [])
        do {
            _ = try await extractor.extractCandidates(from: "irrelevant", catalog: catalog)
            XCTFail("expected unavailable error")
        } catch let error as NutritionAIError {
            XCTAssertEqual(error, .unavailable(.deviceNotSupported))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        let calls = await backend.callCount
        XCTAssertEqual(calls, 0)
    }
}
