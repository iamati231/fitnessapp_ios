#if canImport(FoundationModels)
import XCTest
@testable import FitnessAppAI

/// Bugfix (writing-block.md 7.3, "zweite Ausgabe ist in ~90% der Faelle
/// unknown"): `unit`/`mealType` used to be plain `String` fields mapped via
/// an exact, case-sensitive `rawValue:` lookup — any deviation from the
/// expected token silently became `nil` ("unknown"), even for a value the
/// model stated clearly. They are now real `@Generable` enums
/// (`MealExtractionUnit`/`MealExtractionMealType`), so the framework itself
/// constrains the model to one of the defined cases instead of free text.
/// These tests only prove `FoundationModelsMealExtractor`'s mapping from
/// those enums to the public `MealTextCandidateUnit`/`MealTextCandidateMealType`
/// is complete and that `.unknown` maps to `nil`, not some other case — the
/// actual on-device inference behavior (whether the real model now answers
/// correctly more often) needs a real iOS 26+ device, which the user is
/// verifying themselves.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
final class MealTextExtractorMappingTests: XCTestCase {

    func testCandidateUnitMapsEveryKnownCase() {
        XCTAssertEqual(FoundationModelsMealExtractor.candidateUnit(from: .gram), .gram)
        XCTAssertEqual(FoundationModelsMealExtractor.candidateUnit(from: .piece), .piece)
        XCTAssertEqual(FoundationModelsMealExtractor.candidateUnit(from: .milliliter), .milliliter)
    }

    func testCandidateUnitMapsUnknownToNilNotToAnyCase() {
        XCTAssertNil(FoundationModelsMealExtractor.candidateUnit(from: .unknown))
    }

    func testCandidateMealTypeMapsEveryKnownCase() {
        XCTAssertEqual(FoundationModelsMealExtractor.candidateMealType(from: .breakfast), .breakfast)
        XCTAssertEqual(FoundationModelsMealExtractor.candidateMealType(from: .lunch), .lunch)
        XCTAssertEqual(FoundationModelsMealExtractor.candidateMealType(from: .dinner), .dinner)
        XCTAssertEqual(FoundationModelsMealExtractor.candidateMealType(from: .snack), .snack)
    }

    func testCandidateMealTypeMapsUnknownToNilNotToAnyCase() {
        XCTAssertNil(FoundationModelsMealExtractor.candidateMealType(from: .unknown))
    }
}
#endif
