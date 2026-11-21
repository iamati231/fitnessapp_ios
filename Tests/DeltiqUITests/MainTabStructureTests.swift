import XCTest
#if canImport(SwiftUI) && canImport(UIKit)
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

    func testTabOrderIsHeuteTrainingFortschrittErnaehrungMehr() throws {
        let source = try rootViewSource
        let tagsInOrder = [
            "AppTab.dashboard",   // Heute
            "AppTab.plan",        // Training
            "AppTab.progress",    // Fortschritt (Issue #49: vor Ernährung)
            "AppTab.nutrition",   // Ernährung
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
            "Tabs must appear in order: Heute, Training, Fortschritt, Ernährung, Mehr."
        )
        // Genau fünf `.tag(AppTab....)`-Treffer — kein sechster, verwaister Tab.
        let tagCount = source.components(separatedBy: ".tag(AppTab.").count - 1
        XCTAssertEqual(tagCount, 5, "Exactly five tabs must be tagged in RootView.MainTabView.")
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

    // MARK: - Fortschritt-Tab ProgressRoute Navigation

    func testProgressTabRegistersProgressRouteDestination() throws {
        let source = try rootViewSource
        // ProgressRoute must be registered inside the progress NavigationStack
        // (before .tag(AppTab.progress)) so programmatic pushes via progressPath work.
        guard let progressTagRange = source.range(of: ".tag(AppTab.progress)") else {
            XCTFail("AppTab.progress tag not found in RootView.swift")
            return
        }
        let beforeProgressTag = String(source[source.startIndex..<progressTagRange.lowerBound])
        // The registration must appear after the progress NavStack opens
        guard let navStackRange = beforeProgressTag.range(of: "progressPath)", options: .backwards) else {
            XCTFail("progressPath NavigationStack not found before .tag(AppTab.progress)")
            return
        }
        let progressNavSection = String(beforeProgressTag[navStackRange.upperBound...])
        XCTAssertTrue(
            progressNavSection.contains("ProgressRoute.self"),
            "The progress NavigationStack must register ProgressRoute destinations so programmatic navigation via progressPath works."
        )
    }

    func testProgressMeasurementCTAUsesProgressPath() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/DashboardView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        // CTA must navigate to progress tab via progressPath, not settings/toolsPath
        guard let ctaRange = source.range(of: "ctaAction:") else {
            XCTFail("ctaAction not found in DashboardView.swift")
            return
        }
        // Find the measurement CTA block (after the first ctaAction occurrence near dashboard.empty.cta.addMeasurement)
        guard let ctaKeyRange = source.range(of: "dashboard.empty.cta.addMeasurement") else {
            XCTFail("dashboard.empty.cta.addMeasurement not found")
            return
        }
        let searchStart = min(ctaKeyRange.lowerBound, ctaRange.lowerBound)
        let ctaBlock = String(source[searchStart...]).prefix(400)
        XCTAssertTrue(
            ctaBlock.contains("navigation.selectedTab = .progress"),
            "Measurement CTA must switch to AppTab.progress."
        )
        XCTAssertTrue(
            ctaBlock.contains("navigation.progressPath.append(ProgressRoute.addMeasurement)"),
            "Measurement CTA must push ProgressRoute.addMeasurement (direct to MeasurementView), not overview."
        )
        XCTAssertFalse(
            ctaBlock.contains("navigation.toolsPath"),
            "Measurement CTA must not route through toolsPath (Mehr tab)."
        )
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
