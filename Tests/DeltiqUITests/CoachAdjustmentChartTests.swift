#if canImport(SwiftUI)
import XCTest

/// Follow-up-Ticket ("Lauftrainingsaufbau - Diagramm verbessern", 2026-11-06):
/// Trainingsaufbau-Chart in `CoachAdjustmentPreviewView` bekommt lesbare
/// Wochen-/Achsenbeschriftung, interaktive Balkenauswahl, Phasen-Darstellung
/// und eine dynamische Coaching-Erklaerung. Source-introspection (kein
/// SwiftUI-Render-Harness - `DeltiqUI` kann auf diesem Windows-Host nicht
/// gebaut/ausgefuehrt werden), gleiches Muster wie
/// `CoachAdjustmentInsertionUITests`.
final class CoachAdjustmentChartTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private var viewSource: String {
        get throws { try contents(of: "Cardio/CoachAdjustmentPreviewView.swift") }
    }

    // MARK: - Part 1: dynamische, eindeutige Achsenbeschriftung

    func testWeekAxisLabelIsDynamicNotHardcodedWPrefix() throws {
        let source = try viewSource
        XCTAssertFalse(source.contains("\"W\\(w)\""), "Die alte 'W0'-Kurzform darf nicht mehr vorkommen.")
        XCTAssertTrue(source.contains("weekLabel(w)"), "Die X-Achse muss die lokalisierte weekLabel-Beschriftung nutzen.")
    }

    func testYAxisHasALocalizedTitleLabel() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains(".chartYAxisLabel"), "Die Y-Achse muss einen Titel tragen (\"Laufumfang (km/Woche)\").")
        XCTAssertTrue(source.contains("profile.cardio.adjustment.chart.yAxisLabel"))
    }

    // MARK: - Part 2: interaktive Balkenauswahl

    func testChartUsesNativeXSelection() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains(".chartXSelection(value: $selectedChartWeek)"))
    }

    func testBarsCarryVoiceOverAccessibilityLabels() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains(".accessibilityLabel(weekLabel(points[i].week))"))
        XCTAssertTrue(source.contains(".accessibilityValue("))
    }

    func testSelectionDetailOnlyShowsDeltaWhenAPreviousWeekExists() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains("if i > 0"), "Keine Veraenderung-zur-Vorwoche-Zeile ohne vorherige Woche (Woche 0).")
        XCTAssertTrue(source.contains("profile.cardio.adjustment.chart.weekDelta"))
    }

    // MARK: - Part 3: Trainingsphasen aus echten Daten

    func testChartColorsAndLegendAreDerivedFromChartPhases() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains("CardioFeasibilityCalculator.chartPhases(for: points)"))
        XCTAssertTrue(source.contains("phaseColor(phases[i])"), "Balkenfarbe muss aus der abgeleiteten Phase kommen, nicht fest codiert sein.")
    }

    func testPhaseColorsStayWithinTheExistingAccentColorFamily() throws {
        let source = try viewSource
        guard let range = source.range(of: "private func phaseColor") else {
            XCTFail("phaseColor(_:) nicht gefunden.")
            return
        }
        let body = source[range.lowerBound...].prefix(400)
        XCTAssertTrue(body.contains("Color.deltiqOrange"), "Phasenfarben muessen Abstufungen der bestehenden Akzentfarbe sein, keine neue Farbe.")
        XCTAssertFalse(body.contains("Color.red") || body.contains("Color.blue") || body.contains("Color.green"))
    }

    // MARK: - Part 5: dynamische Coaching-Erklaerung

    func testCoachingExplanationHasFourDataDrivenVariants() throws {
        let source = try viewSource
        for key in [
            "profile.cardio.adjustment.chart.explanation.rampAndTaper",
            "profile.cardio.adjustment.chart.explanation.rampNoTaper",
            "profile.cardio.adjustment.chart.explanation.alreadyAtTargetWithTaper",
            "profile.cardio.adjustment.chart.explanation.steady",
        ] {
            XCTAssertTrue(source.contains(key), "Fehlender Erklaerungs-Key: \(key)")
        }
    }

    // MARK: - Part 6: keine zweite Berechnungslogik

    func testChartReusesExistingProjectionAndPhaseCalculatorNotANewOne() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains("CardioFeasibilityCalculator.weeklyVolumeProjection("))
        XCTAssertTrue(source.contains("CardioFeasibilityCalculator.chartPhases(for: points)"))
        // Kein eigenes Ramp-/Taper-Prozent in der View - das bleibt exklusiv in DeltiqCore.
        XCTAssertFalse(source.contains("0.10") , "Kein eigener Rampen-Prozentsatz in der View - das ist DeltiqCore.maxWeeklyRampPercent.")
    }
}
#endif
