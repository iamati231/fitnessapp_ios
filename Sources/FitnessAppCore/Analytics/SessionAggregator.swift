import Foundation

/// DEL-221: Aggregat-Berechnung einer Trainings-Session als reine Funktion.
///
/// **Warum das existiert.** `WorkoutSession.totalSets` und `.totalVolumeKg`
/// wurden an fuenf Stellen von Hand gerechnet — beim Finish
/// (`ActiveWorkoutView`), beim Verlassen des History-Edit-Modes und beim
/// Satz-Loeschen (`WorkoutSummaryView`, zweimal), beim Fortsetzen im
/// `DayEditorView` und im Preview-Seed. Jede Kopie war fuer sich korrekt, aber
/// niemand garantierte, dass alle fuenf dieselbe Formel benutzen, und ein
/// vergessener Aufruf hinterliess dauerhaft falsche Zahlen. Auf diesen Werten
/// sitzen Dashboard-Wochenvolumen, Coach-Schwellen (5000 kg), DeloadAdvisor
/// und Muskel-Heatmap — stille Fehler dort verfaelschen jede Auswertung.
///
/// Die Berechnung liegt bewusst in Core und nicht in FitnessAppData: sie
/// braucht kein SwiftData, ist damit auf jeder Plattform testbar (inkl. der
/// Windows-Toolchain, auf der `FitnessAppData` nicht kompiliert) und der
/// SwiftData-Adapter in `WorkoutSession.recomputeTotals()` bleibt ein
/// Zweizeiler.
public enum SessionAggregator {

    /// Ein geloggter Satz, reduziert auf das, was fuer die Aggregate zaehlt.
    /// Bewusst kein `ExerciseLog` — das ist ein `@Model` und wuerde die
    /// SwiftData-Abhaengigkeit hier hereinziehen.
    public struct LoggedSet: Sendable, Equatable {
        public let weightKg: Double
        public let reps: Int

        public init(weightKg: Double, reps: Int) {
            self.weightKg = weightKg
            self.reps = reps
        }
    }

    /// Ergebnis der Aggregation.
    public struct Totals: Sendable, Equatable {
        /// Anzahl geloggter Saetze.
        public let setCount: Int
        /// Summe aus `Gewicht × Wiederholungen` ueber alle Saetze (kg).
        public let volumeKg: Double

        public init(setCount: Int, volumeKg: Double) {
            self.setCount = setCount
            self.volumeKg = volumeKg
        }

        public static let zero = Totals(setCount: 0, volumeKg: 0)
    }

    /// Berechnet Satz-Anzahl und Volumen.
    ///
    /// Bewusste Festlegungen — sie halten das Verhalten der fuenf ersetzten
    /// Handrechnungen bei, machen die Kanten aber explizit und testbar:
    ///
    ///   * **Bodyweight-Saetze** (`weightKg == 0`) tragen 0 zum Volumen bei,
    ///     zaehlen aber als Satz. Klimmzuege sind Arbeit, auch wenn die
    ///     Hantelstange leer bleibt.
    ///   * **Cardio-Saetze** (weight und reps beide 0) zaehlen ebenfalls als
    ///     Satz. Das entspricht dem Bestandsverhalten (`logs.count`), auch
    ///     wenn "Satz" fuer einen Lauf sprachlich schief ist.
    ///   * **Negative Werte** werden beim Volumen auf 0 geklemmt, statt die
    ///     Summe zu verkleinern. Negative Gewichte oder Reps sind
    ///     Datenfehler; ein einzelner solcher Datensatz soll nicht das
    ///     Wochenvolumen des Users nach unten manipulieren. Als Satz zaehlt
    ///     er weiterhin, damit die Zeile nicht unsichtbar wird.
    public static func totals(for sets: [LoggedSet]) -> Totals {
        var volume = 0.0
        for set in sets where set.weightKg > 0 && set.reps > 0 {
            volume += set.weightKg * Double(set.reps)
        }
        return Totals(setCount: sets.count, volumeKg: volume)
    }
}
