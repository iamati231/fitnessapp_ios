#if canImport(SwiftUI)
import XCTest

/// Follow-up-Ticket ("Lauftrainingsaufbau - Diagramm verbessern", 2026-11-06)
/// plus dessen Review-Korrektur ("Wochenzuordnung, UI-Tests und
/// Coaching-Erklaerungen korrigieren", 2026-11-06): Trainingsaufbau-Chart in
/// `CoachAdjustmentPreviewView` bekommt lesbare Wochen-/Achsenbeschriftung,
/// interaktive Balkenauswahl, Phasen-Darstellung und eine dynamische
/// Coaching-Erklaerung.
///
/// WICHTIGE EINSCHRAENKUNG (Review-Fix Teil 2): dies ist ausschliesslich
/// Source-Introspection (Text-Suche in der `.swift`-Datei), KEIN
/// SwiftUI-Render-Harness - es gibt in diesem Repo keinen, der auf diesem
/// Windows-Host liefe (gleiches Muster wie `CoachAdjustmentInsertionUITests`).
/// Ein gruener Lauf bestaetigt NUR, dass die erwarteten Code-Strukturen im
/// Quelltext vorhanden sind - NICHT, dass Balkenauswahl, Chart-Rendering
/// oder VoiceOver tatsaechlich wie beschrieben funktionieren. Das bleibt
/// Aufgabe von CI (macOS) bzw. manueller/Geraete-Pruefung.
final class CoachAdjustmentChartTests: XCTestCase {

    /// Review-Fix (Teil 2): eine fest codierte Anzahl `.deletingLastPathComponent()`-
    /// Aufrufe nimmt an, auf welcher Verzeichnistiefe `Package.swift` liegt -
    /// bricht lautlos falsch, sobald sich die Repo-Struktur aendert. Stattdessen
    /// laeuft dies von `#filePath` aus nach oben, bis `Package.swift` gefunden
    /// wird (oder bis zur Laufwerkswurzel, dann ein klarer Fehlschlag statt
    /// eines stillen Fehlverhaltens).
    private struct SourceFileNotFoundError: Error, CustomStringConvertible {
        let path: String
        var description: String {
            "Quelldatei nicht gefunden unter \(path) - Repo-Layout hat sich moeglicherweise geaendert."
        }
    }

    private func findRepoRoot(startingAt filePath: String = #filePath) throws -> URL {
        var dir = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        while true {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            guard parent.path != dir.path else {
                throw SourceFileNotFoundError(path: "Package.swift (von \(filePath) aus nach oben gesucht)")
            }
            dir = parent
        }
    }

    private func contents(of relativePath: String) throws -> String {
        let url = try findRepoRoot().appendingPathComponent("Sources/DeltiqUI").appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SourceFileNotFoundError(path: url.path)
        }
        return try String(contentsOf: url, encoding: .utf8)
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

    /// Review-Fix (Teil 1): `week + 1` verschob jede Beschriftung um eine
    /// Woche (Woche 1 zeigte faelschlich "Woche 2"). `weeklyVolumeProjection`s
    /// `week`-Feld ist bereits die echte Trainingswochen-Nummer - keine
    /// zusaetzliche Addition mehr, und Woche 0 (Ausgangspunkt) bekommt eine
    /// eigene Beschriftung statt "Woche 0"/"Woche 1".
    func testWeekLabelNoLongerShiftsByOneAndDistinguishesWeekZero() throws {
        let source = try viewSource
        XCTAssertFalse(source.contains("week + 1"), "Keine pauschale +1-Verschiebung mehr - week ist bereits die echte Wochennummer.")
        guard let range = source.range(of: "private func weekLabel") else {
            XCTFail("weekLabel(_:) nicht gefunden.")
            return
        }
        let body = source[range.lowerBound...].prefix(500)
        XCTAssertTrue(body.contains("week > 0"), "Woche 0 (Ausgangspunkt) muss von echten Trainingswochen unterschieden werden.")
        XCTAssertTrue(body.contains("profile.cardio.adjustment.chart.weekLabel.current"), "Woche 0 braucht eine eigene Beschriftung (\"Aktuell\"), nicht \"Woche 0\"/\"Woche 1\".")
    }

