import XCTest
#if canImport(SwiftUI)
@testable import DeltiqUI

/// UI-Ticket ("Tab-Leiste vereinfachen, Fortschritt unter Mehr integrieren,
/// Werkzeuge als Kacheln", 2026-11-06): loest den main-navigation-Plan-Stand
/// (2026-10-22, Task 1) ab — `AppTab` droppt zusaetzlich `.measurement`
/// (Koerpermessungen werden seltener erfasst als die anderen Hauptbereiche
/// und brauchen deshalb keinen dauerhaft sichtbaren eigenen Tab mehr).
/// Genau vier Tabs bleiben: Heute, Training, Ernaehrung, Mehr.
///
/// `AppTab` itself is a plain UI enum with no runtime logic (per the task
/// brief's own fallback), so `testNutritionCaseExists`/`testMeasurementCaseIsGone`
/// below are really compile-time checks. The tab bar's actual wiring (order,
/// labels, that `.tools`/`.measurement` are gone) lives in
/// `RootView.MainTabView.body`, which has no testable runtime surface either
/// (it only produces opaque `some View`), so those assertions read the
/// source file directly — the same pattern already used by
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
                .deletingLastPathComponent() // DeltiqUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqUI/RootView.swift")
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

    /// UI-Ticket (2026-11-06): `AppTab.measurement` ist komplett entfallen —
    /// weder als eigener Tab-Case (siehe `testTabOrderIsHeuteTrainingErnaehrungMehr`,
    /// das exakt vier `.tag(AppTab....)`-Treffer verlangt) noch als
    /// Referenz irgendwo in RootView. `ProgressOverviewView` haengt
    /// stattdessen eine Ebene tief unter "Mehr" (`ProgressRoute`).
    func testMeasurementTabWiringIsFullyRemoved() throws {
        let source = try rootViewSource
        XCTAssertFalse(
            source.contains("AppTab.measurement"),
            "AppTab.measurement no longer exists; RootView must not reference it."
        )
        XCTAssertTrue(
            source.contains("ProgressRoute"),
            "RootView must register the ProgressRoute destination that replaces the measurement tab."
        )
    }

    func testTabOrderIsHeuteTrainingErnaehrungMehr() throws {
        let source = try rootViewSource
        let tagsInOrder = [
            "AppTab.dashboard",   // Heute
            "AppTab.plan",        // Training
            "AppTab.nutrition",   // Ernährung
            "AppTab.settings"     // Mehr
        ]
        let positions = tagsInOrder.map { source.range(of: ".tag(\($0))") }
        XCTAssertTrue(
            positions.allSatisfy { $0 != nil },
            "All four tabs must be present and tagged in RootView.MainTabView."
        )
        let indices = positions.compactMap { $0?.lowerBound }
        XCTAssertEqual(
            indices, indices.sorted(),
            "Tabs must appear in order: Heute, Training, Ernährung, Mehr."
        )
        // Genau vier `.tag(AppTab....)`-Treffer — kein fuenfter, verwaister Tab.
        let tagCount = source.components(separatedBy: ".tag(AppTab.").count - 1
        XCTAssertEqual(tagCount, 4, "Exactly four tabs must be tagged in RootView.MainTabView.")
    }

    func testNutritionTabHostsNutritionDayView() throws {
        let source = try rootViewSource
        XCTAssertTrue(
            source.contains("NutritionDayView(isTabRoot: true)"),
            "The nutrition tab should host NutritionDayView as its tab root."
        )
    }

    // MARK: - Fortschritt & Messungen unter "Mehr"

    private var settingsViewSource: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/DeltiqUI/Settings/SettingsView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testSettingsViewHasProgressEntryRightAfterProfile() throws {
        let source = try settingsViewSource
        // Suche erst AB der `body`-Deklaration: "groupNavigationSection" taucht
        // vorher bereits in einem Datei-Kopf-Kommentar auf (Begruendung fuer
        // dessen Fuenf-Gruppen-Aufbau) — eine ungebundene `range(of:)`-Suche
        // ueber die GANZE Datei faende diese Kommentar-Erwaehnung zuerst und
        // meldete faelschlich eine falsche Reihenfolge.
        guard let bodyRange = source.range(of: "public var body: some View") else {
            XCTFail("SettingsView must declare `body`.")
            return
        }
        let searchRange = bodyRange.upperBound..<source.endIndex
        let profileRange = source.range(of: "profileSection", range: searchRange)
        let progressRange = source.range(of: "progressSection", range: searchRange)
        let groupRange = source.range(of: "groupNavigationSection", range: searchRange)
        XCTAssertNotNil(progressRange, "SettingsView.body must reference a progressSection.")
        guard let profileRange, let progressRange, let groupRange else { return }
        // Reihenfolge im body: profileSection, progressSection, groupNavigationSection.
        XCTAssertTrue(profileRange.lowerBound < progressRange.lowerBound)
        XCTAssertTrue(progressRange.lowerBound < groupRange.lowerBound)
    }

    func testCalculatorsViewUsesTwoColumnGrid() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Calculators/CalculatorsView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("LazyVGrid"), "CalculatorsView must render its four tools as a grid, not a vertical list.")
        XCTAssertTrue(source.contains("GridItem(.flexible()"), "CalculatorsView's grid must use exactly two fixed columns.")
    }
}
#endif
