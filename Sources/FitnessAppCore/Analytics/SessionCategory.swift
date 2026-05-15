import Foundation

/// DEL-081: Drei-State-Klassifizierung einer abgeschlossenen Workout-Session.
/// Steuert die UI-Stats-Zeile in HistorySessionRow, WorkoutSummary und den
/// Live-Header in ActiveWorkoutView.
///
///   * `.pureStrength` — Nur Kraft-/TimeBased-Saetze geloggt, kein Cardio.
///   * `.pureCardio`   — Nur Cardio-Saetze (mit `distanceKm > 0`) geloggt.
///   * `.mixed`        — Beides: mind. ein Strength-Satz UND mind. ein
///     Cardio-Satz mit Distanz. UI zeigt dann beide Hauptmetriken
///     (Volumen + Distanz), laesst dafuer Saetze und Pace weg.
public enum SessionCategory: Equatable, Sendable {
    case pureStrength
    case pureCardio
    case mixed

    /// Wertet eine Liste von Log-Klassifikationen zur Session-Kategorie aus.
    /// Pure-Logic-Helper: kann sowohl in Core-Tests als auch in der
    /// SwiftData-WorkoutSession-Extension genutzt werden.
    ///
    /// - Parameter logs: pro Log ein Tuple `(isCardio, distanceKm)`. Cardio-
    ///   Logs ohne Distanz (z.B. nur Dauer-Eingabe) werden NICHT als
    ///   "Cardio absolviert" gewertet — sonst wuerde ein abgebrochenes Run
    ///   ein Plan-Mixed-State faelschlich melden.
    public static func evaluate(logs: [(isCardio: Bool, distanceKm: Double?)]) -> SessionCategory {
        let hasStrength = logs.contains { !$0.isCardio }
        let hasCardio = logs.contains { $0.isCardio && ($0.distanceKm ?? 0) > 0 }
        switch (hasStrength, hasCardio) {
        case (true, true):   return .mixed
        case (false, true):  return .pureCardio
        default:             return .pureStrength
        }
    }
}
