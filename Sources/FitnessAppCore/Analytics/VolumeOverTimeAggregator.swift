// DEL-178: Volume-Over-Time-Aggregator — pure-function bucketing von
// Strength-Logs in Kalenderwochen. Wird vom Dashboard-Chart genutzt; lebt
// in Core, weil reines Number-Crunching und ohne SwiftData-Abhängigkeit.
//
// Bewusste Designentscheidungen:
//   - Cardio-/Time-based Logs werden ausgeklammert (kein Volume-Begriff).
//   - Eine Woche wird durch `Calendar.dateInterval(of: .weekOfYear, ...)`
//     definiert — respektiert das User-Locale (Mo-Start in DE, So-Start
//     in US). Caller muss `Calendar.current` reichen.
//   - Wochen ohne Strength-Aktivität bekommen einen Eintrag mit
//     `volumeKg == 0`. Das macht das Chart-Rendering ehrlicher (Lücken
//     sind sichtbar als 0er-Bars statt Phantom-Verbindungs-Linien) und
//     lässt sich auf der View-Seite trivial herausfiltern, falls man
//     "nur trainierte Wochen" zeigen will.

import Foundation

/// Ein Datenpunkt: eine Kalenderwoche + das Strength-Volumen darin.
public struct VolumeWeekPoint: Identifiable, Equatable, Sendable {
    public let weekStart: Date        // Mo (DE) bzw. So (US) 00:00 lokal
    public let volumeKg: Double

    public var id: Date { weekStart }

    public init(weekStart: Date, volumeKg: Double) {
        self.weekStart = weekStart
        self.volumeKg = volumeKg
    }
}

public enum VolumeOverTimeAggregator {

    /// Aggregiert die Logs in Wochen-Bukets innerhalb von `windowStart...now`.
    /// Liefert ein lückenloses Array — jede Woche im Fenster bekommt einen
    /// Eintrag, auch wenn `volumeKg == 0`.
    ///
    /// - Parameter logs: pro Log ein Tuple. `isCardio`/`isTimeBased` true →
    ///   wird übersprungen (kein Volume-Begriff).
    /// - Parameter windowStart: linke Kante des Charts. Der Aggregator
    ///   springt vom `windowStart`-Wochenbeginn aus weiter, sodass die
    ///   Buckets sauber an Kalenderwochen ausgerichtet sind.
    /// - Parameter now: rechte Kante (default `Date()`).
    /// - Parameter calendar: Locale-Sensible Wochengrenze.
    public static func aggregate(
        logs: [(date: Date, weightKg: Double, reps: Int, isCardio: Bool, isTimeBased: Bool)],
        windowStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [VolumeWeekPoint] {
        // 1) Strength-Volume pro Log (weight × reps), gruppiert nach Wochenbeginn.
        var bucketTotals: [Date: Double] = [:]
        for log in logs {
            guard !log.isCardio, !log.isTimeBased else { continue }
            guard log.date >= windowStart, log.date <= now else { continue }
            let weekStart = weekStartFor(log.date, calendar: calendar)
            let setVolume = log.weightKg * Double(log.reps)
            bucketTotals[weekStart, default: 0] += setVolume
        }

        // 2) Lückenloses Array über den gesamten Bereich. Das macht die
        //    BarMark-Darstellung ehrlich — Wochen ohne Training erscheinen
        //    als 0-Bars und sind sofort als Pausen erkennbar.
        var result: [VolumeWeekPoint] = []
        var cursor = weekStartFor(windowStart, calendar: calendar)
        let upper = weekStartFor(now, calendar: calendar)
        while cursor <= upper {
            let volume = bucketTotals[cursor] ?? 0
            result.append(VolumeWeekPoint(weekStart: cursor, volumeKg: volume))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Wochenbeginn fuer einen beliebigen Tag — `Calendar.dateInterval(of:
    /// .weekOfYear)` ist das robusteste Mittel; Locale-Sensitivity ist eingebaut.
    private static func weekStartFor(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
