import XCTest
@testable import FitnessAppCore

/// Phase F – Unit-Tests fuer `CardioBaselineCalculator.medianFiveKmSeconds`.
/// Deckt alle vom Spec geforderten Faelle ab: leere/unzureichende Datenmenge,
/// Median-Berechnung (gerade/ungerade), Distanz- und Dauer-Filter,
/// Plausibilitaets-Filter, Ausreisser-Robustheit und Reproduzierbarkeit.
final class FiveKmMedianBaselineTests: XCTestCase {

    // MARK: - Hilfsfunktionen

    private func run(_ distanceKm: Double, _ durationSeconds: Int) -> CardioBaselineCalculator.RunSample {
        CardioBaselineCalculator.RunSample(distanceKm: distanceKm, durationSeconds: durationSeconds)
    }

    /// Erzeugt einen exakt 5,0-km-Lauf mit der angegebenen Pace (min/km).
    /// Dauer = pace * 5 * 60 Sekunden.
    private func validRun(paceMinPerKm: Double) -> CardioBaselineCalculator.RunSample {
        let duration = Int((paceMinPerKm * 5.0 * 60.0).rounded())
        return run(5.0, duration)
    }

    // MARK: - Keine / unzureichende Datenmenge

    func testNoRunsYieldsNil() {
        XCTAssertNil(CardioBaselineCalculator.medianFiveKmSeconds(from: []))
    }

    func testOneValidRunYieldsNil() {
        // Eine einzige Messung ist keine belastbare Baseline.
        XCTAssertNil(CardioBaselineCalculator.medianFiveKmSeconds(from: [validRun(paceMinPerKm: 5.0)]))
    }

