#if canImport(SwiftData)
import Foundation
import FitnessAppCore

/// P8 Stufe-2 (Session-Inhaltsvertrag): snapshot-first lesen mit Live-
/// Fallback NUR für Alt-Sessions, für die NIE ein Snapshot aufgenommen
/// wurde (`.notCaptured`). Ein vorhandener, aber beschädigter/nicht
/// unterstützter Snapshot (`.unreadable`) liefert bewusst `nil` statt
/// stillschweigend auf den (ggf. inzwischen anders aussehenden) Live-Tag
/// auszuweichen. Geteilt zwischen `WorkoutSummaryView` (Historie,
/// abgeschlossene Session) und den Zeitformat-/Zirkel-Playern
/// (`TimedWorkoutPlayerView`/`CircuitWorkoutPlayerView`) für eine laufende/
/// wiederaufgenommene Session — in beiden Fällen gilt: eine externe
/// Änderung an `day.timeCapMinutes`/`circuitRounds`/`circuitRestSeconds`/
/// `circuitMode` seit Session-Start darf weder die Anzeige noch (bei den
/// Playern) die tatsächliche Timer-/Rundenlogik beeinflussen.
extension WorkoutSession {
    public func contentSnapshotFirst<T>(
        _ fromSnapshot: (TrainingDayContentSnapshot) -> T?,
        liveFallback: () -> T?
    ) -> T? {
        switch contentSnapshotState {
        case .available(let snapshot): return fromSnapshot(snapshot)
        case .notCaptured: return liveFallback()
        case .unreadable: return nil
        }
    }

    public var contentSnapshotTimeCapMinutes: Int? {
        contentSnapshotFirst({ $0.timeCapMinutes }, liveFallback: { day?.timeCapMinutes })
    }

    public var contentSnapshotCircuitRounds: Int? {
        contentSnapshotFirst({ $0.circuitRounds }, liveFallback: { day?.circuitRounds })
    }

    public var contentSnapshotCircuitRestSeconds: Int? {
        contentSnapshotFirst({ $0.circuitRestSeconds }, liveFallback: { day?.circuitRestSeconds })
    }

    /// P8 Stufe-2-Nachbesserung (Resume-Isolation): steuert bei
    /// `CircuitWorkoutPlayerView` die tatsächliche Rundenabschluss-LOGIK
    /// (`.toFailure` vs. `.fixedReps`), nicht nur eine Anzeige — deshalb
    /// hier mit aufgenommen, obwohl `WorkoutSummaryView` es bisher nicht
    /// brauchte.
    public var contentSnapshotCircuitMode: CircuitRoundMode? {
        contentSnapshotFirst({ $0.circuitMode }, liveFallback: { day?.circuitMode })
    }
}
#endif
