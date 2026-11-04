#if canImport(SwiftUI)
import XCTest

/// Phase F Integrationstests: Sichert die Verdrahtung von
/// `medianFiveKmSeconds` in `CardioGoalEditorView` durch Source-Introspection
/// gegen spaeteres Herausrefaktorieren ab.
///
/// Gleiches Muster wie `DashboardRunReEntryFilterTests` — die
/// relevanten privaten Methoden koennen nicht direkt aufgerufen
/// werden, deshalb wird geprueft, ob die kritischen Bezeichner in
/// der jeweiligen Methode vorhanden sind.
final class CardioBaselineIntegrationTests: XCTestCase {

    private var source: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // DeltiqUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqUI/Settings/CardioGoalEditorView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Schneidet den Body der angegebenen privaten Funktion heraus
    /// (bis zur naechsten `private func`-Grenze, max. 1000 Zeichen).
    private func body(of funcName: String, in src: String, maxLength: Int = 1000) -> Substring? {
        guard let range = src.range(of: "private func \(funcName)") else { return nil }
        return src[range.lowerBound...].prefix(maxLength)
    }

    // MARK: - computeCardioBaseline

    func testComputeUsesMedianWindowConstant() throws {
        let src = try source
        guard let body = body(of: "computeCardioBaseline", in: src) else {
            XCTFail("computeCardioBaseline nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("fiveKmMedianWindowDays"),
            "computeCardioBaseline muss fiveKmMedianWindowDays fuer das 90-Tage-Fenster verwenden"
        )
    }

    func testComputeCallsMedianFiveKmSeconds() throws {
        let src = try source
        guard let body = body(of: "computeCardioBaseline", in: src, maxLength: 1500) else {
            XCTFail("computeCardioBaseline nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("medianFiveKmSeconds"),
            "computeCardioBaseline muss medianFiveKmSeconds aufrufen"
        )
    }

    func testComputePassesMedianToResult() throws {
        let src = try source
        guard let body = body(of: "computeCardioBaseline", in: src, maxLength: 1500) else {
            XCTFail("computeCardioBaseline nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("median5kSeconds"),
            "computeCardioBaseline muss median5kSeconds an CardioBaselineCalculator.Result uebergeben"
        )
    }

    // MARK: - applyCardioBaseline

    func testApplyPrefersMedianOverReference() throws {
        let src = try source
        guard let body = body(of: "applyCardioBaseline", in: src) else {
            XCTFail("applyCardioBaseline nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("median5kSeconds"),
            "applyCardioBaseline muss median5kSeconds (Phase F) als bevorzugte Quelle verwenden"
        )
    }

    // MARK: - cardioLogs (Datenfilterung)

    func testCardioLogsFiltersOnIsRealWorkout() throws {
        let src = try source
        guard let body = body(of: "cardioLogs", in: src) else {
            XCTFail("cardioLogs nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("isRealWorkout"),
            "cardioLogs muss isRealWorkout pruefen — unvollstaendige Sessions duerfen nicht zaehlen"
        )
    }

    func testCardioLogsFiltersOnResolvedIsCardio() throws {
        let src = try source
        guard let body = body(of: "cardioLogs", in: src) else {
            XCTFail("cardioLogs nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("resolvedIsCardio"),
            "cardioLogs muss resolvedIsCardio pruefen — Krafttraining darf nicht als Laufdaten zaehlen"
        )
    }

    func testCardioLogsFiltersOnDateCutoff() throws {
        let src = try source
        guard let body = body(of: "cardioLogs", in: src) else {
            XCTFail("cardioLogs nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertTrue(
            body.contains("startTime"),
            "cardioLogs muss nach startTime filtern — nur Daten innerhalb des Zeitfensters zaehlen"
        )
    }

    // MARK: - applyCardioBaseline Ziel-Minimum-Regression (DEL-251-v2)

    func testApplyDoesNotClampToGoalMinimum() throws {
        let src = try source
        guard let body = body(of: "applyCardioBaseline", in: src) else {
            XCTFail("applyCardioBaseline nicht in CardioGoalEditorView gefunden")
            return
        }
        XCTAssertFalse(
            body.contains("minimumWeeklyVolumeKm"),
            "applyCardioBaseline darf minimumWeeklyVolumeKm NICHT verwenden — Retro-Sync-Wert darf nicht auf Ziel-Minimum angehoben werden (DEL-251-v2)"
        )
    }

    // MARK: - isEmpty-Guard (kein Dialog bei leerer Baseline)

    func testEmptyGuardPresent() throws {
        let src = try source
        XCTAssertTrue(
            src.contains("result.isEmpty"),
            "CardioGoalEditorView muss result.isEmpty pruefen, bevor der Bestaetigungs-Dialog angezeigt wird"
        )
    }
}
#endif
