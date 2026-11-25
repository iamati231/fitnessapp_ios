import XCTest

/// Audit-Fund (Modul 17, MealPlanner-UI). Fuer dieselbe Tagessumme
/// (kcal/Makros) formatierte `dayOverviewSection` zwei unterschiedliche
/// Nachkommastellen-Konventionen, je nachdem ob ein Profil mit Zielen
/// existiert: ohne Ziele blieben echte Nachkommastellen erhalten
/// (`truncated(to: 2)`), mit Zielen wurde zuerst auf 0 Nachkommastellen
/// abgeschnitten und danach ein erzwungenes ",00" angehaengt
/// (`truncated(to: 0).formattedTwoDecimals`) - vorgetaeuschte Praezision,
/// waehrend der Fortschrittsbalken daneben weiterhin mit dem vollen,
/// nicht abgeschnittenen Wert rechnete.
///
/// Fix: `goalProgressRow` nutzt jetzt dieselbe `truncated(to: 2)`-Konvention
/// wie die No-Goals-Zeile direkt daneben.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class MealPlannerViewGoalProgressDecimalPrecisionTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Nutrition/MealPlannerView.swift"),
                encoding: .utf8
            )
        }
    }

    func testGoalProgressRowUsesRealTwoDecimalPrecisionNotFakeZero() throws {
        let text = try source
        guard let start = text.range(of: "private func goalProgressRow(_ row: GoalRow, showsDivider: Bool) -> some View {") else {
            return XCTFail("goalProgressRow(_:showsDivider:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of goalProgressRow not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("truncated(to: 0)"),
                       "goalProgressRow must not truncate to 0 decimals and then force fake trailing zeros")
        XCTAssertTrue(body.contains("current.truncated(to: 2)") && body.contains("row.goal.truncated(to: 2)"),
                      "goalProgressRow must show real 2-decimal precision, consistent with the no-goals row next to it")
    }
}
