import Foundation

/// Erkennt mögliche Trainings-Stagnation pro Übung.
/// Reine Core-Logik: kein SwiftData, kein SwiftUI, kein I/O.
public enum PlateauDetector {

    // MARK: - Konstanten

    public static let minExpositions         = 4
    public static let minPeriodDays          = 28
    /// Obergrenze für "kein Fortschritt": relChange < +2 % → Befund.
    public static let minImprovementFraction = 0.02
    /// Untergrenze für Stagnation: relChange < −10 % → Regression (nicht Plateau).
    public static let regressionThreshold    = 0.10
    public static let robustWindowSize       = 2         // Median über jeweils 2 früheste / 2 späteste
    public static let repRange               = 1...12    // Kraftbereich; außerhalb → ungültig

    // MARK: - Status

    public enum DetectionStatus: Sendable {
        /// −regressionThreshold ≤ relChange < +minImprovementFraction.
        /// Passende xcstrings-Keys: coaching.plateauDetected.*.
        case stagnation
        /// relChange < −regressionThreshold (mehr als 10 % Rückgang).
        /// Kein Emitter/xcstrings-Key vorhanden — wird vom Dashboard-Layer nicht angezeigt.
        case regression
    }

    // MARK: - Input

    /// Beste e1RM-Schätzung einer Übung an einem Kalendertag einer realen Session.
    public struct Exposition: Sendable {
        public let exerciseName: String
        public let exerciseTemplateID: UUID?   // nil → Fallback auf Name
        public let calendarDay: Date           // Calendar.startOfDay(for: sessionDate)
        public let bestE1RM: Double

        public init(
            exerciseName: String,
            exerciseTemplateID: UUID?,
            calendarDay: Date,
            bestE1RM: Double
        ) {
            self.exerciseName = exerciseName
            self.exerciseTemplateID = exerciseTemplateID
            self.calendarDay = calendarDay
            self.bestE1RM = bestE1RM
        }
    }

    // MARK: - Output

    public struct Finding: Sendable {
        public let exerciseName: String
        public let expositionCount: Int
        public let periodDays: Int
        /// (latestMedian − earlyMedian) / earlyMedian.
        /// Negativ = Rückgang, ~0 = Stagnation.
        public let relativeChangeFraction: Double
        public let status: DetectionStatus
    }

    // MARK: - Hauptfunktion

    /// Gibt den deterministischen Top-Befund zurück, oder nil wenn nichts stagniert
    /// oder zurückgegangen ist.
    /// Sortierung: längste Beobachtungsperiode zuerst, Übungsname als stabiler Tiebreaker.
    public static func detect(expositions: [Exposition]) -> Finding? {
        var groups: [GroupKey: [Exposition]] = [:]
        for exp in expositions {
            let k = GroupKey(templateID: exp.exerciseTemplateID, name: exp.exerciseName)
            groups[k, default: []].append(exp)
        }
        return groups.values
            .compactMap { evaluate($0) }
            .sorted { lhs, rhs in
                lhs.periodDays != rhs.periodDays
                    ? lhs.periodDays > rhs.periodDays
                    : lhs.exerciseName < rhs.exerciseName
            }
            .first
    }

    // MARK: - Private

    private enum GroupKey: Hashable {
        case id(UUID)
        case name(String)

        init(templateID: UUID?, name: String) {
            self = templateID.map(GroupKey.id) ?? .name(name)
        }
    }

    private static func evaluate(_ raw: [Exposition]) -> Finding? {
        // Deduplizieren: mehrere Sessions an einem Tag → max e1RM
        let deduped: [Exposition] = Dictionary(grouping: raw, by: \.calendarDay)
            .compactMap { _, group in group.max(by: { $0.bestE1RM < $1.bestE1RM }) }
            .sorted { $0.calendarDay < $1.calendarDay }

        guard deduped.count >= minExpositions,
              let first = deduped.first, let last = deduped.last else { return nil }

        let days = Calendar.current
            .dateComponents([.day], from: first.calendarDay, to: last.calendarDay).day ?? 0
        guard days >= minPeriodDays else { return nil }

        let earlyMedian = median(deduped.prefix(robustWindowSize).map(\.bestE1RM))
        let lateMedian  = median(deduped.suffix(robustWindowSize).map(\.bestE1RM))

        guard earlyMedian > 0, earlyMedian.isFinite, lateMedian.isFinite else { return nil }

        let relChange = (lateMedian - earlyMedian) / earlyMedian
        guard relChange < minImprovementFraction else { return nil }   // klarer Fortschritt → kein Befund

        let status: DetectionStatus = relChange < -regressionThreshold ? .regression : .stagnation

        return Finding(
            exerciseName: raw.first?.exerciseName ?? "",
            expositionCount: deduped.count,
            periodDays: days,
            relativeChangeFraction: relChange,
            status: status
        )
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let s = values.sorted()
        let m = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
    }
}
