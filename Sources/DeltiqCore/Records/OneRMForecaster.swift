// DEL-179: e1RM-Forecast für Compound-Lifts.
//
// Analog zu BodyCalculations.projectWeightTrend, aber für die geschätzten
// 1RM-Werte einzelner Compound-Lifts. Lineare Regression über die letzten
// N Datenpunkte, Projektion auf X Wochen voraus, mit defensiver
// Reliability-Prüfung.
//
// **Designentscheidungen:**
//   - Nutzt nur die letzten 6 Sessions (analog Weight-Forecast) — ältere
//     Daten ziehen die Trendlinie zu sehr in Richtung "wo der User vor
//     einem halben Jahr war". Aktuelle Progression ist die ehrliche
//     Aussage.
//   - Bei <3 Sessions kein Forecast (Stichprobe zu klein).
//   - Bei Standardabweichung > 15% des Mittelwerts: unzuverlässig
//     (typisch bei De-Loads oder kaputten Logs).
//   - Slope-Clamp: ein Sprung von >20 kg pro Woche im Forecast wird auf
//     ±20 limitiert. Sonst projiziert eine kurze Hochlauf-Phase
//     wahnsinnige Werte in die Zukunft.
//   - Sanity-Bound: Forecast außerhalb von 20 – 500 kg wird verworfen
//     (das Forecast-Modell ist linear und kann bei stark steigenden
//     Anfängern utopische Werte ausspucken — ein Hard-Cap hält die UI
//     ehrlich).

import Foundation

/// Ein Trainings-Datenpunkt einer Übung: das beste geschätzte 1RM einer
/// Session zu einem Datum. Mirrors `CompoundPoint` auf UI-Seite, ist aber
/// hier in Core ohne Identifiable-Conformance (das brauchen Charts, nicht
/// der Aggregator).
public struct OneRMSample: Equatable, Sendable {
    public let date: Date
    public let oneRM: Double

    public init(date: Date, oneRM: Double) {
        self.date = date
        self.oneRM = oneRM
    }
}

public enum OneRMForecaster {

    /// Wieviele Wochen pro Sekunde — vorsichtig statt 1.0/(7*86_400) für
    /// die Compile-Time-Konstante.
    private static let secondsPerWeek: Double = 7 * 24 * 3600

    /// Anzahl letzter Sessions, die in die Regression eingehen. Spiegelt
    /// die Weight-Forecast-Konvention.
    private static let recentSamplesWindow = 6

    /// Maximale plausible Wachstumsrate (kg/Woche). Bei Beginnern können
    /// "Newbie-Gains" 5-8 kg pro Woche real sein, aber lineare Extra-
    /// polation bricht da schnell — wir clampen ab 20 kg/Woche.
    private static let slopeClampKgPerWeek: Double = 20.0

    /// Plausibler 1RM-Bereich für die finale Sanity-Prüfung.
    private static let sanityRange: ClosedRange<Double> = 20.0...500.0

    /// Reliability-Schwelle: relative Standardabweichung (SD / Mean) der
    /// Datenpunkte. Über 15% gilt der Trend als zu wackelig.
    private static let unreliabilityRSD: Double = 0.15

    /// Projiziert den e1RM `weeksAhead` Wochen voraus. Liefert nil, wenn:
    ///   - weniger als 3 Datenpunkte
    ///   - Datenpunkte alle innerhalb derselben Woche (kein Trend möglich)
    ///   - Trend zu unzuverlässig (RSD > 15%)
    ///   - projizierter Wert außerhalb der Sanity-Range
    public static func projectOneRM(
        samples: [OneRMSample],
        weeksAhead: Int
    ) -> Double? {
        let sorted = samples.sorted { $0.date < $1.date }
        let points = Array(sorted.suffix(recentSamplesWindow))
        guard points.count >= 3 else { return nil }
        guard !isUnreliable(points: points) else { return nil }

        let firstDate = points.first!.date
        let lastDate = points.last!.date
        let spanWeeks = lastDate.timeIntervalSince(firstDate) / secondsPerWeek
        // Mindestens 1 Tag Abstand — sonst ist die Slope-Berechnung
        // numerisch instabil.
        guard spanWeeks >= 1.0 / 7.0 else { return nil }

        let xValues = points.map { $0.date.timeIntervalSince(firstDate) / secondsPerWeek }
        let yValues = points.map { $0.oneRM }
        let xMean = xValues.reduce(0, +) / Double(xValues.count)
        let yMean = yValues.reduce(0, +) / Double(yValues.count)

        let ssXX = xValues.reduce(0.0) { acc, x in acc + (x - xMean) * (x - xMean) }
        guard ssXX >= 1e-9 else { return nil }

        let rawSlope = zip(xValues, yValues).reduce(0.0) { acc, pair in
            acc + (pair.0 - xMean) * (pair.1 - yMean)
        } / ssXX

        // Slope-Clamp: extreme Newbie-Gains-Phase projiziert sonst absurde
        // Werte 8 Wochen voraus. ±20 kg/Woche ist die obere Plausibilität.
        let slope = max(-slopeClampKgPerWeek, min(slopeClampKgPerWeek, rawSlope))

        let projectedX = xValues.last! + Double(weeksAhead)
        let projected = yMean + slope * (projectedX - xMean)

        return sanityRange.contains(projected) ? projected : nil
    }

    /// Erzeugt einen forecasted Datenpunkt (Datum + e1RM) für die View —
    /// hilfreich, weil das UI eine LineMark zum letzten echten Punkt
    /// braucht. `nil` wenn kein Forecast möglich (siehe `projectOneRM`).
    public static func forecastPoint(
        samples: [OneRMSample],
        weeksAhead: Int,
        now: Date = Date()
    ) -> OneRMSample? {
        guard let value = projectOneRM(samples: samples, weeksAhead: weeksAhead) else {
            return nil
        }
        let targetDate = now.addingTimeInterval(Double(weeksAhead) * secondsPerWeek)
        return OneRMSample(date: targetDate, oneRM: value)
    }

    // DEL-242: Die public `isUnreliable(samples:)`-Ueberladung ist entfernt —
    // repo-weit ohne Aufrufer. Der interne Aufruf weiter oben lautet
    // `isUnreliable(points:)` und traf immer die private Fassung unten; die
    // Argument-Labels trennen die beiden Overloads sauber, es gab also keine
    // versteckte Nutzung. `projectOneRM` prueft die Verlaesslichkeit selbst,
    // die UI blendet den Forecast damit ohnehin schon aus.

    private static func isUnreliable(points: [OneRMSample]) -> Bool {
        guard points.count >= 3 else { return false }
        let ys = points.map { $0.oneRM }
        let mean = ys.reduce(0, +) / Double(ys.count)
        guard mean > 0 else { return true }
        let variance = ys.reduce(0.0) { acc, y in acc + (y - mean) * (y - mean) } / Double(ys.count)
        let sd = sqrt(variance)
        return sd / mean > unreliabilityRSD
    }
}