    func testTwoValidRunsYieldNil() {
        // Zwei Messungen liegen noch unter minimumFiveKmSamples (3).
        let runs = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5)]
        XCTAssertNil(CardioBaselineCalculator.medianFiveKmSeconds(from: runs))
    }

    func testExactlyMinimumSamplesYieldsBaseline() {
        // Genau 3 gueltige Laeufe (Mindestanzahl): Baseline muss berechnet werden.
        // Paces [5.0, 5.5, 6.0] → Median = 5.5 min/km → 1650 s
        let runs = [
            validRun(paceMinPerKm: 5.0),
            validRun(paceMinPerKm: 5.5),
            validRun(paceMinPerKm: 6.0),
        ]
        XCTAssertEqual(CardioBaselineCalculator.medianFiveKmSeconds(from: runs), 1650)
    }

    // MARK: - Median-Berechnung

    func testOddCountMedianIsMiddleValue() {
        // 5 Laeufe: Median = mittleres Element der sortierten Pace-Liste.
        // Paces [5.0, 5.5, 6.0, 6.5, 7.0] → Median = 6.0 min/km → 1800 s
        let runs = [
            validRun(paceMinPerKm: 5.0),
            validRun(paceMinPerKm: 5.5),
            validRun(paceMinPerKm: 6.0),
            validRun(paceMinPerKm: 6.5),
            validRun(paceMinPerKm: 7.0),
        ]
        XCTAssertEqual(CardioBaselineCalculator.medianFiveKmSeconds(from: runs), 1800)
    }

    func testEvenCountMedianIsAverageOfTwoMiddleValues() {
        // 4 Laeufe: Median = Mittelwert der zwei mittleren Werte.
        // Paces [5.0, 5.5, 6.0, 6.5] → Median = (5.5 + 6.0) / 2 = 5.75 min/km → 1725 s
        let runs = [
            validRun(paceMinPerKm: 5.0),
            validRun(paceMinPerKm: 5.5),
            validRun(paceMinPerKm: 6.0),
            validRun(paceMinPerKm: 6.5),
        ]
        XCTAssertEqual(CardioBaselineCalculator.medianFiveKmSeconds(from: runs), 1725)
    }

    // MARK: - Distanz-Toleranz-Filter

    func testRunBelowDistanceLowerBoundExcluded() {
        // 4,4 km — zu kurz, kein 5-km-Lauf. Nur die 3 gueltigen zaehlen.
        let short = run(4.4, 1300)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [short]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    func testRunAboveDistanceUpperBoundExcluded() {
        // 5,6 km — zu lang. Nur die 3 gueltigen zaehlen.
        let long = run(5.6, 1900)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [long]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    func testExactBoundaryDistancesAreIncluded() {
        // 4,5 km und 5,5 km liegen exakt auf der Grenze (>=, <=) und zaehlen mit.
        // Beide Laeufe: Pace ~5.0 min/km → 5-km-Aequivalent 1500 s (plausibel).
        let low  = run(4.5, 1350) // 4.5 km in 22:30 → 5.0 min/km
        let high = run(5.5, 1650) // 5.5 km in 27:30 → 5.0 min/km
        let third = validRun(paceMinPerKm: 5.0)
        XCTAssertNotNil(
            CardioBaselineCalculator.medianFiveKmSeconds(from: [low, high, third]),
            "Laeufe genau auf den Distanzgrenzen muessen als gueltig zaehlen"
        )
    }

    // MARK: - Dauer-Filter

    func testRunBelowMinimumDurationExcluded() {
        // 299 s — fehlgestartete Uhr / Dateneingabefehler.
        let tooShort = run(5.0, 299)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [tooShort]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    func testZeroDurationExcluded() {
        // Defensiv: falls eine unvollstaendige Session mit 0-Dauer ankommt.
        let zero = run(5.0, 0)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [zero]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    // MARK: - Plausibilitaets-Filter (implausible Zeiten)

    func testImplausiblyFastRunExcluded() {
        // 4,5 km in 300 s = 1,11 min/km → 5-km-Aequivalent ~333 s < 600 s → Ausschluss.
        let implausiblyFast = run(4.5, 300)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [implausiblyFast]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    func testImplausiblySlowRunExcluded() {
        // 5,0 km in 5941 s ≈ 19,8 min/km → 5-km-Aequivalent 5941 s > 5400 s → Ausschluss.
        let implausiblyLow = run(5.0, 5941)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [implausiblyLow]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    // MARK: - Andere Cardio-Aktivitaeten / unvollstaendige Sessions

    func testNonFiveKmActivityExcludedByDistanceFilter() {
        // Andere Cardio-Arten (Radfahren, Schwimmen) landen typisch ausserhalb
        // der 4,5–5,5-km-Toleranz und werden dadurch ausgeschlossen.
        // Die Lauf-Art-Filterung ist Aufgabe des Aufrufers (resolvedIsCardio).
        let cycling = run(20.0, 3600) // 20 km Radfahrt
        let swimming = run(1.0, 1800) // 1 km Schwimmen
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [cycling, swimming]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    func testIncompleteSessionWithZeroDurationExcluded() {
        // Unvollstaendige Sessions (isRealWorkout == false) filtert der Aufrufer.
        // Defensiv: falls eine 0-Dauer-Session durchkommt, wird sie hier ausgeschlossen.
        let incomplete = run(5.0, 0)
        let valid = [validRun(paceMinPerKm: 5.0), validRun(paceMinPerKm: 5.5), validRun(paceMinPerKm: 6.0)]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid + [incomplete]),
            CardioBaselineCalculator.medianFiveKmSeconds(from: valid)
        )
    }

    // MARK: - Ausreisser-Robustheit (Median vs. Mittelwert)

    func testFastOutlierHasMinimalEffectOnMedian() {
        // Paces sortiert: [3.0, 5.5, 6.0, 6.5, 7.0] → Median = 6.0 min/km → 1800 s.
        // Ein einfacher Mittelwert waere auf (3.0+5.5+6.0+6.5+7.0)/5 = 5.6 min/km gefallen.
        let outlier = validRun(paceMinPerKm: 3.0) // 900 s, in Plausibilitaetsrange [600, 5400]
        let normal = [
            validRun(paceMinPerKm: 5.5),
            validRun(paceMinPerKm: 6.0),
            validRun(paceMinPerKm: 6.5),
            validRun(paceMinPerKm: 7.0),
        ]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: normal + [outlier]),
            1800,
            "Median bei 6.0 min/km (1800 s) — sehr schneller Ausreisser verschiebt ihn nicht"
        )
    }

    func testSlowOutlierHasMinimalEffectOnMedian() {
        // Paces sortiert: [5.5, 6.0, 6.5, 7.0, 17.0] → Median = 6.5 min/km → 1950 s.
        // Sehr langsamer Lauf (5 km in 85 min = 17 min/km, noch in Plausibilitaetsrange).
        let outlier = run(5.0, 5100) // 17.0 min/km → 5 km = 5100 s, in [600, 5400]
        let normal = [
            validRun(paceMinPerKm: 5.5),
            validRun(paceMinPerKm: 6.0),
            validRun(paceMinPerKm: 6.5),
            validRun(paceMinPerKm: 7.0),
        ]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: normal + [outlier]),
            1950,
            "Median bei 6.5 min/km (1950 s) — sehr langsamer Ausreisser verschiebt ihn moderat"
        )
    }

    // MARK: - Reproduzierbarkeit

    func testReproducibleWithIdenticalInput() {
        // Pure function: gleiche Eingabe → stets gleiches Ergebnis.
        let runs = [
            validRun(paceMinPerKm: 5.0),
            validRun(paceMinPerKm: 5.5),
            validRun(paceMinPerKm: 6.0),
        ]
        XCTAssertEqual(
            CardioBaselineCalculator.medianFiveKmSeconds(from: runs),
            CardioBaselineCalculator.medianFiveKmSeconds(from: runs)
        )
    }

    // MARK: - Zeitfenster- und Schwellwert-Konstanten

    func testFiveKmMedianWindowDaysDefined() {
        // Der Aufrufer filtert nach diesem Wert vor dem Aufruf (s. weeklyVolumeKm).
        XCTAssertEqual(CardioBaselineCalculator.fiveKmMedianWindowDays, 90)
    }

    func testMinimumFiveKmSamplesDefined() {
        XCTAssertEqual(CardioBaselineCalculator.minimumFiveKmSamples, 3)
    }

    func testDistanceRangeConstantsDefined() {
        XCTAssertEqual(CardioBaselineCalculator.fiveKmDistanceRangeLow, 4.5, accuracy: 0.001)
        XCTAssertEqual(CardioBaselineCalculator.fiveKmDistanceRangeHigh, 5.5, accuracy: 0.001)
    }
}
