#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Einmalige Reparatur nachgetragener Laeufe: Wer einen Lauf erst nach dem
/// Laufen eintrug, hat dafuer eine Dauer von ein, zwei Minuten gespeichert (die
/// Wanduhr zwischen Start und Beenden), obwohl der Lauf 26 Minuten dauerte. Die
/// Dauer wird auf die eingetragene Cardio-Zeit angehoben.
///
/// Bewusst eng gefasst:
/// - nur der sichere Fall (gespeicherte Dauer kuerzer als die eingetragene Cardio-
///   Zeit, siehe `SessionDurationEstimator.repairedMinutes`) — Kraft wird bei
///   bestehenden Daten nicht geschaetzt;
/// - nur die Dauer: Beginn und Ende bleiben, damit Schluessel und Sortierung
///   unveraendert sind;
/// - keine importierten Einheiten (deren Dauer stammt aus Health) und keine
///   Zeitformate;
/// - EINMAL: Ein Schluessel merkt sich den Lauf, damit eine spaetere manuelle
///   Dauer im Verlauf nicht wieder ueberschrieben wird. Schlaegt das Laden fehl,
///   wird der Schluessel nicht gesetzt (naechster Start versucht es erneut).
@MainActor
public enum SessionDurationRepair {

    static let doneKey = "migration_session_duration_repair_v1"

    /// - Returns: Anzahl der angepassten Sessions.
    @discardableResult
    public static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) -> Int {
        guard !defaults.bool(forKey: doneKey) else { return 0 }

        // Wie im Export-Service nur das einfache Bool-Predicate; alles andere
        // entscheidet der Code im Speicher.
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false }
        )
        guard let sessions = try? context.fetch(descriptor) else { return 0 }

        var repaired = 0
        for session in sessions {
            guard session.importSourceName == nil,
                  session.healthKitSampleUUID == nil,
                  session.timeFormatSnapshot == nil
            else { continue }
            if session.repairShortDuration() { repaired += 1 }
        }
        if repaired > 0 { try? context.save() }
        defaults.set(true, forKey: doneKey)
        return repaired
    }
}
#endif
