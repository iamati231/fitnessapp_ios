#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DailyMealPlanTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testInit_normalizesDateToStartOfDay() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let plan = DailyMealPlan(date: date)
        let expected = Calendar.current.startOfDay(for: date)
        XCTAssertEqual(plan.date, expected, "DailyMealPlan.init muss Datum auf Tagesbeginn normalisieren")
    }

    func testFetchOrCreate_sameDay_returnsSamePlan() throws {
        // container muss benannt bleiben — ModelContext hält keine starke Referenz auf ModelContainer
        let container = try makeContainer()
        let ctx = container.mainContext
        let date = Date(timeIntervalSince1970: 1_000_000)

        let plan1 = try DailyMealPlan.fetchOrCreate(for: date, in: ctx)
        let plan2 = try DailyMealPlan.fetchOrCreate(for: date, in: ctx)

        XCTAssertTrue(plan1 === plan2, "Gleicher Tag muss gleichen Plan liefern")
    }

    func testFetchOrCreate_differentTimeSameDay_returnsSamePlan() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_000_000))
        let morning = dayStart.addingTimeInterval(3_600)   // 01:00
        let evening = dayStart.addingTimeInterval(72_000)  // 20:00

        let plan1 = try DailyMealPlan.fetchOrCreate(for: morning, in: ctx)
        let plan2 = try DailyMealPlan.fetchOrCreate(for: evening, in: ctx)

        XCTAssertTrue(plan1 === plan2, "Verschiedene Uhrzeiten am selben Tag müssen denselben Plan liefern")
    }

    func testFetchOrCreate_differentDays_returnsDifferentPlans() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let day1 = Date(timeIntervalSince1970: 1_000_000)
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: day1))!

        let plan1 = try DailyMealPlan.fetchOrCreate(for: day1, in: ctx)
        let plan2 = try DailyMealPlan.fetchOrCreate(for: day2, in: ctx)

        XCTAssertFalse(plan1 === plan2, "Verschiedene Tage müssen verschiedene Pläne liefern")
    }

    func testUpsertGenerated_generatedPlan_isOverwritten() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let date = Date(timeIntervalSince1970: 1_000_000)

        let a1 = PlannedMealAssignment(recipeID: "r1", mealType: .lunch)
        _ = try DailyMealPlan.upsertGenerated(date: date, assignments: [a1], warning: nil, in: ctx)

        let a2 = PlannedMealAssignment(recipeID: "r2", mealType: .dinner)
        let updated = try DailyMealPlan.upsertGenerated(date: date, assignments: [a2], warning: "W", in: ctx)

        let plan = try DailyMealPlan.fetchOrCreate(for: date, in: ctx)
        XCTAssertTrue(updated, "Generierter Plan muss überschreibbar sein")
        XCTAssertEqual(plan.assignments.count, 1)
        XCTAssertEqual(plan.assignments.first?.recipeID, "r2")
        XCTAssertEqual(plan.generatorWarning, "W")
    }

    func testUpsertGenerated_manuallyAdjustedPlan_isNotOverwritten() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let date = Date(timeIntervalSince1970: 1_000_000)

        let plan = try DailyMealPlan.fetchOrCreate(for: date, in: ctx)
        plan.isManuallyAdjusted = true

        let a = PlannedMealAssignment(recipeID: "r1", mealType: .lunch)
        let updated = try DailyMealPlan.upsertGenerated(date: date, assignments: [a], warning: nil, in: ctx)

        XCTAssertFalse(updated, "Manuell angepasster Plan darf nicht überschrieben werden")
        XCTAssertTrue(plan.assignments.isEmpty, "Assignments dürfen nicht verändert worden sein")
    }
}
#endif
