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
    public static func make(from records: [PersonalRecord]) -> Celebration? {
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

        let title = title(for: headline)
        var body = detail(for: headline)
        if remaining > 0 {
            body += "  •  +\(remaining) weitere\(remaining == 1 ? "r" : "") Rekord\(remaining == 1 ? "" : "e")"
        }

        // Compact one-liner for the Live Activity (limited horizontal space).
        let activityLine: String = {
            let exercise = shortenExercise(headline.exerciseName)
            switch headline.kind {
            case .maxReps:
                return "🏆 \(headline.reps) Wdh \(exercise)"
            case .maxHoldSeconds:
                return "🏆 \(headline.reps)s \(exercise)"
            case .estimated1RM, .heaviestWeight:
                return "🏆 \(formatNumber(headline.newValue)) kg \(exercise)"
            case .bestSet:
                return "🏆 \(formatNumber(headline.weightKg))×\(headline.reps) \(exercise)"
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

    private static func title(for record: PersonalRecord) -> String {
        switch record.kind {
        case .estimated1RM:    return "Neuer 1RM-Rekord! 🏆"
        case .heaviestWeight:  return "Neues Maximalgewicht! 💪"
        case .bestSet:         return "Neuer Bestsatz! 📈"
        case .maxReps:         return "Neuer Reps-Rekord! 🔥"
        case .maxHoldSeconds:  return "Neue Bestzeit! ⏱️"
        }
    }

    private static func detail(for record: PersonalRecord) -> String {
        switch record.kind {
        case .estimated1RM:
            return "\(record.exerciseName) — \(formatNumber(record.newValue)) kg geschaetzt (vorher \(formatNumber(record.previousValue)) kg)"
        case .heaviestWeight:
            return "\(record.exerciseName) — \(formatNumber(record.newValue)) kg (vorher \(formatNumber(record.previousValue)) kg)"
        case .bestSet:
            return "\(record.exerciseName) — \(formatNumber(record.weightKg)) kg × \(record.reps) (\(formatNumber(record.newValue)) kg-Vol)"
        case .maxReps:
            return "\(record.exerciseName) — \(record.reps) Wdh (vorher \(Int(record.previousValue.rounded())))"
        case .maxHoldSeconds:
            return "\(record.exerciseName) — \(record.reps) Sek (vorher \(Int(record.previousValue.rounded())) Sek)"
        }
    }

    // MARK: - Helpers

    /// Same priority as PRDetector.kindOrder. Lower = more impressive.
    private static func priority(_ kind: PersonalRecord.Kind) -> Int {
        switch kind {
        case .estimated1RM:    return 0
        case .heaviestWeight:  return 1
        case .bestSet:         return 2
        case .maxReps:         return 3
        case .maxHoldSeconds:  return 4
        }
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
