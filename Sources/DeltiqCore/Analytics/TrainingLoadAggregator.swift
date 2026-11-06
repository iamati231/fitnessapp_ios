import Foundation

/// AI-Running-Coach Phase 2, Work Package 2A: Wochen-Bucketing der
/// vereinheitlichten Trainingshistorie. Reine Funktion, keine SwiftData-
/// Abhaengigkeit - die SwiftData-Glue lebt in
/// `DeltiqData/TrainingActivityExtractor.swift`.
///
/// **Keine zweite Wochenaggregation** (Ticket Teil 5, Anforderung 1): die
/// Lauf-/Cross-Training-/Unbekannt-Zahlen entstehen durch einen
/// unveraenderten Aufruf von `CardioVolumeOverTimeAggregator.aggregate` -
/// nur das fehlende Kraft-Bucketing (das es dort nicht gibt) kommt hier
/// neu dazu, mit identischer Luecken-Fuell-Strategie.
public enum TrainingLoadAggregator {

    /// Aggregiert die Aktivitaeten in Wochen-Buckets innerhalb von
    /// `windowStart...now`. Luecken-los wie `CardioVolumeOverTimeAggregator.
    /// aggregate` - jede Woche im Fenster bekommt einen Eintrag.
    public static func aggregate(
        activities: [TrainingActivity],
        windowStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TrainingLoadWeek] {
        let cardioWeeks = CardioVolumeOverTimeAggregator.aggregate(
            sessions: activities.map(\.asCardioLoggedSession),
            windowStart: windowStart, now: now, calendar: calendar
        )

        struct StrengthBucket {
            var setCount = 0
            var volumeKg = 0.0
        }
        var strengthBuckets: [Date: StrengthBucket] = [:]
        for activity in activities {
            guard activity.date >= windowStart, activity.date <= now else { continue }
            let weekStart = weekStartFor(activity.date, calendar: calendar)
            var bucket = strengthBuckets[weekStart] ?? StrengthBucket()
            bucket.setCount += activity.strengthSetCount
            bucket.volumeKg += activity.strengthVolumeKg
            strengthBuckets[weekStart] = bucket
        }

        // `cardioWeeks` ist bereits luecken-los ueber das gesamte Fenster -
        // darueber mappen erhaelt diese Eigenschaft automatisch fuer das
        // Gesamtergebnis, ohne die Luecken-Fuell-Logik ein zweites Mal zu
        // schreiben.
        return cardioWeeks.map { point in
            let bucket = strengthBuckets[point.weekStart] ?? StrengthBucket()
            return TrainingLoadWeek(
                weekStart: point.weekStart,
                running: point,
                strengthSessionCount: point.strengthSessionCount,
                strengthSetCount: bucket.setCount,
                strengthVolumeKg: bucket.volumeKg
            )
        }
    }

    /// Dupliziertes Ein-Zeiler-Pendant zu `CardioVolumeOverTimeAggregator.
    /// weekStartFor`/`VolumeOverTimeAggregator.weekStartFor` (beide
    /// `private`, Phase-1-Code bleibt unveraendert) - keine Fachlogik,
    /// reine Kalenderarithmetik.
    private static func weekStartFor(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
