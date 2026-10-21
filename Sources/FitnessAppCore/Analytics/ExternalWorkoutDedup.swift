import Foundation

/// Reine Zeitfenster-Ueberlappungs-Logik fuer den HealthKit-Workout-Import
/// (siehe `FitnessAppUI.ExternalWorkoutImportService`). Als eigene, reine
/// Funktion hier in Core extrahiert, damit sie ueber `FitnessAppCoreTests`
/// abgedeckt werden kann — `FitnessAppUI` hat kein eigenes Test-Target, und
/// die eigentliche SwiftData-Orchestrierung braucht einen `ModelContext`,
/// den wir hier nicht mocken wollen.
public enum ExternalWorkoutDedup {

    /// Ein externes Sample (z.B. ein von Adidas Running getrackter Lauf)
    /// gilt als "schon vorhanden", wenn mehr als die Haelfte seiner EIGENEN
    /// Dauer mit einem bestehenden Zeitfenster ueberlappt. Exakte Sekunden-
    /// Gleichheit (wie beim CSV-Reimport-Dedup) passt hier nicht — ein von
    /// einer Fremd-App getrackter Lauf und ein manuell in der App
    /// nacherfasster Lauf haben nie exakt denselben Start-Zeitstempel.
    public static func overlapsExisting(
        sampleStart: Date,
        sampleEnd: Date,
        existingWindows: [(start: Date, end: Date)]
    ) -> Bool {
        let sampleDuration = sampleEnd.timeIntervalSince(sampleStart)
        guard sampleDuration > 0 else { return false }
        for window in existingWindows {
            let overlapStart = max(sampleStart, window.start)
            let overlapEnd = min(sampleEnd, window.end)
            let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
            if overlapDuration / sampleDuration > 0.5 { return true }
        }
        return false
    }
}
