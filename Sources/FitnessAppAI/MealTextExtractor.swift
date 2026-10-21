// ─────────────────────────────────────────────────────────────────────────────
// Task E / I2 (see task-D-review.md): typed structured output, built on top of
// NutritionAIService.swift's research comment (same APIs, same min OS). New
// piece here: `@Generable`/`@Guide` typed extraction instead of free text.
//   `session.respond(to:generating:)` -> `Response<T>` for a `@Generable` T;
//   arrays of `@Generable` element types are themselves `@Generable` as a
//   property of a container struct (there is no bare `[Foo].self` form).
//   `@Generable` properties are declared `var` (the macro also synthesizes a
//   PartiallyGenerated variant with optional members during streaming; we only
//   use the final, fully-populated `.content`, never partial generation).
// As with NutritionAIAvailability/NutritionAIError, nothing FoundationModels-typed
// crosses out of this file: `MealTextCandidate` and friends are plain Sendable
// value types with String/Double/Bool fields.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Privacy: the input text and every candidate derived from it may contain
// nutrition data — never print/debugPrint/log them anywhere in this module.

/// Unit guessed by the model for one extracted food mention. Deliberately a
/// small, closed, FM-free enum — never `FitnessAppCore.FoodUnit` directly, so
/// this module keeps its "no dependencies" property (Task D review).
public enum MealTextCandidateUnit: String, Sendable, Equatable {
    case gram
    case piece
    case milliliter
}

/// Meal-type guessed from context (e.g. "zum Mittagessen"). `nil` on the
/// candidate means no guess could be made — the UI keeps whatever meal type
/// is already selected in the draft, it never silently picks one.
public enum MealTextCandidateMealType: String, Sendable, Equatable {
    case breakfast
    case lunch
    case dinner
    case snack
}

/// One food mention as extracted by the model, BEFORE catalog matching.
/// `quantity`/`unit`/`mealType` are `nil` whenever the model didn't state (or
/// didn't clearly state) a value — never a silently-assumed default.
public struct MealTextCandidate: Sendable, Equatable {
    public let foodText: String
    public let quantity: Double?
    public let unit: MealTextCandidateUnit?
    public let mealType: MealTextCandidateMealType?

    public init(foodText: String, quantity: Double?, unit: MealTextCandidateUnit?, mealType: MealTextCandidateMealType?) {
        self.foodText = foodText
        self.quantity = quantity
        self.unit = unit
        self.mealType = mealType
    }
}

/// One local catalog entry as far as matching needs it — just the already
/// resolved, localized display name (see `AddMealView.resolvedName`). Kept
/// deliberately minimal so this module never needs `FitnessAppCore`/`Bundle`.
public struct MealTextCatalogEntry: Sendable, Equatable {
    public let catalogID: String
    public let name: String

    public init(catalogID: String, name: String) {
        self.catalogID = catalogID
        self.name = name
    }
}

/// Final, UI-ready draft candidate: the model's guess plus the catalog
/// entries it could match against. The UI/`MealDraft` NEVER auto-accepts a
/// candidate — it is always either a single confident match, a manual pick
/// from `matches`, or a quantity follow-up question.
public struct MealDraftCandidate: Sendable, Equatable {
    public let foodText: String
    /// `nil` when quantity was missing/invalid — the UI must ask, never default.
    public let quantity: Double?
    public let unit: MealTextCandidateUnit?
    public let mealType: MealTextCandidateMealType?
    /// Catalog entries whose name matches `foodText`. Empty = no catalog hit
    /// (manual search only), one = confident match, more than one = ambiguous
    /// (manual pick required).
    public let matches: [MealTextCatalogEntry]

    public init(foodText: String, quantity: Double?, unit: MealTextCandidateUnit?, mealType: MealTextCandidateMealType?, matches: [MealTextCatalogEntry]) {
        self.foodText = foodText
        self.quantity = quantity
        self.unit = unit
        self.mealType = mealType
        self.matches = matches
    }

    public var needsQuantity: Bool { quantity == nil }
    public var isAmbiguous: Bool { matches.count > 1 }
    public var hasNoCatalogMatch: Bool { matches.isEmpty }
}

