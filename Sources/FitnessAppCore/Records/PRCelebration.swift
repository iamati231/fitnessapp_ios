import Foundation

/// Builds celebration strings (notification title/body, live-activity headline)
/// from a list of detected PRs. Pure value-type helper — usable from any layer
/// (notifications, widgets, watch) without dragging UI dependencies in.
///
/// **Headline priority** matches `PRDetector.kindOrder`:
/// `estimated1RM > heaviestWeight > bestSet > maxReps > maxHoldSeconds`
/// — the most impressive PR leads, the rest collapse into a "+ N weitere" tail.
public enum PRCelebration {

    /// Returns nil when `records` is empty. Otherwise picks the highest-priority
    /// PR as the headline; remaining PRs are summarized as a count if any.
    ///
    /// README 2.16 Nachtrag (28c): Emoji sind eine Eigenschaft der Tonlage,
    /// nicht der Oberflaeche — die `coaching.*.motivating`-Katalogtexte
    /// tragen sie schon nur in dieser einen Tonlage, hier zieht dieselbe
    /// Regel ein. `tone` hat einen Default, damit bestehende Aufrufer
    /// (Tests) unveraendert bleiben; Produktionsaufrufer geben die
    /// tatsaechliche `UserBodyProfile.coachingTone` mit.
    public static func make(from records: [PersonalRecord], tone: CoachingTone = .motivating) -> Celebration? {
        guard !records.isEmpty else { return nil }

        // Sort by display priority; ties resolved by exerciseName for stability.
        let sorted = records.sorted { lhs, rhs in
            let lp = priority(lhs.kind)
            let rp = priority(rhs.kind)
            if lp != rp { return lp < rp }
            return lhs.exerciseName < rhs.exerciseName
        }

        let headline = sorted[0]
        let remaining = sorted.count - 1

        let title = title(for: headline, tone: tone)
        var body = detail(for: headline)
        if remaining > 0 {
            body += "  •  +\(remaining) weitere\(remaining == 1 ? "r" : "") Rekord\(remaining == 1 ? "" : "e")"
        }

        // Compact one-liner for the Live Activity (limited horizontal space).
        let trophyPrefix = tone == .motivating ? "🏆 " : ""
        let activityLine: String = {
            let exercise = shortenExercise(headline.exerciseName)
            switch headline.kind {
            case .maxReps:
                return "\(trophyPrefix)\(headline.reps) Wdh \(exercise)"
            case .maxHoldSeconds:
                return "\(trophyPrefix)\(headline.reps)s \(exercise)"
            case .estimated1RM, .heaviestWeight:
                return "\(trophyPrefix)\(formatNumber(headline.newValue)) kg \(exercise)"
            case .bestSet:
                return "\(trophyPrefix)\(formatNumber(headline.weightKg))×\(headline.reps) \(exercise)"
            // DEL-064 Cardio
            case .longestDistance:
                return "\(trophyPrefix)\(formatNumber(headline.newValue)) km \(exercise)"
            case .fastestPace:
                return "\(trophyPrefix)\(formatPace(headline.newValue)) \(exercise)"
            // Zeitformate (README 2.9)
            case .mostRounds:
                return "\(trophyPrefix)\(Int(headline.newValue)) Runden \(exercise)"
            case .fastestTime:
                return "\(trophyPrefix)\(formatDuration(headline.newValue)) \(exercise)"
            }
        }()

        return Celebration(
            title: title,
            body: body,
            activityLine: activityLine,
            recordCount: records.count
        )
    }

    /// Bundle of strings tailored for the three render surfaces — push notification,
    /// Live Activity headline, and (eventually) Apple Watch face.
    public struct Celebration: Equatable, Sendable {
        public let title: String
        public let body: String
        /// Compact one-liner sized for Dynamic-Island / Lock-Screen banner.
        public let activityLine: String
        public let recordCount: Int

        public init(title: String, body: String, activityLine: String, recordCount: Int) {
            self.title = title
            self.body = body
            self.activityLine = activityLine
            self.recordCount = recordCount
        }
    }

    // MARK: - Title / detail per kind

