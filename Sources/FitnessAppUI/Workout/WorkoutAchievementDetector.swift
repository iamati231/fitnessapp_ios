#if canImport(SwiftData)
import Foundation
import FitnessAppData
import FitnessAppCore

/// UX-202 — Detector für nicht-PR Achievements am Ende eines Trainings.
///
/// PRs werden in `WorkoutSummaryView.prSection` über `PRDetector` gerendert
/// und sind orthogonal zu diesen Achievements. Dieser Detector ergänzt
/// kontextuelle Erfolge ("dein 3. Workout diese Woche", "längstes Workout
/// der Woche") für den Reward-Moment, ohne dass der User mehrmals etwas
/// gleiches in mehreren Sections sieht.
///
/// Read-only (rein lesend, keine Mutation) — wird beim Erscheinen des
/// Summary-Screens evaluiert. Im History-Replay-Mode (`isReadOnly`) wird
/// der Detector NICHT aufgerufen, weil die Achievements für den "frisch
/// erreicht"-Moment gedacht sind, nicht für die rückblickende Anzeige.
@MainActor
public enum WorkoutAchievementDetector {

    public struct Achievement: Identifiable, Equatable {
        public let id: Kind
        public let kind: Kind

        public init(kind: Kind) {
            self.id = kind
            self.kind = kind
        }

        public enum Kind: Equatable, Hashable {
            /// "Dein 3. Workout diese Woche". Nur ab dem 3. wöchentlichen
            /// Workout gezeigt — bei 1-2 wäre's eher demotivierend als
            /// belohnend.
            case weeklyMilestone(count: Int)
            /// Diese Session hat das hoechste Volumen aller Strength/Mixed-
            /// Sessions dieser Kalenderwoche. Nur sinnvoll wenn min. 1
            /// andere Vergleichs-Session in der Woche existiert (sonst
            /// triviales "1 von 1").
            case heaviestOfWeek
            /// Längste Trainings-Dauer der Woche. Gleiche Vergleichs-Logik
            /// wie heaviestOfWeek.
            case longestOfWeek
            /// Distanz-Rekord der Woche (für Cardio-Sessions). Nur wenn
            /// die Session überhaupt Distanz geloggt hat UND mehr als jede
            /// andere Cardio-Session dieser Woche.
            case longestDistanceOfWeek
        }
    }

    /// Wertet alle Achievements für `session` aus. `history` ist eine
    /// bereits gefilterte Liste aller completed Sessions (inkl. dieser);
    /// rest-day-marker werden hier intern ausgefiltert.
    public static func detect(
        session: WorkoutSession,
        history: [WorkoutSession],
        now: Date = .now
    ) -> [Achievement] {
        let realCompleted = history.filter { $0.isCompleted && !$0.isRestDay }
        guard !realCompleted.isEmpty else { return [] }

        // Aktuelle Kalenderwoche bestimmen. Calendar.current respektiert
        // das Locale (Mo-So vs So-Sa), damit der User die "Woche" so sieht
        // wie sein iPhone-Kalender.
        var cal = Calendar.current
        cal.firstWeekday = cal.firstWeekday
        guard let week = cal.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }
        let weekSessions = realCompleted.filter { week.contains($0.startTime) }
        guard !weekSessions.isEmpty else { return [] }

        var results: [Achievement] = []

        // ─── Weekly Milestone (≥3 in Woche) ─────────────────────────────
        if weekSessions.count >= 3 {
            results.append(.init(kind: .weeklyMilestone(count: weekSessions.count)))
        }

        // Helper: zähle nur "andere" Sessions als die aktuelle. Wenn die
        // aktuelle Session nicht in der Woche ist (Edge-Case: Mitternacht-
        // Übergang während des Trainings), wird sie ohnehin ignoriert.
        let thisID = session.persistentModelID
        let othersInWeek = weekSessions.filter { $0.persistentModelID != thisID }
        let thisInWeek = weekSessions.contains { $0.persistentModelID == thisID }
        guard thisInWeek, !othersInWeek.isEmpty else { return results }

        // ─── Heaviest of Week (Volumen) ─────────────────────────────────
        // Nur für Strength/Mixed-Sessions sinnvoll — reine Cardio-Sessions
        // tragen `totalVolumeKg == 0`, das gegen andere Cardio-Sessions zu
        // vergleichen produziert ein false-positive "0 ist mehr als 0".
        if session.totalVolumeKg > 0 {
            let maxOtherVolume = othersInWeek.map(\.totalVolumeKg).max() ?? 0
            if session.totalVolumeKg > maxOtherVolume {
                results.append(.init(kind: .heaviestOfWeek))
            }
        }

        // ─── Longest of Week (Dauer) ────────────────────────────────────
        if session.durationMinutes > 0 {
            let maxOtherDuration = othersInWeek.map(\.durationMinutes).max() ?? 0
            if session.durationMinutes > maxOtherDuration {
                results.append(.init(kind: .longestOfWeek))
            }
        }

        // ─── Distance Record (Cardio) ───────────────────────────────────
        let thisDistance = session.logs.compactMap(\.distanceKm).reduce(0.0, +)
        if thisDistance > 0 {
            let maxOtherDistance = othersInWeek.map { other in
                other.logs.compactMap(\.distanceKm).reduce(0.0, +)
            }.max() ?? 0
            if thisDistance > maxOtherDistance {
                results.append(.init(kind: .longestDistanceOfWeek))
            }
        }

        return results
    }
}
#endif
