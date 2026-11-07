#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Phase 5.0: Persistenz-Roundtrip für requiresHalal und Ernährungspräferenzen.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class NutritionPreferencesTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: - Persistenz

    func testRequiresHalal_defaultFalse() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        container.mainContext.insert(profile)
        try container.mainContext.save()
        XCTAssertFalse(profile.mealPlanRequiresHalal)
        XCTAssertFalse(profile.nutritionPreferences.requiresHalal)
    }

    func testRequiresHalal_persistsTrue() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        container.mainContext.insert(profile)
        profile.mealPlanRequiresHalal = true
        try container.mainContext.save()
        XCTAssertTrue(profile.nutritionPreferences.requiresHalal)
    }

    func testNutritionPreferences_roundtrip_allFields() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        container.mainContext.insert(profile)

        var prefs = UserNutritionPreferences(
            dietaryStyle: .vegan,
            requiresHalal: true,
            allergenExclusions: [.gluten, .lactose],
            excludedRecipeIDs: ["recipe_a", "recipe_b"]
        )
        profile.nutritionPreferences = prefs
        try container.mainContext.save()

        let loaded = profile.nutritionPreferences
        XCTAssertEqual(loaded.dietaryStyle, .vegan)
        XCTAssertTrue(loaded.requiresHalal)
        XCTAssertEqual(loaded.allergenExclusions, [.gluten, .lactose])
        XCTAssertEqual(loaded.excludedRecipeIDs, ["recipe_a", "recipe_b"])
    }

    func testNutritionPreferences_setterUpdatesAllFlatFields() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        container.mainContext.insert(profile)

        profile.nutritionPreferences = UserNutritionPreferences(
            dietaryStyle: .pescetarian,
            requiresHalal: false,
            allergenExclusions: [.eggs],
            excludedRecipeIDs: ["r1"]
        )
        XCTAssertEqual(profile.mealPlanDietaryStyleRaw, "pescetarian")
        XCTAssertFalse(profile.mealPlanRequiresHalal)
        XCTAssertEqual(profile.mealPlanAllergenExclusionsRaw, ["eggs"])
        XCTAssertEqual(profile.mealPlanExcludedRecipeIDsRaw, ["r1"])
    }
}
#endif