    private static func title(for record: PersonalRecord, tone: CoachingTone) -> String {
        let base: String
        let emoji: String
        switch record.kind {
        case .estimated1RM:     base = "Neuer 1RM-Rekord!";       emoji = "🏆"
        case .heaviestWeight:   base = "Neues Maximalgewicht!";   emoji = "💪"
        case .bestSet:          base = "Neuer Bestsatz!";         emoji = "📈"
        case .maxReps:          base = "Neuer Reps-Rekord!";      emoji = "🔥"
        case .maxHoldSeconds:   base = "Neue Bestzeit!";          emoji = "⏱️"
        case .longestDistance:  base = "Längste Distanz!";        emoji = "🎉"
        case .fastestPace:      base = "Neue Best-Pace!";         emoji = "🔥"
        case .mostRounds:       base = "Neue Bestrunde!";         emoji = "🎉"
        case .fastestTime:      base = "Neue WOD-Bestzeit!";      emoji = "⚡"
        }
        guard tone == .motivating else { return base }
        return "\(base) \(emoji)"
    }

    private static func detail(for record: PersonalRecord) -> String {
        switch record.kind {
        case .estimated1RM:
            return "\(record.exerciseName) — \(formatNumber(record.newValue)) kg geschätzt (vorher \(formatNumber(record.previousValue)) kg)"
        case .heaviestWeight:
            return "\(record.exerciseName) — \(formatNumber(record.newValue)) kg (vorher \(formatNumber(record.previousValue)) kg)"
        case .bestSet:
            return "\(record.exerciseName) — \(formatNumber(record.weightKg)) kg × \(record.reps) (\(formatNumber(record.newValue)) kg-Vol)"
        case .maxReps:
            return "\(record.exerciseName) — \(record.reps) Wdh (vorher \(Int(record.previousValue.rounded())))"
        case .maxHoldSeconds:
            return "\(record.exerciseName) — \(record.reps) Sek (vorher \(Int(record.previousValue.rounded())) Sek)"
        case .longestDistance:
            return "\(record.exerciseName) — \(formatNumber(record.newValue)) km (vorher \(formatNumber(record.previousValue)) km)"
        case .fastestPace:
            return "\(record.exerciseName) — \(formatPace(record.newValue)) (vorher \(formatPace(record.previousValue)))"
        case .mostRounds:
            // Bugfix (Teil-Wiederholungen entfernt): siehe PRHistoryView.swift
            // fuer die Begruendung des reps > 0-Gates.
            guard record.reps > 0 else {
                return "\(record.exerciseName) — \(Int(record.newValue)) Runden (vorher \(Int(record.previousValue)) Runden)"
            }
            return "\(record.exerciseName) — \(Int(record.newValue)) Runden + \(record.reps) Wdh (vorher \(Int(record.previousValue)) Runden)"
        case .fastestTime:
            return "\(record.exerciseName) — \(formatDuration(record.newValue)) (vorher \(formatDuration(record.previousValue)))"
        }
    }

    // MARK: - Helpers

    /// Same priority as PRDetector.kindOrder. Lower = more impressive.
    /// DEL-064: Cardio-PRs ans Ende — bei Mixed-Sessions sollen Strength-
    /// PRs zuerst gefeiert werden (Brand-Erinnerung: wir sind primaer eine
    /// Strength-App; Cardio ist Add-On fuer Hybrid-Athleten).
    ///
    /// DEL-218: liest jetzt `PersonalRecord.Kind.displayPriority` statt eine
    /// eigene Kopie der Reihenfolge zu halten.
    private static func priority(_ kind: PersonalRecord.Kind) -> Int {
        kind.displayPriority
    }

    /// Pace-Formatter analog zu `PaceCalculator.formatPace`, aber als
    /// stand-alone-Hilfsfunktion damit dieser File keine zusaetzliche
    /// Cross-Module-Dependency braucht.
    private static func formatPace(_ minutesPerKm: Double) -> String {
        guard minutesPerKm.isFinite, minutesPerKm > 0 else { return "—:——" }
        let total = Int((minutesPerKm * 60.0).rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    /// Formatiert Auf-Zeit-Ergebnisse (Sekunden). Wiederverwendet
    /// `PaceCalculator.formatDuration`, statt einen dritten eigenen
    /// mm:ss-Formatter zu schreiben.
    private static func formatDuration(_ totalSeconds: Double) -> String {
        PaceCalculator.formatDuration(Int(totalSeconds.rounded()))
    }

    /// Truncate exercise names so the Dynamic Island doesn't overflow. ~14 chars
    /// fits comfortably in the expanded compactTrailing region.
    private static func shortenExercise(_ name: String) -> String {
        if name.count <= 14 { return name }
        return String(name.prefix(13)) + "…"
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        // 2 decimal places, German locale (comma) for consistency with the rest of the UI.
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
