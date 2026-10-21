#if canImport(SwiftData)
import XCTest
@testable import FitnessAppUI
import FitnessAppAI

/// Task F: pure gating for `NutritionDayView`'s optional AI insight section —
/// visible exactly when AI is `.available` AND the day has >=1 meal (Brief).
/// Proves the "KI-Ausfall laesst die normale Tagesuebersicht unveraendert"
/// requirement at the level that's actually testable without rendering
/// SwiftUI: the section is gated off completely for every non-`.available`
/// status, regardless of whether the day has meals.
@available(iOS 17.0, macOS 14.0, *)
final class NutritionInsightVisibilityTests: XCTestCase {

    private static let unavailableStates: [NutritionAIAvailability] = [
        .deviceNotSupported, .appleIntelligenceNotEnabled,
        .languageNotSupported, .temporarilyUnavailable
    ]

    func testUnavailable_neverVisible_evenWithMeals() {
        for status in Self.unavailableStates {
            XCTAssertFalse(
                NutritionInsightVisibility.isVisible(availability: status, hasMeals: true),
                "status \(status) must hide the insight section"
            )
        }
    }

    func testAvailable_butNoMeals_notVisible() {
        XCTAssertFalse(NutritionInsightVisibility.isVisible(availability: .available, hasMeals: false))
    }

    func testAvailable_withMeals_visible() {
        XCTAssertTrue(NutritionInsightVisibility.isVisible(availability: .available, hasMeals: true))
    }
}
#endif
