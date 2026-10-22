import XCTest
#if canImport(SwiftUI)
@testable import FitnessAppUI

/// Main-navigation plan (2026-10-22), Task 3: closes the gap Task 1 left open
/// — the water-tracker reminder deep link must land directly on
/// `WaterTrackerView`, not just on the "Mehr" (Settings) tab root.
///
/// `CalculatorsView` moves from its own tab root to a `NavigationLink` nested
/// one level under `SettingsView`'s `groupNavigationSection`. The deep link
/// reuses `AppNavigation.toolsPath` + `CalculatorsRoute`, now bound to the
/// Settings tab's `NavigationStack` instead of a dedicated Werkzeuge tab.
///
/// Neither `RootView.MainTabView.body` nor `applyPendingRouteIfAny()` nor
/// `SettingsView.groupNavigationSection` have a testable runtime surface
/// (opaque `some View` / private methods) — same situation already
/// documented by `MainTabStructureTests` and
/// `DashboardNutritionCardTabSwitchTests`. These tests read the source files
/// directly, the established pattern in this suite.
@available(iOS 17.0, macOS 14.0, *)
final class WaterTrackerDeepLinkTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Isolates `applyPendingRouteIfAny()`'s body so assertions can't
    /// accidentally match an unrelated `.settings`/`.toolsPath` reference
    /// elsewhere in the file.
    private func applyPendingRouteBody(in source: String) throws -> String {
        guard let start = source.range(of: "private func applyPendingRouteIfAny() {") else {
            XCTFail("applyPendingRouteIfAny() not found in RootView.swift")
            return ""
        }
        guard let end = source.range(of: "private func configureTabBarAppearance", range: start.upperBound..<source.endIndex) else {
            XCTFail("could not find end of applyPendingRouteIfAny()")
            return ""
        }
        return String(source[start.upperBound..<end.lowerBound])
    }

    func testWaterTrackerDeepLinkSwitchesTabAndPushesCalculatorsRoute() throws {
        let body = try applyPendingRouteBody(in: try source("RootView.swift"))
        XCTAssertTrue(
            body.contains("navigation.selectedTab = .settings"),
            "The water-tracker deep link must still switch to the Settings (Mehr) tab."
        )
        XCTAssertTrue(
            body.contains("navigation.toolsPath = NavigationPath()"),
            "The deep link must reset toolsPath before pushing, so it always lands exactly on WaterTrackerView."
        )
        XCTAssertTrue(
            body.contains("navigation.toolsPath.append(CalculatorsRoute.waterTracker)"),
            "The deep link must push CalculatorsRoute.waterTracker onto toolsPath — the single-hop route to WaterTrackerView."
        )
    }

    /// Verifies the Settings tab's `NavigationStack` is the one bound to
    /// `toolsPath` and the one that resolves `CalculatorsRoute` to
    /// `WaterTrackerView` — not a leftover from the removed `.tools` tab.
    func testSettingsNavigationStackIsBoundToToolsPathAndResolvesWaterTracker() throws {
        let rootViewSource = try source("RootView.swift")
        guard let stackStart = rootViewSource.range(of: "NavigationStack(path: $navigation.toolsPath) {") else {
            XCTFail("Settings tab's NavigationStack must be bound to navigation.toolsPath")
            return
        }
        guard let stackEnd = rootViewSource.range(of: ".tag(AppTab.settings)", range: stackStart.upperBound..<rootViewSource.endIndex) else {
            XCTFail("could not find end of the Settings tab block")
            return
        }
        let settingsTabBlock = String(rootViewSource[stackStart.upperBound..<stackEnd.lowerBound])
        XCTAssertTrue(
            settingsTabBlock.contains("SettingsView()"),
            "The toolsPath-bound stack must still host SettingsView as its root."
        )
        XCTAssertTrue(
            settingsTabBlock.contains(".navigationDestination(for: CalculatorsRoute.self)"),
            "The Settings tab's stack must resolve CalculatorsRoute, so the deep-link push lands somewhere."
        )
        XCTAssertTrue(
            settingsTabBlock.contains("WaterTrackerView()"),
            "CalculatorsRoute.waterTracker must resolve to WaterTrackerView directly, not to CalculatorsView."
        )
    }

    func testToolsTabNoLongerExistsInRootView() throws {
        let rootViewSource = try source("RootView.swift")
        XCTAssertFalse(
            rootViewSource.contains("AppTab.tools"),
            "AppTab.tools no longer exists (Task 1); RootView must not reference it."
        )
    }

    /// Verifies the normal, tapped path: a 5th row in SettingsView's grouped
    /// navigation pushes to CalculatorsView, the same DeltiqRow/NavigationLink
    /// convention as the 4 existing rows.
    func testSettingsGroupNavigationLinksToCalculatorsView() throws {
        let settingsSource = try source("Settings/SettingsView.swift")
        guard let start = settingsSource.range(of: "private var groupNavigationSection: some View {") else {
            XCTFail("groupNavigationSection not found in SettingsView.swift")
            return
        }
        guard let end = settingsSource.range(of: "private func hintRow", range: start.upperBound..<settingsSource.endIndex) else {
            XCTFail("could not find end of groupNavigationSection")
            return
        }
        let sectionBody = String(settingsSource[start.upperBound..<end.lowerBound])
        XCTAssertTrue(
            sectionBody.contains("CalculatorsView()"),
            "groupNavigationSection must gain a 5th NavigationLink to CalculatorsView (Werkzeuge moves under Mehr)."
        )
        let navigationLinkCount = sectionBody.components(separatedBy: "NavigationLink {").count - 1
        XCTAssertEqual(
            navigationLinkCount, 5,
            "groupNavigationSection should now have 5 NavigationLinks: the 4 existing groups plus CalculatorsView."
        )
    }

    /// `CalculatorsView` is no longer a tab root, so it needs a back
    /// affordance (DeltiqHeader onBack + restored swipe-back gesture) — the
    /// same pattern every other Settings-nested screen uses.
    func testCalculatorsViewHasBackNavigation() throws {
        let calculatorsSource = try source("Calculators/CalculatorsView.swift")
        XCTAssertTrue(
            calculatorsSource.contains("onBack: { dismiss() }"),
            "CalculatorsView is now pushed under SettingsView and needs a back button."
        )
        XCTAssertTrue(
            calculatorsSource.contains(".deltiqSwipeBackEnabled()"),
            "CalculatorsView must restore the swipe-back gesture lost to .navigationBarBackButtonHidden(true)."
        )
    }
}
#endif
