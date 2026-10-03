import Foundation

/// Die Laufzeit eines aus Apple Health importierten Workouts (Lauf oder Radfahrt
/// einer anderen App, siehe `FitnessAppUI.ExternalWorkoutImportService`).
///
/// HealthKit kennt zwei Zeiten: Beginn bis Ende (`startDate`/`endDate`) und die
/// Dauer des Workouts (`HKWorkout.duration`). Die Dauer ist die AKTIVE Zeit: Die
/// Quell-App oder die Uhr zieht Pausen ab (Pause-/Fortsetzen-Ereignisse) oder gibt
/// ihre eigene Zeit an. Fuer einen Lauf ist sie die richtige Laufzeit — mit ihr
/// stimmen Dauer und Pace mit der Quell-App (und Apple Fitness) ueberein, waehrend
/// Beginn bis Ende jede Pause an der Ampel mitzaehlt.
///
/// Wie ueberall in der App wird NIE aufgerundet: 25:59,6 sind 25:59 und damit
/// 25 Minuten, nicht 26.
public enum ExternalWorkoutDuration {

    /// Um so viel darf die aktive Dauer Beginn bis Ende ueberschreiten
    /// (Sekundenrundung der Quell-App), ohne unplausibel zu werden.
    public static let toleranceSeconds: TimeInterval = 1

    /// Die Laufzeit in ganzen Sekunden (abgerundet): die aktive Dauer der Quelle,
    /// wenn sie plausibel ist (> 0 und nicht laenger als Beginn bis Ende), sonst
    /// Beginn bis Ende.
    public static func seconds(start: Date, end: Date, activeSeconds: TimeInterval?) -> Int {
        let span = max(0, end.timeIntervalSince(start))
        if let active = activeSeconds, active.isFinite, active > 0, active <= span + toleranceSeconds {
            return Int(min(active, span))
        }
        return Int(span)
    }

    /// Was die fruehere Version fuer dasselbe Workout gespeichert hat: Beginn bis
    /// Ende, auf die naechste Sekunde GERUNDET.
    public static func legacySeconds(start: Date, end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start).rounded()))
    }

    /// Die richtige Laufzeit fuer eine BEREITS importierte Einheit — aber nur,
    /// solange sie noch so aussieht, wie der fruehere Import sie angelegt hat
    /// (Sekunden und Minuten unveraendert). Hat der Nutzer die Dauer im Verlauf
    /// geaendert, bleibt seine Aenderung.
    /// - Returns: die neuen Sekunden oder `nil`, wenn nichts zu aendern ist.
    public static func correctedSeconds(
        storedSeconds: Int,
        storedMinutes: Int,
        start: Date,
        end: Date,
        activeSeconds: TimeInterval?
    ) -> Int? {
        let legacy = legacySeconds(start: start, end: end)
        guard storedSeconds == legacy, storedMinutes == legacy / 60 else { return nil }
        let corrected = seconds(start: start, end: end, activeSeconds: activeSeconds)
        return corrected == storedSeconds ? nil : corrected
    }
}
