#if canImport(SwiftData)
import Foundation
import FitnessAppCore

// DEL-221: Der EINZIGE Schreiber der Session-Aggregate.
//
// Regel ab hier: `session.totalSets` und `session.totalVolumeKg` werden
// ausserhalb dieser Datei NICHT mehr direkt zugewiesen. Wer Logs einer Session
// hinzufuegt, entfernt oder deren Gewicht/Reps aendert, ruft danach
// `recomputeTotals()`. Die Formel selbst lebt in
// `FitnessAppCore.SessionAggregator` und ist dort ohne SwiftData getestet.

public extension WorkoutSession {

    /// Rechnet `totalSets` und `totalVolumeKg` aus den aktuellen Logs neu.
    ///
    /// - Parameter exerciseCount: Optionale Neubelegung von `exerciseCount`.
    ///   Bewusst ein Parameter und keine Ableitung aus `logs`: die Bedeutung
    ///   des Feldes haengt am Aufrufer. `ActiveWorkoutView` zaehlt beim Finish
    ///   die tatsaechlich angezeigten Uebungen (DEL-092: bei versteckten
    ///   Warmups zaehlen diese nicht mit), waehrend die Plan-Pfade
    ///   `day.activeExercises.count` verwenden. Diese beiden Zahlen
    ///   unterscheiden sich legitim — sie hier zu vereinheitlichen wuerde
    ///   Bestands-History umschreiben. `nil` laesst das Feld unangetastet.
    /// - Returns: Die berechneten Aggregate, falls der Aufrufer sie direkt
    ///   weiterverwenden will (z.B. fuer eine Live-Activity-Update).
    @discardableResult
    func recomputeTotals(exerciseCount newExerciseCount: Int? = nil) -> SessionAggregator.Totals {
        let totals = SessionAggregator.totals(
            for: logs.map {
                SessionAggregator.LoggedSet(weightKg: $0.weight, reps: $0.reps)
            }
        )
        totalSets = totals.setCount
        totalVolumeKg = totals.volumeKg
        if let newExerciseCount {
            exerciseCount = newExerciseCount
        }
        return totals
    }
}
#endif
