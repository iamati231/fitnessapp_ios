import XCTest

/// Regression guard: keiner der vier Haupt-Tab-Root-Views darf eine
/// `Color.clear.frame(height: 0)` als Scroll-Anker-Zeile verwenden.
/// Innerhalb eines VStack(spacing: N) belegt ein solches Element zwar
/// keine eigene Hoehe, erzeugt aber trotzdem N pt Leerraum durch den
/// VStack-Spacing-Mechanismus (Spacing zwischen benachbarten Views).
/// Korrekte Alternativen: `.id()` direkt auf den ersten sichtbaren View
/// (PlansListView-Muster) oder auf den umgebenden VStack (Dashboard-/
/// Settings-Muster).
final class TabScrollAnchorRegressionTests: XCTestCase {

    private func readSource(_ name: String, path: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testDashboardHasNoInvisibleScrollAnchorRow() throws {
        let src = try readSource("DashboardView", path: "Sources/DeltiqUI/DashboardView.swift")
        XCTAssertFalse(
            src.contains("Color.clear.frame(height: 0).id(\"dashboard-top\")"),
            "Color.clear.frame(height: 0) als Scroll-Anker im VStack erzeugt ungewollten VStack-Spacing-Leerraum"
        )
        XCTAssertTrue(
            src.contains(".id(\"dashboard-top\")"),
            "Scroll-Anker 'dashboard-top' muss weiterhin vorhanden sein"
        )
    }

    func testSettingsHasNoInvisibleScrollAnchorRow() throws {
        let src = try readSource("SettingsView", path: "Sources/DeltiqUI/Settings/SettingsView.swift")
        XCTAssertFalse(
            src.contains("Color.clear.frame(height: 0).id(\"settings-top\")"),
            "Color.clear.frame(height: 0) als Scroll-Anker im VStack erzeugt ungewollten VStack-Spacing-Leerraum"
        )
        XCTAssertTrue(
            src.contains(".id(\"settings-top\")"),
            "Scroll-Anker 'settings-top' muss weiterhin vorhanden sein"
        )
    }
}
