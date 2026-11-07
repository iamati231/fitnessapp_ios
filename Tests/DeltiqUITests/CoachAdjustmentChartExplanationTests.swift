#if canImport(SwiftUI)
import XCTest
import DeltiqCore
@testable import DeltiqUI

/// Review-Fix ("Lauftrainingsdiagramm - Wochenzuordnung, UI-Tests und
/// Coaching-Erklaerungen korrigieren", 2026-11-06), Teil 3/6: echte
/// Verhaltenstests fuer `CoachAdjustmentChartExplanation.classify` - anders
/// als `CoachAdjustmentChartTests` (Source-Introspektion) ruft dies die
/// tatsaechliche Logik auf und prueft ihr Ergebnis. `CoachAdjustmentChartExplanation`
/// selbst hat keine SwiftUI-Abhaengigkeit, liegt aber in einer Datei, deren
/// Modul (`DeltiqUI`) auf diesem Windows-Host hinter `#if canImport(SwiftUI)`
/// leer kompiliert - lokal also ebenfalls nicht ausfuehrbar, dafuer aber eine
/// echte, auf CI (macOS) ausgefuehrte Verhaltens-Pruefung statt reinem
/// Quelltext-Grep.
final class CoachAdjustmentChartExplanationTests: XCTestCase {

    private typealias Phase = CardioFeasibilityCalculator.ChartPhase

    // MARK: 1. Kontinuierlicher Aufbau

    func testContinuousBuildUpWhenVolumeRisesAcrossMultipleWeeksWithNoPlateauOrTaper() {
        let points: [(week: Int, km: Double)] = [(0, 10), (1, 13), (2, 16), (3, 19)]
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        XCTAssertEqual(CoachAdjustmentChartExplanation.classify(points: points, phases: phases), .continuousBuildUp)
    }

    // MARK: 2. Aufbau mit Plateau

    func testPlateauWhenSeveralWeeksStayAtTheSameMaximumAfterARealClimb() {
        let points: [(week: Int, km: Double)] = [(0, 15), (1, 20), (2, 20), (3, 20)]
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        XCTAssertEqual(CoachAdjustmentChartExplanation.classify(points: points, phases: phases), .plateau)
    }

    // MARK: 3. Vorhandene Entlastungsphase im Aufbau

    /// Mit der heutigen, monoton steigenden Rampe kann dieser Fall in der
    /// echten App nie vorkommen - diese Daten sind bewusst synthetisch, um
    /// die Erkennung selbst zu pruefen (sie muss funktionieren, FALLS die
    /// Projektionslogik jemals Entlastungswochen bekommt, ohne dass diese
    /// View dafuer angepasst werden muesste).
    func testDeloadWithinBuildUpWhenVolumeDipsBeforeReachingThePeak() {
        let points: [(week: Int, km: Double)] = [(0, 10), (1, 15), (2, 12), (3, 20)]
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        XCTAssertEqual(CoachAdjustmentChartExplanation.classify(points: points, phases: phases), .deloadWithinBuildUp)
    }

    // MARK: 4. Belastungsspitze (ohne nennenswerten Aufbau, ohne Taper)

    func testPeakReachedWhenThereIsNoMeaningfulRampAndNoTaper() {
        let points: [(week: Int, km: Double)] = [(0, 20), (1, 20)]
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        XCTAssertEqual(CoachAdjustmentChartExplanation.classify(points: points, phases: phases), .peakReached)
    }

    // MARK: 5. Tapering

    func testTaperWhenTheFinalWeeksAreReducedBeforeRaceDay() {
        let points = CardioFeasibilityCalculator.weeklyVolumeProjection(startKm: 10, goal: .marathon, weeksAvailable: 10)
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        XCTAssertEqual(CoachAdjustmentChartExplanation.classify(points: points, phases: phases), .taper)
    }

    // MARK: 6. Kurzer Trainingsplan ohne Tapering

    /// 1 Woche <= `taperWeeks` (2): `weeklyVolumeProjection` wendet bewusst
    /// keinen Taper an (siehe `CardioFeasibilityCalculatorTests.
    /// testProjectionNoTaperForOneWeek`). Die Erklaerung darf deshalb NICHT
    /// "Tapering" behaupten.
    func testShortPlanWithoutTaperDoesNotClaimTapering() {
        let points = CardioFeasibilityCalculator.weeklyVolumeProjection(startKm: 20, goal: .marathon, weeksAvailable: 1)
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        let result = CoachAdjustmentChartExplanation.classify(points: points, phases: phases)
        XCTAssertNotEqual(result, .taper, "Ohne tatsaechlichen Taper darf kein Tapering behauptet werden.")
        XCTAssertEqual(result, .peakReached)
    }

    // MARK: Prioritaet

    /// Ein Plan kann gleichzeitig ein Plateau UND einen Taper zeigen - die
    /// unmittelbar wettkampf-relevante Taper-Aussage hat Vorrang vor der
    /// Beschreibung des vorangegangenen Aufbaus.
    func testTaperTakesPriorityOverAPlateauThatPrecedesIt() {
        let points: [(week: Int, km: Double)] = [(0, 10), (1, 20), (2, 20), (3, 14)]
        let phases = CardioFeasibilityCalculator.chartPhases(for: points)
        XCTAssertEqual(CoachAdjustmentChartExplanation.classify(points: points, phases: phases), .taper)
    }

    // MARK: localizationKey

    func testEveryCaseHasALocalizationKey() {
        for explanation: CoachAdjustmentChartExplanation in [.deloadWithinBuildUp, .taper, .plateau, .continuousBuildUp, .peakReached] {
            _ = explanation.localizationKey
        }
    }
}
#endif
