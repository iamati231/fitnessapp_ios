import Foundation

/// DEL-082: Vier-Stufen-Klassifizierung des Wochen-Volumens pro Muskel-
/// gruppe. UI-Layer rendert die Heatmap-Tiles je nach Bucket in
/// unterschiedlichen Farben.
///
/// Quellen:
///   * 0 Saetze         → `.untrained` (System-Gray)
///   * 1–8 Saetze       → `.maintenance` (Light-Orange) — reicht zum
///     Halten, nicht zum Wachsen
///   * 9–18 Saetze      → `.optimal` (DeltiqOrange) — Hypertrophie-Sweet-Spot
///     laut Schoenfeld-Reviews
///   * >18 Saetze       → `.overreaching` (Red) — Recovery-Risiko, evtl.
///     zu viel Junk-Volume
public enum MuscleVolumeBucket: Equatable, Sendable, CaseIterable {
    case untrained       // 0
    case maintenance     // 1...8
    case optimal         // 9...18
    case overreaching    // 19+

    /// Klassifiziert eine Set-Anzahl in den passenden Bucket.
    public init(setsThisWeek count: Int) {
        switch count {
        case ...0:     self = .untrained
        case 1...8:    self = .maintenance
        case 9...18:   self = .optimal
        default:       self = .overreaching
        }
    }

    /// Deutscher User-Label fuer den Bucket. Wird im UI als Untertitel
    /// pro Tile angezeigt.
    public var label: String {
        switch self {
        case .untrained:     return "Untrainiert"
        case .maintenance:   return "Erhalt"
        case .optimal:       return "Optimal"
        case .overreaching:  return "Übervolumen"
        }
    }
}

/// DEL-082: Aggregat einer Muskelgruppe in der aktuellen Kalenderwoche.
/// View-Layer rendert ein Tile pro Group.
public struct MuscleWeeklyVolume: Equatable, Sendable, Identifiable {
    public let group: MuscleGroup
    public let setsCount: Int
    public var bucket: MuscleVolumeBucket { MuscleVolumeBucket(setsThisWeek: setsCount) }

    public var id: MuscleGroup { group }

    public init(group: MuscleGroup, setsCount: Int) {
        self.group = group
        self.setsCount = setsCount
    }
}

// MARK: - DEL-082 Weekly-Volume Aggregator

/// Pure-Aggregator: nimmt eine Liste von Logs (mit Datum + Exercise-Name) und
/// liefert pro MuscleGroup das Set-Count innerhalb der aktuellen Kalenderwoche.
///
/// Exercise-Name → MuscleGroup Mapping laeuft ueber ein injektiertes Closure
/// (`nameToMuscle`), damit die SwiftData-Library-Lookups View-Layer-side
/// passieren und Core SwiftData-frei bleibt.
public enum MuscleVolumeAggregator {

    /// Berechnet Wochen-Volume pro Muskelgruppe.
    ///
    /// - Parameter logs: pro Log ein Tuple `(date, exerciseName, isCardio)`.
    ///   Cardio-Logs werden uebersprungen (kein "Volume"-Begriff).
    /// - Parameter weekStart: Kalenderwochen-Start (Mo 00:00 in DE,
    ///   So 00:00 in US). Caller liefert via
    ///   `Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear])`.
    /// - Parameter nameToMuscle: Mapping vom Exercise-Namen auf die
    ///   `primaryMuscle`-Group. Closure damit Core SwiftData-frei bleibt.
    /// - Returns: ein Eintrag pro MuscleGroup.allCases, sortiert in
    ///   Display-Reihenfolge (chest, back, shoulders, ...).
    public static func aggregate(
        logs: [(date: Date, exerciseName: String, isCardio: Bool)],
        weekStart: Date,
        nameToMuscle: (String) -> MuscleGroup?
    ) -> [MuscleWeeklyVolume] {
        let weekLogs = logs.filter { !$0.isCardio && $0.date >= weekStart }
        var counts: [MuscleGroup: Int] = [:]
        for log in weekLogs {
            guard let muscle = nameToMuscle(log.exerciseName) else { continue }
            counts[muscle, default: 0] += 1
        }
        return MuscleGroup.allCases.map { group in
            MuscleWeeklyVolume(group: group, setsCount: counts[group] ?? 0)
        }
    }
}
