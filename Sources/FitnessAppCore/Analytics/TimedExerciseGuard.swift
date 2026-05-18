import Foundation

/// DEL-097: Pure-Logic-Helper fuer den Single-Active-Time-Based-Exercise-
/// Guard. Lebt im Core, damit die Regel auf Windows-CI getestbar bleibt —
/// die eigentliche UI-Verzweigung in `SetRow.swift` spiegelt dieselbe
/// Semantik via Computed Properties.
///
/// **Vertrag:**
///   * Strength + Cardio (Non-Time-Based) sind nie geguarded — `canStart`
///     liefert dort immer `true`.
///   * Wenn der Slot leer ist (kein Lock aktiv), darf jede Time-Exercise
///     starten.
///   * Wenn der Slot von der CANDIDATE-Uebung selbst gehalten wird, ist
///     der Resume-Pfad erlaubt — die laufende Plank wieder anzufassen
///     soll natuerlich klappen.
///   * Nur wenn der Slot von einer ANDEREN Time-Exercise gehalten wird,
///     blockt der Guard.
public enum TimedExerciseGuard {

    /// True wenn die `candidate`-Uebung gestartet werden darf.
    /// `candidateID` und `activeTimedExerciseID` sind generisch
    /// (`Hashable`), damit Tests `String`/`UUID`/`Int` einkippen koennen
    /// und der UI-Code `PersistentIdentifier` aus SwiftData.
    public static func canStart<ID: Hashable>(
        candidateID: ID,
        candidateIsTimeBased: Bool,
        activeTimedExerciseID: ID?
    ) -> Bool {
        guard candidateIsTimeBased else { return true }
        guard let active = activeTimedExerciseID else { return true }
        return active == candidateID
    }

    /// True wenn die `candidate`-Uebung von einer ANDEREN laufenden
    /// Time-Exercise blockiert wird. Inverse von `canStart` fuer Non-
    /// Time-Based-Candidates immer false (nie blockiert), ansonsten
    /// das passende Komplement.
    public static func isBlockedByOther<ID: Hashable>(
        candidateID: ID,
        candidateIsTimeBased: Bool,
        activeTimedExerciseID: ID?
    ) -> Bool {
        guard candidateIsTimeBased else { return false }
        guard let active = activeTimedExerciseID else { return false }
        return active != candidateID
    }
}
