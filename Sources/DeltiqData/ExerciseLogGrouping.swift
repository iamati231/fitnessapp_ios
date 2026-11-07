#if canImport(SwiftData)
import Foundation
import SwiftData

/// P8 Stufe-2 (`docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`): wie eine Historien-
/// Ansicht (`WorkoutSummaryView`) `WorkoutSession.logs` zu Übungs-Sektionen
/// gruppiert — inklusive der Fälle, in denen die zugehörige `Exercise`
/// inzwischen gelöscht wurde (orphan).
public enum ExerciseLogGroup: Identifiable, Sendable {
    /// Die `Exercise` existiert noch — volle Funktionalität (Edit, Delete,
    /// Cardio-Equipment-Picker) bleibt möglich.
    case live(Exercise, [ExerciseLog])
    /// `Exercise` wurde gelöscht. `key` disambiguiert zwei gleichnamige,
    /// inzwischen gelöschte Übungen am selben Tag (siehe `ExerciseLogGrouping.group`).
    case orphaned(key: String, logs: [ExerciseLog])

    public var id: String {
        switch self {
        case .live(let exercise, _): return "live-\(exercise.persistentModelID)"
        case .orphaned(let key, _): return "orphan-\(key)"
        }
    }

    /// Sortierschlüssel — für orphane Gruppen der `orderIndex` zum
    /// Logging-Zeitpunkt (`ExerciseLog.exerciseOrderIndexSnapshot`), NICHT
    /// der Name; Alt-Logs ohne dieses Feld landen ans Ende statt eine
    /// falsche Position zu erraten.
    public var orderIndex: Int {
        switch self {
        case .live(let exercise, _): return exercise.orderIndex
        case .orphaned(_, let logs): return logs.first?.exerciseOrderIndexSnapshot ?? Int.max
        }
    }

    public var logs: [ExerciseLog] {
        switch self {
        case .live(_, let logs): return logs
        case .orphaned(_, let logs): return logs
        }
    }
}

/// Einzige Gruppierstelle für "welche Logs gehören zu welcher Übung" in
/// einer Historien-Ansicht. Ein Log ohne lebende `Exercise`-Referenz
/// (orphan, z. B. nach Tag-/Übungslöschung) wurde vor P8 Stufe-2 an dieser
/// Stelle komplett verworfen — der Satz blieb zwar in
/// `session.totalSets`/`totalVolumeKg` mitgezählt, verschwand aber
/// unsichtbar aus der Aufschlüsselung. `group(_:)` verwirft nichts mehr.
public enum ExerciseLogGrouping {
    /// Gruppiert nach lebender Objektidentität (`Exercise.persistentModelID`),
    /// wenn vorhanden. Für orphane Logs ist der Schlüssel
    /// `exerciseOrderIndexSnapshot` (fehlt der bei Alt-Logs vor diesem Feld:
    /// `exerciseTemplateIDSnapshot` + `exerciseNameSnapshot`) — NICHT allein
    /// der Name, sonst würden zwei gleichnamige, inzwischen gelöschte
    /// Übungen (z. B. Hauptsatz + Finisher) fälschlich zu einer Gruppe
    /// verschmolzen. Ergebnis sortiert nach `orderIndex`.
    public static func group(_ logs: [ExerciseLog]) -> [ExerciseLogGroup] {
        let liveLogs = logs.filter { $0.exercise != nil }
        let orphanLogs = logs.filter { $0.exercise == nil }

        let liveGrouped = Dictionary(grouping: liveLogs) { $0.exercise!.persistentModelID }
        let live: [ExerciseLogGroup] = liveGrouped.compactMap { (_, logs) -> ExerciseLogGroup? in
            guard let exercise = logs.first?.exercise else { return nil }
            return .live(exercise, logs.sorted { $0.setIndex < $1.setIndex })
        }

        let orphanGrouped = Dictionary(grouping: orphanLogs) { log -> String in
            if let idx = log.exerciseOrderIndexSnapshot { return "idx:\(idx)" }
            return "key:\(log.exerciseTemplateIDSnapshot?.uuidString ?? "-")|\(log.exerciseNameSnapshot ?? "-")"
        }
        let orphaned: [ExerciseLogGroup] = orphanGrouped.map { (key, logs) in
            .orphaned(key: key, logs: logs.sorted { $0.setIndex < $1.setIndex })
        }

        return (live + orphaned).sorted { $0.orderIndex < $1.orderIndex }
    }
}
#endif
