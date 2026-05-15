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
    /// - Parameter logs: pro Log ein Tuple `(isCardio, distanceKm, durationSeconds)`.
    ///
    /// **DEL-093: Ad-Hoc-Cardio-Fix.** Frueher haben wir Cardio-Logs ohne
    /// Distanz als "nicht absolviert" gewertet — das fuehrte dazu, dass ein
    /// reines Laufband-Workout mit nur Dauer-Eingabe als `.pureStrength`
    /// gekippt ist und in History "0 Sätze · 0 kg" anzeigte. Die neue
    /// Logik:
    ///
    ///   * **Reines Cardio-Workout** (keine Strength-Logs, mind. ein
    ///     Cardio-Log) → `.pureCardio`, unabhaengig von Distanz/Dauer.
    ///     Defensiver Fallback fuer freie Ad-Hoc-Trainings.
    ///   * **Strength + Cardio mit Distanz/Dauer** → `.mixed`.
    ///   * **Strength + Cardio-Log ohne Werte** (abgebrochen) → `.pureStrength`,
    ///     damit ein geskippter Run keinen Mixed-Header faelscht.
    ///   * **Empty / nur strength** → `.pureStrength`.
    public static func evaluate(
        logs: [(isCardio: Bool, distanceKm: Double?, durationSeconds: Int?)]
    ) -> SessionCategory {
        let hasStrength = logs.contains { !$0.isCardio }
        let hasMeaningfulCardio = logs.contains {
            $0.isCardio && (($0.distanceKm ?? 0) > 0 || ($0.durationSeconds ?? 0) > 0)
        }
        let hasAnyCardio = logs.contains { $0.isCardio }

        // Reines Cardio: keine Strength-Logs + mind. ein Cardio-Log →
        // pureCardio, unabhaengig vom Distanz-/Dauer-Fuell-Stand.
        if !hasStrength && hasAnyCardio { return .pureCardio }

        // Mixed nur, wenn der Cardio-Anteil substanziell ist.
        if hasStrength && hasMeaningfulCardio { return .mixed }

        return .pureStrength
    }
}