/// The raw structured-output model call, without availability gating or
/// catalog matching. Mirrors `NutritionAITextGenerating`'s pattern so tests
/// can inject fake/broken responses without touching FoundationModels.
public protocol NutritionAIMealExtracting: Sendable {
    func extractMealCandidates(instructions: String, prompt: String) async throws -> [MealTextCandidate]
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct MealExtractionResponse {
    @Guide(description: "One entry per distinct food or drink mentioned in the input text.")
    var items: [MealExtractionItem]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct MealExtractionItem {
    @Guide(description: "The food/drink name exactly as mentioned in the input text, same language as the input.")
    var foodText: String
    @Guide(description: "The numeric amount stated for this food. Omit entirely if no amount was stated.")
    var quantity: Double?
    @Guide(description: "Unit for quantity. One of: gram, piece, milliliter, unknown.")
    var unit: String
    @Guide(description: "Meal type suggested by the text (e.g. time-of-day words). One of: breakfast, lunch, dinner, snack, unknown.")
    var mealType: String
}
#endif

/// Real backend: one fresh `LanguageModelSession` per request, typed output
/// via `@Generable`/`@Guide` — never regex-parsed free text (plan requirement).
public struct FoundationModelsMealExtractor: NutritionAIMealExtracting {
    public init() {}

    public func extractMealCandidates(instructions: String, prompt: String) async throws -> [MealTextCandidate] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt, generating: MealExtractionResponse.self)
                return response.content.items.map(Self.makeCandidate)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw NutritionAIError.generationFailed
            }
        }
        #endif
        throw NutritionAIError.unavailable(.deviceNotSupported)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func makeCandidate(from item: MealExtractionItem) -> MealTextCandidate {
        MealTextCandidate(
            foodText: item.foodText,
            quantity: item.quantity,
            unit: MealTextCandidateUnit(rawValue: item.unit),
            mealType: MealTextCandidateMealType(rawValue: item.mealType)
        )
    }
    #endif
}

/// Orchestrates structured extraction + local catalog matching for one piece of
/// free text. The AI NEVER produces a nutrient value itself (plan requirement):
/// callers take `matches`/catalog IDs from here and compute nutrients via
/// `NutritionCalculations.nutrients(for:quantity:unit:)` (Core) as usual.
public struct MealTextExtractor: Sendable {
    private let service: NutritionAIService

    public init(service: NutritionAIService = NutritionAIService()) {
        self.service = service
    }

    public func availability() -> NutritionAIAvailability {
        service.availability()
    }

    /// Throws `NutritionAIError` (including `.unavailable(_)`, propagated from
    /// `service`) without ever crashing on a malformed model response — any
    /// candidate missing a usable food name is simply dropped, any invalid
    /// quantity/unit/meal-type is normalized to `nil` rather than defaulted.
    public func extractCandidates(from text: String, catalog: [MealTextCatalogEntry]) async throws -> [MealDraftCandidate] {
        let raw = try await service.extractMealCandidates(from: text)
        return raw.compactMap { candidate -> MealDraftCandidate? in
            let foodText = candidate.foodText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !foodText.isEmpty else { return nil }
            let sanitizedQuantity = (candidate.quantity ?? 0) > 0 ? candidate.quantity : nil
            return MealDraftCandidate(
                foodText: foodText,
                quantity: sanitizedQuantity,
                unit: candidate.unit,
                mealType: candidate.mealType,
                matches: Self.matchCatalog(foodText: foodText, catalog: catalog)
            )
        }
    }

    /// Case-insensitive exact match first; falls back to substring match in
    /// either direction (e.g. "Reis" matching "Reis, gekocht"). Pure string
    /// comparison only — the actual nutrient lookup always goes through Core.
    static func matchCatalog(foodText: String, catalog: [MealTextCatalogEntry]) -> [MealTextCatalogEntry] {
        let exact = catalog.filter { $0.name.caseInsensitiveCompare(foodText) == .orderedSame }
        if !exact.isEmpty { return exact }
        return catalog.filter {
            $0.name.localizedCaseInsensitiveContains(foodText) || foodText.localizedCaseInsensitiveContains($0.name)
        }
    }
}
