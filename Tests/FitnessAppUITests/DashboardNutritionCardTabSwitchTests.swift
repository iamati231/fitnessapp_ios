import XCTest
#if canImport(SwiftUI)
@testable import FitnessAppUI

/// Main-navigation plan (2026-10-22), Task 2: the dashboard's nutrition card
/// must switch to the (now existing, Task 1) nutrition tab instead of
/// pushing a second, duplicate `NutritionDayView` onto the dashboard's own
/// stack.
///
/// `nutritionCard` is a private `@ViewBuilder` property on `DashboardView`
/// that only produces an opaque `some View` — there's no runtime surface to
/// assert against without a SwiftUI rendering harness, which this package
/// doesn't have. Same situation `MainTabStructureTests` already documents
/// for `RootView.MainTabView.body`: read the source file directly.
@available(iOS 17.0, macOS 14.0, *)
final class DashboardNutritionCardTabSwitchTests: XCTestCase {

    private var dashboardViewSource: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // FitnessAppUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/FitnessAppUI/DashboardView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Isolates the `nutritionCard` property body so assertions can't
    /// accidentally pass by matching an unrelated `NutritionDayView()` push
    /// or `selectedTab` assignment elsewhere in the file.
    private func nutritionCardBody(in source: String) throws -> String {
        guard let propStart = source.range(of: "private var nutritionCard: some View {") else {
            XCTFail("nutritionCard property not found in DashboardView.swift")
            return ""
        }
        // The property body ends at the closing brace that returns to the
        // next top-level declaration's doc comment; `todayMeals` is the next
        // property directly below it in the current file layout.
        guard let bodyEnd = source.range(of: "private var todayMeals:", range: propStart.upperBound..<source.endIndex) else {
            XCTFail("could not find end of nutritionCard property body")
            return ""
        }
        return String(source[propStart.upperBound..<bodyEnd.lowerBound])
    }

    func testNutritionCardNoLongerPushesItsOwnNutritionDayView() throws {
        let body = try nutritionCardBody(in: dashboardViewSource)
        XCTAssertFalse(
            body.contains("NutritionDayView()"),
            "nutritionCard must not push a second NutritionDayView onto the dashboard's own stack; the nutrition tab already hosts it as its root (Task 1)."
        )
        XCTAssertFalse(
            body.contains("NavigationLink"),
            "nutritionCard's tap targets must not be NavigationLinks anymore — they switch tabs instead."
        )
    }

    func testNutritionCardSwitchesToNutritionTabInBothBranches() throws {
        let body = try nutritionCardBody(in: dashboardViewSource)
        let occurrences = body.components(separatedBy: "navigation.selectedTab = .nutrition").count - 1
        XCTAssertEqual(
            occurrences, 2,
            "Both the empty-state branch and the populated branch of nutritionCard must set navigation.selectedTab = .nutrition on tap."
        )
    }
}
#endif
