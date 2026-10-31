#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
@testable import FitnessAppCore

/// Phase 5.1: Tests für WeekPlannerView-Logik.
/// Datumsberechnungen, Wochennavigation, Nährwerte, OFF-01.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class WeekPlannerTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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

    private lazy var knownRecipe = Recipe(
        id: "r_known", nameKey: "t.known",
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

    // Woche beginnt am Montag (weekday=2 in ISO-Kalender)
    func testWeekStartsOnMonday() {
        let monday = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 11, 1)) // 1. Nov 2026 ist Samstag
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        // ISO: weekday() gibt 7 für Samstag, aber mit firstWeekday=2 ist Montag=1
        XCTAssertEqual(cal.component(.weekday, from: monday), 2, "Woche muss mit Montag beginnen")
    }

    // Woche endet am Sonntag
    func testWeekEndsOnSunday() {
        let monday = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 11, 1))
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday)!
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        XCTAssertEqual(cal.component(.weekday, from: sunday), 1, "Woche endet am Sonntag (weekday=1 in gregorianischem Kalender)")
    }

    // Monatswechsel: 31. Okt → 1. Nov in einer Woche
    func testMonthBoundary() {
        let monday = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 10, 26))
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: monday) }
        let months = Set(days.map { Calendar.current.component(.month, from: $0) })
        XCTAssertTrue(months.count > 1, "Woche KW44-2026 enthält Oktober und November")
    }

    // Jahreswechsel: 28. Dez → 3. Jan in einer Woche
    func testYearBoundary() {
        let monday = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 12, 28))
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: monday) }
        let years = Set(days.map { Calendar.current.component(.year, from: $0) })
        XCTAssertTrue(years.count > 1, "Letzte Dezember-Woche 2026 enthält 2026 und 2027")
    }

    // Schaltjahr: 2028 hat 29. Feb
    func testLeapYear() {
        let feb28 = date(2028, 2, 28)
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: feb28) }
        let hasFeb29 = days.contains {
            Calendar.current.component(.month, from: $0) == 2 &&
            Calendar.current.component(.day, from: $0) == 29
        }
        XCTAssertTrue(hasFeb29, "2028 ist Schaltjahr — 29. Feb muss erscheinen")
    }

    // Navigation: vorherige Woche
    func testPrevWeekNavigation() {
        let thisMonday = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 11, 4))
        let prevMonday = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisMonday)!
        let expected = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 10, 26))
        XCTAssertEqual(Calendar.current.startOfDay(for: prevMonday), Calendar.current.startOfDay(for: expected))
    }

    // Navigation: nächste Woche
    func testNextWeekNavigation() {
        let thisMonday = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 11, 4))
        let nextMonday = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: thisMonday)!
        let expected = WeekPlannerViewTestHelper.mondayOfWeek(containing: date(2026, 11, 9))
        XCTAssertEqual(Calendar.current.startOfDay(for: nextMonday), Calendar.current.startOfDay(for: expected))
    }

    // Rückkehr zur aktuellen Woche
    func testReturnToCurrentWeek() {
        let currentMonday = WeekPlannerViewTestHelper.mondayOfWeek(containing: Date())
        let todayMonday = WeekPlannerViewTestHelper.currentWeekMonday()
        XCTAssertEqual(Calendar.current.startOfDay(for: currentMonday), Calendar.current.startOfDay(for: todayMonday))
    }

    // Tagesplan wird dem korrekten Datum zugeordnet
    func testPlanAssignedToCorrectDate() throws {
        let targetDate = date(2026, 11, 3)
        let plan = DailyMealPlan(date: targetDate)
        context.insert(plan)
        try context.save()

        let descriptor = FetchDescriptor<DailyMealPlan>(
            predicate: #Predicate { $0.date == Calendar.current.startOfDay(for: targetDate) }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(Calendar.current.component(.day, from: fetched.first!.date), 3)
        XCTAssertEqual(Calendar.current.component(.month, from: fetched.first!.date), 11)
    }

    // Tag ohne Tagesplan: nil zurückgeben
    func testDayWithoutPlanReturnsNil() throws {
        let day = date(2026, 11, 5)
        let allPlans: [DailyMealPlan] = try context.fetch(FetchDescriptor<DailyMealPlan>())
        let normalized = Calendar.current.startOfDay(for: day)
        let plan = allPlans.first { $0.date == normalized }
        XCTAssertNil(plan, "Tag ohne Plan muss nil ergeben — nicht als 0 kcal behandeln")
    }

    // Kalorien und Makros stimmen mit Tagesplan überein
    func testNutrientsMatchPlan() throws {
        let day = date(2026, 11, 4)
        let plan = DailyMealPlan(date: day)
        let assignment = PlannedMealAssignment(recipeID: "r_known", mealType: .lunch, portionMultiplier: 1.0)
        context.insert(plan)
        plan.assignments.append(assignment)
        try context.save()

        let result = RecipeNutritionCalculator.nutrients(for: knownRecipe, catalog: [food], portionMultiplier: 1.0)
        guard case .success(let n) = result else { XCTFail("Berechnung schlug fehl"); return }
        XCTAssertEqual(n.kcal.value, 165, accuracy: 0.01)
        XCTAssertEqual(n.proteinG.value, 31, accuracy: 0.01)
    }

    // Portionsfaktoren werden berücksichtigt
    func testPortionMultiplierApplied() {
        let result = RecipeNutritionCalculator.nutrients(for: knownRecipe, catalog: [food], portionMultiplier: 2.0)
        guard case .success(let n) = result else { XCTFail(); return }
        XCTAssertEqual(n.kcal.value, 330, accuracy: 0.01)
        XCTAssertEqual(n.proteinG.value, 62, accuracy: 0.01)
    }

    // OFF-01: Unbekannte Nährwerte bleiben unbekannt
    func testOFF01_unknownNutrientsRemainUnknown() {
        let result = RecipeNutritionCalculator.nutrients(for: unknownRecipe, catalog: [unknownFood], portionMultiplier: 1.0)
        guard case .success(let n) = result else { XCTFail(); return }
        XCTAssertTrue(n.kcal.isUnknown, "kcal muss unbekannt bleiben")
        XCTAssertTrue(n.proteinG.isUnknown, "Protein muss unbekannt bleiben")
        XCTAssertTrue(n.partiallyKnown, "partiallyKnown muss true sein")
    }

    // Öffnen eines Tages übergibt korrektes Datum (Route-Check)
    func testDayNavigationPassesCorrectDate() {
        let day = date(2026, 11, 5)
        let route = MealPlannerRoute.plannerDay(day)
        if case .plannerDay(let routeDate) = route {
            XCTAssertEqual(Calendar.current.startOfDay(for: routeDate), Calendar.current.startOfDay(for: day))
        } else {
            XCTFail("Route muss .plannerDay sein")
        }
    }

    // Bestehende Tagesansicht bleibt intakt — allPlans-Query unverändert
    func testExistingDayViewUnchanged() throws {
        let day = date(2026, 11, 4)
        let plan = DailyMealPlan(date: day)
        context.insert(plan)
        try context.save()

        let allPlans: [DailyMealPlan] = try context.fetch(FetchDescriptor<DailyMealPlan>())
        let normalized = Calendar.current.startOfDay(for: day)
        let fetched = allPlans.first { $0.date == normalized }
        XCTAssertNotNil(fetched, "Tagesplan muss weiterhin via allPlans-Query erreichbar sein")
        XCTAssertFalse(fetched!.isManuallyAdjusted, "Neu angelegter Plan darf nicht manuallyAdjusted sein")
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar.current.date(from: comps)!
    }
}

/// Testhelfer: Zugriff auf private Datumsfunktionen aus WeekPlannerView.
/// Dupliziert die Logik um SwiftUI-Abhängigkeit zu vermeiden.
enum WeekPlannerViewTestHelper {
    static func currentWeekMonday(calendar: Calendar = .current) -> Date {
        mondayOfWeek(containing: Date(), calendar: calendar)
    }

    static func mondayOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
}
#endif
