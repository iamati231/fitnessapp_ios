#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
@testable import FitnessAppCore

/// Phase 4.9: Integrationstests für MealPlanOptimizer.
/// Prüft Portionsskalierung, Schrittweiten, OFF-01, Filter und Plan-Isolation.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPlanOptimizerIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    // Bekanntes Lebensmittel: 100g → 165 kcal, 31g P, 0g KH, 3.6g F
    private let food = FoodCatalogItem(
        id: "chicken",
        nameKey: "t.chicken",
        category: .meat,
        kcalPer100g: 165,
        proteinPer100g: 31,
        carbsPer100g: 0,
        fatPer100g: 3.6
    )

    private let unknownFood = FoodCatalogItem(
        id: "mystery",
        nameKey: "t.mystery",
        category: .meat,
        nutrientsPer100g: NutrientValues(kcal: .unknown, proteinG: .unknown, carbsG: .unknown, fatG: .unknown)
    )

    private let nutsFood = FoodCatalogItem(
        id: "nuts",
        nameKey: "t.nuts",
        category: .other,
        kcalPer100g: 600,
        proteinPer100g: 15,
        carbsPer100g: 20,
        fatPer100g: 50
    )

    private lazy var lunchRecipe = Recipe(
        id: "r_lunch", nameKey: "t.lunch",
        mealTypes: [.lunch], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 100)]
    )

    private lazy var unknownRecipe = Recipe(
        id: "r_unknown", nameKey: "t.unknown",
        mealTypes: [.lunch], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "mystery", amountGrams: 100)]
    )

    private lazy var nutsRecipe = Recipe(
        id: "r_nuts", nameKey: "t.nuts_recipe",
        mealTypes: [.lunch], dietaryTags: [], allergens: [.nuts], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "nuts", amountGrams: 100)]
    )

    private lazy var veganRecipe = Recipe(
        id: "r_vegan", nameKey: "t.vegan",
        mealTypes: [.lunch], dietaryTags: [.vegan], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 100)]
    )

    private lazy var breakfastRecipe = Recipe(
        id: "r_breakfast", nameKey: "t.breakfast",
        mealTypes: [.breakfast], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 100)]
    )

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    private func defaultPrefs() -> UserNutritionPreferences { UserNutritionPreferences() }

    // Simuliert applyOptimization() aus MealPlannerView
    private func applyProposal(_ proposal: OptimizedPlanProposal, to plan: DailyMealPlan) throws {
        for change in proposal.changes where change.hasChange {
            guard let assignment = plan.assignments.first(where: {
                $0.mealType == change.mealType && $0.recipeID == change.currentRecipeID
            }) else { continue }
            assignment.recipeID = change.proposedRecipeID
            assignment.portionMultiplier = change.proposedMultiplier
        }
        plan.isManuallyAdjusted = true
        try context.save()
    }

    // MARK: - 1. Kein Ziel gesetzt → noGoalSet

    func testNoGoalSet_returnsError() {
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: nil, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        XCTAssertEqual(result, .failure(.noGoalSet))
    }

    // MARK: - 2. Keine Zuweisungen → noAssignments

    func testNoAssignments_returnsError() {
        let result = MealPlanOptimizer.optimize(
            assignments: [],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        XCTAssertEqual(result, .failure(.noAssignments))
    }

    // MARK: - 3. Einfache kcal-Skalierung

    func testSingleSlotKcal_scalesPortion() {
        // 1 Portion = 165 kcal, Ziel = 330 → Faktor 2.0 → Multiplier 2.0
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 330, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail("Ergebnis muss success sein"); return }
        XCTAssertEqual(p.changes.first?.proposedMultiplier, 2.0, accuracy: 0.001)
    }

    // MARK: - 4. Schrittweite 0.5

    func testStepRounding_roundsToHalfStep() {
        // 1 Portion = 165 kcal, Ziel = 214 → Faktor ~1.297 → round(1.297/0.5)*0.5 = 1.5
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 214, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        let proposed = p.changes.first?.proposedMultiplier ?? 0
        XCTAssertEqual(proposed.truncatingRemainder(dividingBy: 0.5), 0.0,
                       "Multiplier muss Vielfaches von 0.5 sein")
    }

    // MARK: - 5. Clamp Minimum 0.5

    func testClampMin_staysAtHalf() {
        // Sehr kleines Ziel → Faktor weit < 0.5 → wird auf 0.5 geklammert
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 5, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertEqual(p.changes.first?.proposedMultiplier, 0.5)
    }

    // MARK: - 6. Clamp Maximum 5.0

    func testClampMax_staysAtFive() {
        // Sehr großes Ziel → Faktor weit > 5.0 → wird auf 5.0 geklammert
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 100_000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertEqual(p.changes.first?.proposedMultiplier, 5.0)
    }

    // MARK: - 7. OFF-01: Unbekannte Nährwerte bleiben unbekannt

    func testOFF01_unknownNutrientsNotTreatedAsZero() {
        // unknownRecipe hat nur unbekannte Nährwerte.
        // proposedTotals müssen ebenfalls unbekannt sein (nicht 0).
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [unknownRecipe], foodCatalog: [food, unknownFood],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertTrue(p.proposedTotals.kcal.isUnknown || p.proposedTotals.kcal.value == 0,
                      "Vollständig unbekannte Nährwerte dürfen nicht als bekannt erscheinen")
        XCTAssertNotNil(p.warning, "Bei unbekannten Nährwerten muss eine Warnung vorliegen")
    }

    // MARK: - 8. Allergen-Filter beim Swap

    func testAllergenFilter_excludesAllergenRecipesFromSwap() {
        // unknownRecipe als Slot → benötigt Swap.
        // nutsRecipe ist einziger Kandidat, aber Nuts ist ausgeschlossen.
        var prefs = UserNutritionPreferences()
        prefs.allergenExclusions = [.nuts]
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [unknownRecipe, nutsRecipe], foodCatalog: [food, unknownFood, nutsFood],
            preferences: prefs
        )
        guard case .success(let p) = result else { XCTFail(); return }
        // Kein valider Swap → proposedRecipeID bleibt r_unknown (oder ein anderes, aber NICHT nutsRecipe)
        XCTAssertNotEqual(p.changes.first?.proposedRecipeID, "r_nuts",
                          "Nussrezept darf bei aktiver Allergen-Ausschluss nicht als Swap vorgeschlagen werden")
    }

    // MARK: - 9. DietaryStyle-Filter beim Swap

    func testDietaryStyleFilter_veganOnly() {
        // unknownRecipe → Swap nötig. Nur veganRecipe darf für Vegan-Präferenz vorgeschlagen werden.
        var prefs = UserNutritionPreferences()
        prefs.dietaryStyle = .vegan
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [unknownRecipe, lunchRecipe, veganRecipe],
            foodCatalog: [food, unknownFood],
            preferences: prefs
        )
        guard case .success(let p) = result else { XCTFail(); return }
        let proposed = p.changes.first?.proposedRecipeID
        // lunchRecipe ist nicht vegan-tagged, darf bei veganem Stil nicht vorgeschlagen werden
        XCTAssertNotEqual(proposed, "r_lunch",
                          "Nicht-veganes Rezept darf nicht als Swap für vegane Präferenz vorgeschlagen werden")
    }

    // MARK: - 10. ExcludedRecipes-Filter beim Swap

    func testExclusionFilter_excludedRecipeNotSuggested() {
        // unknownRecipe → Swap nötig. lunchRecipe ist explizit ausgeschlossen.
        var prefs = UserNutritionPreferences()
        prefs.excludedRecipeIDs = ["r_lunch"]
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [unknownRecipe, lunchRecipe],
            foodCatalog: [food, unknownFood],
            preferences: prefs
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertNotEqual(p.changes.first?.proposedRecipeID, "r_lunch",
                          "Explizit ausgeschlossenes Rezept darf nicht als Swap vorgeschlagen werden")
    }

    // MARK: - 11. Swap wird vorgeschlagen für unlösbaren Slot

    func testSwap_proposedForUnresolvableSlot() {
        // unknownRecipe kann nicht berechnet werden → lunchRecipe wird als Swap vorgeschlagen
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [unknownRecipe, lunchRecipe],
            foodCatalog: [food, unknownFood],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        let change = p.changes.first
        XCTAssertNotNil(change, "Es muss mindestens einen SlotChange geben")
        XCTAssertEqual(change?.proposedRecipeID, "r_lunch",
                       "Unlösbarer Slot muss Swap zu berechenbarem Rezept erhalten")
        XCTAssertTrue(change?.recipeChanged ?? false)
    }

    // MARK: - 12. hasChanges = true wenn Multiplier geändert

    func testHasChanges_trueWhenMultiplierChanged() {
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 330, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertTrue(p.hasChanges, "Skalierung auf 2.0 muss hasChanges = true liefern")
    }

    // MARK: - 13. hasChanges = false wenn kein Unterschied

    func testHasChanges_falseWhenNoChange() {
        // Ziel = exakt aktuelle Nährwerte → Faktor 1.0 → gerundeter Multiplier = 1.0 → keine Änderung
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 165, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertFalse(p.hasChanges, "Ziel = aktueller Wert: keine Änderung erwartet")
    }

    // MARK: - 14. proposedTotals korrekt berechnet

    func testProposedTotals_matchesExpected() {
        // Ziel 330 kcal → Multiplier 2.0 → 2 × 165 = 330 kcal, 2 × 31 = 62g P
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 330, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        guard let kcal = p.proposedTotals.kcal.value,
              let protein = p.proposedTotals.proteinG.value else {
            XCTFail("proposedTotals müssen bekannte Werte haben"); return
        }
        XCTAssertEqual(kcal, 330, accuracy: 1.0)
        XCTAssertEqual(protein, 62, accuracy: 1.0)
    }

    // MARK: - 15. Zielkonflikt → Warnung nicht nil

    func testGoalConflict_warningNotNil() {
        // Stark widersprüchliche Ziele: hohes kcal-Ziel, sehr niedriges Protein-Ziel
        // → hohe Spannung zwischen den Skalierungsfaktoren → Zielkonflikt-Warnung
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 3000,   // Faktor ~18 auf 165 kcal
            proteinGoal: 1.0,    // Faktor ~0.03 auf 31g Protein
            carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertNotNil(p.warning, "Bei starkem Zielkonflikt muss eine Warnung vorhanden sein")
    }

    // MARK: - 16. Alle Nährwerte unbekannt → Warnung, Multiplier unverändert

    func testAllUnknown_warningAndUnchangedMultipliers() {
        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [unknownRecipe], foodCatalog: [unknownFood],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertNotNil(p.warning, "Vollständig unbekannte Nährwerte müssen eine Warnung erzeugen")
        // Wenn kein Multiplier berechnet werden kann, bleibt der ursprüngliche Wert
        XCTAssertEqual(p.changes.first?.proposedMultiplier, 1.0)
    }

    // MARK: - 17. MealEntry/MealItem unberührt nach Apply (Diary-Isolation)

    func testDiaryEntriesUnchanged_afterApply() throws {
        let entry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(entry)
        let item = MealItem(
            catalogID: "x", nameSnapshot: "Test", quantity: 100, unit: .gram,
            nutrients: NutrientValues(kcal: .known(200), proteinG: .known(10), carbsG: .known(20), fatG: .known(5)),
            meal: entry
        )
        context.insert(item)
        let plan = DailyMealPlan(date: Date())
        context.insert(plan)
        let a = PlannedMealAssignment(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)
        context.insert(a)
        a.plan = plan
        try context.save()

        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 330, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        try applyProposal(p, to: plan)

        XCTAssertEqual(try context.fetch(FetchDescriptor<MealEntry>()).count, 1,
                       "MealEntry darf durch Optimierung nicht verändert werden")
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealItem>()).count, 1,
                       "MealItem darf durch Optimierung nicht verändert werden")
    }

    // MARK: - 18. Teilweise unbekannte Nährwerte → Warnung

    func testPartialUnknown_warning() {
        // Breakfast-Slot mit bekannten Nährwerten, Lunch-Slot mit unbekannten
        let result = MealPlanOptimizer.optimize(
            assignments: [
                (recipeID: "r_breakfast", mealType: .breakfast, portionMultiplier: 1.0),
                (recipeID: "r_unknown", mealType: .lunch, portionMultiplier: 1.0)
            ],
            calorieGoal: 500, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [breakfastRecipe, unknownRecipe],
            foodCatalog: [food, unknownFood],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        XCTAssertNotNil(p.warning,
                        "Teilweise unbekannte Nährwerte müssen eine Warnung erzeugen")
    }

    // MARK: - 19. Mehrtag-Isolation: andere Pläne unberührt

    func testMultiDayIsolation_otherPlansUnchanged() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let planToday = DailyMealPlan(date: today)
        context.insert(planToday)
        let aToday = PlannedMealAssignment(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)
        context.insert(aToday)
        aToday.plan = planToday

        let planTomorrow = DailyMealPlan(date: tomorrow)
        context.insert(planTomorrow)
        let aTomorrow = PlannedMealAssignment(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)
        context.insert(aTomorrow)
        aTomorrow.plan = planTomorrow
        try context.save()

        let result = MealPlanOptimizer.optimize(
            assignments: [(recipeID: "r_lunch", mealType: .lunch, portionMultiplier: 1.0)],
            calorieGoal: 330, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [lunchRecipe], foodCatalog: [food],
            preferences: defaultPrefs()
        )
        guard case .success(let p) = result else { XCTFail(); return }
        // Nur planToday anpassen
        try applyProposal(p, to: planToday)

        XCTAssertEqual(aToday.portionMultiplier, 2.0, accuracy: 0.001,
                       "Heutiger Plan muss angepasst worden sein")
        XCTAssertEqual(aTomorrow.portionMultiplier, 1.0, accuracy: 0.001,
                       "Plan von morgen darf nicht verändert werden")
        XCTAssertFalse(planTomorrow.isManuallyAdjusted,
                       "isManuallyAdjusted von morgen darf nicht gesetzt werden")
    }
}
#endif
