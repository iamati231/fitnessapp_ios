import XCTest
#if canImport(SwiftUI)
@testable import FitnessAppUI

/// Main-navigation plan (2026-10-22), Task 1: `AppTab` gains `.nutrition` and
/// drops `.tools` (Werkzeuge leaves the tab bar; its wiring moves to a
/// Settings-nested path in a later, not-yet-dispatched task of the same
/// plan).
///
/// `AppTab` itself is a plain UI enum with no runtime logic (per the task
/// brief's own fallback), so `testNutritionCaseExists` below is really a
/// compile-time check: this file simply wouldn't build without `.nutrition`.
/// The tab bar's actual wiring (order, labels, that `.tools` is gone) lives
/// in `RootView.MainTabView.body`, which has no testable runtime surface
/// either (it only produces opaque `some View`), so those assertions read
/// the source file directly — the same pattern already used by
/// `DeltiqLabelScalesDownInsteadOfWrappingTests`.
@available(iOS 17.0, macOS 14.0, *)
final class MainTabStructureTests: XCTestCase {

    func testNutritionCaseExists() {
        let tab: AppTab = .nutrition
        XCTAssertEqual(tab, .nutrition)
    }

    private var rootViewSource: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // FitnessAppUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/FitnessAppUI/RootView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testToolsTabWiringIsFullyRemoved() throws {
        let source = try rootViewSource
        XCTAssertFalse(
            source.contains("AppTab.tools"),
            "AppTab.tools no longer exists; RootView must not reference it."
        )
    }

    func testTabOrderIsHeuteTrainingErnaehrungFortschrittMehr() throws {
        let source = try rootViewSource
        let tagsInOrder = [
            "AppTab.dashboard",   // Heute
            "AppTab.plan",        // Training
            "AppTab.nutrition",   // Ernährung
            "AppTab.measurement", // Fortschritt
            "AppTab.settings"     // Mehr
        ]
        let positions = tagsInOrder.map { source.range(of: ".tag(\($0))") }
        XCTAssertTrue(
            positions.allSatisfy { $0 != nil },
            "All five tabs must be present and tagged in RootView.MainTabView."
        )
        let indices = positions.compactMap { $0?.lowerBound }
        XCTAssertEqual(
            indices, indices.sorted(),
            "Tabs must appear in order: Heute, Training, Ernährung, Fortschritt, Mehr."
        )
    }

    func testNutritionTabHostsNutritionDayView() throws {
        let source = try rootViewSource
        XCTAssertTrue(
            source.contains("NutritionDayView(isTabRoot: true)"),
            "The nutrition tab should host NutritionDayView as its tab root."
        )
    }
}
#endif
