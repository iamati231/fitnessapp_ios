// DEL-197: Trainings-Kalender + Wochen-Streak.
//
// Pure-Aggregator für das Dashboard-Kalender-Widget: nimmt die Start-
// Daten realer Workouts und liefert
//   1. ein Set normalisierter Trainings-Tage (startOfDay) für die
//      Dot-Markierung im Monatsraster und
//   2. den Wochen-Streak — wie viele KONSEKUTIVE Kalenderwochen
//      (rückwärts ab heute) mindestens ein Workout enthalten.
//
// **Warum Wochen statt Tage:** Niemand trainiert 365 Tage am Stück; ein
// Tages-Streak wäre für Kraftsport demotivierend (jeder Ruhetag bricht
// ihn). Die Kalenderwoche ist die ehrliche Einheit — sie matcht auch das
// Wochen-Volumen-Denken im Rest der App (Heatmap, Volume-Chart).
//
// **Grace für die laufende Woche:** Wenn die aktuelle Woche noch kein
// Workout hat (es ist z.B. Montag), bricht das den Streak NICHT — er
// zählt dann ab der Vorwoche. Erst eine komplett verstrichene Woche
// ohne Training reißt die Kette.

import Foundation

public enum TrainingCalendarAggregator {

    /// Normalisiert Workout-Zeitstempel auf Tagesanfang — das Set, gegen
    /// das die Kalender-Zellen ihren Dot-Status prüfen.
    public static func workoutDays(
        of dates: [Date],
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    /// Anzahl konsekutiver Kalenderwochen mit >= 1 Workout, rückwärts ab
    /// `now`. Laufende Woche ohne Workout zählt nicht mit, bricht aber
    /// auch nicht (Grace) — erst eine VOLL verstrichene leere Woche endet
    /// den Streak.
    public static func weekStreak(
        workoutDates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard !workoutDates.isEmpty else { return 0 }
        let weekStarts = Set(workoutDates.compactMap { weekStart(of: $0, calendar: calendar) })
        guard var cursor = weekStart(of: now, calendar: calendar) else { return 0 }

        // Grace: aktuelle Woche noch leer → eine Woche zurückspringen und
        // dort mit dem Zählen beginnen.
        if !weekStarts.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }

        var streak = 0
        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Locale-sensitiver Wochenbeginn (Mo in DE, So in US).
    private static func weekStart(of date: Date, calendar: Calendar) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
    }
}
