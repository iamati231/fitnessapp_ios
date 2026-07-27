#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// DEL-222: Der EINZIGE Schreiber von `Gear.currentDistanceKm`.
///
/// Regel ab hier: `currentDistanceKm` wird ausserhalb dieser Datei und des
/// Gear-Editors nicht mehr direkt zugewiesen. Wer Cardio-Logs anlegt, loescht
/// oder deren Distanz aendert, bucht das Delta hier.
///
/// **Warum kein blindes Neurechnen aus den Logs.** Naheliegend waere
/// `currentDistanceKm = Summe aller Session-Kilometer`. Das waere aber ein
/// Datenverlust: der Gear-Editor (`GearListView`) laesst den User den
/// Kilometerstand direkt eintippen — der typische Fall ist ein Schuh, der beim
/// Anlegen schon 250 km auf der Uhr hatte, oder eine manuelle Korrektur. Ein
/// Recompute wuerde diesen Anteil stillschweigend verwerfen.
///
/// `trackedDistanceKm(for:in:)` liefert deshalb nur die *nachvollziehbare*
/// Teilmenge und ueberschreibt nichts. Sauber loesen liesse sich das mit einem
/// zusaetzlichen `baselineDistanceKm`-Feld (manuelle Basis + getrackte
/// Kilometer, damit der Stand herleitbar und nicht driftbar ist) — das ist eine
/// Schema-Aenderung und wartet bewusst darauf, dass das Projekt einen
/// versionierten Migrationsplan hat.
public enum GearOdometer {

    /// Bucht ein Delta (positiv = dazu, negativ = zurueck) auf das Gear.
    /// No-op ohne Gear oder bei Delta 0.
    public static func book(deltaKm: Double, to gear: Gear?) {
        guard let gear, deltaKm != 0 else { return }
        gear.currentDistanceKm = GearDistance.booked(
            current: gear.currentDistanceKm,
            delta: deltaKm
        )
    }

    /// Haengt eine Distanz von einem Gear auf ein anderes um. Wird beim
    /// nachtraeglichen Gear-Wechsel einer Session gebraucht.
    public static func transfer(km: Double, from old: Gear?, to new: Gear?) {
        guard old?.persistentModelID != new?.persistentModelID else { return }
        book(deltaKm: -km, to: old)
        book(deltaKm: km, to: new)
    }

    /// Cardio-Kilometer einer Session (Summe ueber ihre Logs).
    public static func distanceKm(of session: WorkoutSession) -> Double {
        GearDistance.total(of: session.logs.map(\.distanceKm))
    }

    /// Summe der Kilometer aus allen ABGESCHLOSSENEN Sessions, die auf dieses
    /// Gear gebucht sind — also der Teil des Kilometerstands, den die App
    /// belegen kann.
    ///
    /// Filterung in-memory statt per `#Predicate`: SwiftData-Praedikate auf
    /// Relationships sind unzuverlaessig (dieselbe Entscheidung wie bei den
    /// Datums-Cutoffs im WaterTracker).
    public static func trackedDistanceKm(for gear: Gear, in context: ModelContext) -> Double {
        let all = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let mine = all.filter {
            $0.isCompleted && $0.gear?.persistentModelID == gear.persistentModelID
        }
        return mine.reduce(0.0) { $0 + distanceKm(of: $1) }
    }
}
#endif
