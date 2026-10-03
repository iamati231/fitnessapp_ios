#if canImport(SwiftData)
import Foundation
import FitnessAppCore

// Beginn, Ende und Dauer einer Session setzen. Die Regel, ob die Wanduhr
// glaubwuerdig ist, lebt in `FitnessAppCore.SessionDurationEstimator` und ist
// dort ohne SwiftData getestet; hier steht nur die Anbindung an die Logs.

public extension WorkoutSession {

    /// Eingaben fuer `SessionDurationEstimator`: nur echt geloggte Saetze (keine
    /// Platzhalter-Zeilen), mit der Pause der jeweiligen Uebung.
    var durationLogInputs: [SessionDurationEstimator.LogInput] {
        loggedSets.map { log in
            SessionDurationEstimator.LogInput(
                isCardio: log.resolvedIsCardio,
                durationSeconds: log.durationSeconds,
                restSeconds: log.exercise?.restSeconds
            )
        }
    }

    /// Beenden einer Session: setzt Ende und Dauer.
    ///
    /// Lief das Training live mit, ist die Dauer die Wanduhr zwischen Start und
    /// Beenden (wie bisher). Wurde es NACHGETRAGEN — ein Lauf, den man erst nach
    /// dem Laufen einträgt, hat zwischen Start und Beenden eine Minute —, gilt die
    /// eingetragene Cardio-Zeit; Krafttraining bekommt eine Schaetzung aus der
    /// Satzzahl. In dem Fall wird auch der BEGINN zurueckgesetzt, sodass das
    /// Training mit dem Beenden aufhoert: Ende, Beginn und Dauer passen zusammen
    /// (Health-Export, Abgleich mit Importen und "in der Zukunft"-Pruefung
    /// brauchen genau das), und das Training liegt dort, wo es vermutlich lief —
    /// kurz vor dem Eintragen. `durationMinutes` ist wie ueberall abgerundet
    /// (25:56 sind 25 Min); der Beginn liegt auf die SEKUNDE genau (Ende minus 25:56),
    /// damit der Health-Eintrag die genaue Zeit bekommt.
    @discardableResult
    func finalizeTiming(endingAt end: Date) -> SessionDurationEstimate {
        let wallClockSeconds = max(0, Int(end.timeIntervalSince(startTime)))
        let estimate = SessionDurationEstimator.estimate(
            wallClockSeconds: wallClockSeconds,
            logs: durationLogInputs
        )
        endTime = end
        durationMinutes = estimate.minutes
        if estimate.isCorrected {
            startTime = end.addingTimeInterval(-Double(estimate.seconds))
        }
        return estimate
    }

    /// Bestehende, abgeschlossene Session: hebt eine kuerzere gespeicherte Dauer
    /// auf die eingetragene Cardio-Zeit an (nur der sichere Fall, siehe
    /// `SessionDurationEstimator.repairedMinutes`). Beginn und Ende bleiben
    /// unveraendert — wie nach einer Dauer-Aenderung im Verlauf.
    /// - Returns: `true`, wenn die Dauer geaendert wurde.
    @discardableResult
    func repairShortDuration() -> Bool {
        guard let minutes = SessionDurationEstimator.repairedMinutes(
            storedMinutes: durationMinutes,
            logs: durationLogInputs
        ) else { return false }
        durationMinutes = minutes
        return true
    }
}
#endif
