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

    /// Anzahl konsekutiver Kalenderwochen, die das Wochenziel erfüllen,
    /// rückwärts ab `now`. Laufende Woche unter dem Ziel zählt nicht mit,
    /// bricht aber auch nicht (Grace) — erst eine VOLL verstrichene Woche
    /// unter dem Ziel endet den Streak.
    ///
    /// DEL-203: `goalPerWeek` macht den Streak ehrlich — wer sich 3×/Woche
    /// vorgenommen hat, hält den Streak nur mit 3 Workouts. Default 1 =
    /// das alte "mindestens ein Workout"-Verhalten.
    public static func weekStreak(
        workoutDates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current,
        goalPerWeek: Int = 1
    ) -> Int {
        guard !workoutDates.isEmpty else { return 0 }
        let goal = max(1, goalPerWeek)

        // Workouts pro Kalenderwoche zählen — Mehrfach-Sessions am selben
        // TAG zählen einzeln (zwei Einheiten an einem Tag sind zwei
        // Workouts Richtung Ziel).
        var countsByWeek: [Date: Int] = [:]
        for date in workoutDates {
            guard let week = weekStart(of: date, calendar: calendar) else { continue }
            countsByWeek[week, default: 0] += 1
        }

        guard var cursor = weekStart(of: now, calendar: calendar) else { return 0 }

        // Grace: aktuelle Woche noch unter dem Ziel → eine Woche zurück-
        // springen und dort mit dem Zählen beginnen.
        if countsByWeek[cursor, default: 0] < goal {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }

        var streak = 0
        while countsByWeek[cursor, default: 0] >= goal {
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