    /// Review-Fix (Teil 1): Achse und Auswahl-Panel duerfen nie auseinander-
    /// laufen - beide rufen dieselbe `weekLabel(_:)`-Funktion auf, es gibt
    /// keine zweite, duplizierte Formatierung.
    func testSelectionPanelUsesTheSameWeekLabelFunctionAsTheAxis() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains("Text(weekLabel(points[i].week))"), "Das Auswahl-Panel muss dieselbe weekLabel(_:)-Funktion wie die Achse nutzen.")
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

    // MARK: - Part 3 (Review-Fix): fachlich praezisere Coaching-Erklaerungen

    /// Review-Fix: die alten 4 Varianten (reine "steigt?"/"tapert?"-Kombination)
    /// behaupteten "steigt schrittweise" auch bei einem echten Mehrwochen-
    /// Plateau - irrefuehrend. 5 neue, unterscheidbare Faelle.
    func testCoachingExplanationHasFiveDataDrivenVariants() throws {
        let source = try viewSource
        for key in [
            "profile.cardio.adjustment.chart.explanation.continuousBuildUp",
            "profile.cardio.adjustment.chart.explanation.plateau",
            "profile.cardio.adjustment.chart.explanation.deloadWithinBuildUp",
            "profile.cardio.adjustment.chart.explanation.peakReached",
            "profile.cardio.adjustment.chart.explanation.taper",
        ] {
            XCTAssertTrue(source.contains(key), "Fehlender Erklaerungs-Key: \(key)")
        }
        for oldKey in [
            "profile.cardio.adjustment.chart.explanation.rampAndTaper",
            "profile.cardio.adjustment.chart.explanation.rampNoTaper",
            "profile.cardio.adjustment.chart.explanation.alreadyAtTargetWithTaper",
            "profile.cardio.adjustment.chart.explanation.steady",
        ] {
            XCTAssertFalse(source.contains(oldKey), "Alter, zu grober Erklaerungs-Key darf nicht mehr vorkommen: \(oldKey)")
        }
    }

    /// Die eigentliche Klassifikationslogik (`CoachAdjustmentChartExplanation`)
    /// ist SwiftUI-unabhaengig und bekommt echte Verhaltenstests in
    /// `CoachAdjustmentChartExplanationTests` - hier nur noch die
    /// Verdrahtung pruefen: die View muss tatsaechlich delegieren, nicht
    /// ihre eigene Kopie der Logik behalten.
    func testViewDelegatesExplanationClassificationInsteadOfDuplicatingIt() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains("CoachAdjustmentChartExplanation.classify(points: points, phases: phases)"))
    }

    // MARK: - Part 4 (Review-Fix): Auswahl bei Planaenderung zuruecksetzen

    func testSelectionResetsOnlyWhenTheProjectionInputsActuallyChange() throws {
        let source = try viewSource
        XCTAssertTrue(source.contains("ChartProjectionIdentity"), "Reset muss an eine Equatable-Identitaet der Projektions-Eingaben gekoppelt sein, nicht an jedes Re-Render.")
        XCTAssertTrue(source.contains(".onChange(of: ChartProjectionIdentity(startKm: startVol, goal: projGoal, weeksAvailable: totalWeeks))"))
        XCTAssertTrue(source.contains("selectedChartWeek = nil"))
    }

    func testChartProjectionIdentityIsEquatable() throws {
        let source = try viewSource
        guard let range = source.range(of: "private struct ChartProjectionIdentity") else {
            XCTFail("ChartProjectionIdentity nicht gefunden.")
            return
        }
        let body = source[range.lowerBound...].prefix(200)
        XCTAssertTrue(body.contains("Equatable"), "ChartProjectionIdentity muss Equatable sein, sonst kompiliert .onChange(of:) nicht.")
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
