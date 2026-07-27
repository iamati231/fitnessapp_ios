import Foundation

/// DEL-222: Kilometer-Arithmetik fuer Equipment (Laufschuhe, Raeder) als reine
/// Funktionen.
///
/// **Warum das existiert.** `Gear.currentDistanceKm` wurde an fuenf Stellen
/// per Delta gebucht: Credit beim Workout-Finish, Debit beim Loeschen einer
/// Session, Debit beim Loeschen einzelner Saetze, Delta beim Nachtragen einer
/// Distanz und ein Transfer beim Umhaengen auf ein anderes Gear. Jede Stelle
/// hat ihren eigenen `max(0, ...)`-Clamp mitgebracht, und keine hat je
/// nachgerechnet. Ein vergessener Pfad heisst: der Kilometerstand eines
/// Laufschuhs laeuft dauerhaft aus dem Ruder — und daran haengt die
/// "Schuh wechseln"-Warnung.
///
/// Bewusst in Core und SwiftData-frei: damit auf der Windows-Toolchain
/// testbar, waehrend der Zugriff auf die Session-Logs im Data-Modul bleibt.
public enum GearDistance {

    /// Summiert Cardio-Distanzen. Toleriert `nil` (Kraft-Logs fuehren keine
    /// Distanz) und ignoriert negative Werte, statt die Summe zu verkleinern —
    /// eine kaputte Zeile soll den Kilometerstand nicht nach unten faelschen.
    public static func total(of distancesKm: [Double?]) -> Double {
        var sum = 0.0
        for case let .some(km) in distancesKm where km > 0 {
            sum += km
        }
        return sum
    }

    /// Wendet ein Delta auf einen Kilometerstand an und klemmt bei 0.
    ///
    /// Der Clamp ist der Grund, warum das eine Funktion ist: er lag vorher in
    /// vier Kopien im UI-Layer, und ein negativer Kilometerstand wuerde
    /// `Gear.progress` und damit die Austausch-Warnung unsinnig machen.
    public static func booked(current: Double, delta: Double) -> Double {
        max(0, current + delta)
    }
}
