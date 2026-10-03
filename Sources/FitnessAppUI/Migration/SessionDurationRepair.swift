#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Reparatur der Dauer bestehender Laeufe: Wer einen Lauf erst nach dem Laufen
/// eintrug, hat dafuer eine Dauer von ein, zwei Minuten gespeichert (die Wanduhr
/// zwischen Start und Beenden), obwohl der Lauf 26 Minuten dauerte; ein Lauf, bei
/// dem das Training vorher gestartet oder offen gelassen wurde, eine zu lange. Die
/// Dauer wird auf die eingetragene Cardio-Zeit gesetzt.
///
/// Bewusst eng gefasst:
/// - ein einzelner Lauf (genau ein Cardio-Satz mit Zeit) in beide Richtungen,
///   mehrere Cardio-Saetze nur, wenn die Dauer kuerzer als ihre Summe ist (siehe
///   `SessionDurationEstimator.repairedMinutes`) — Kraft wird bei bestehenden
///   Daten nicht geschaetzt;
/// - nur die Dauer: Beginn und Ende bleiben, damit Schluessel und Sortierung
///   unveraendert sind;
/// - keine importierten Einheiten (deren Dauer stammt aus Health) und keine
///   Zeitformate.
///
/// Zwei Einstiege:
/// - `runIfNeeded`: EINMAL beim Start. Ein Schluessel merkt sich den Lauf, damit
///   eine spaetere manuelle Dauer im Verlauf nicht wieder ueberschrieben wird.
///   Schlaegt das Laden fehl, wird der Schluessel nicht gesetzt (der naechste
///   Start versucht es erneut).
/// - `repairAfterImport`: nach einem CSV-Import oder Backup-Restore, unabhaengig
///   vom Schluessel — sonst blieben Laeufe aus einer Sicherung, die vor dem
///   Update entstand (oder auf einem frisch installierten Geraet importiert
///   wird), dauerhaft bei der falschen Dauer.
///
/// Nicht an einen Actor gebunden: Der Aufrufer ruft mit dem Kontext auf, auf dem
/// er ohnehin arbeitet (wie bei `DataImportService.performImport`).
public enum SessionDurationRepair {

    /// v2: Ein einzelner Lauf gilt jetzt auch bei zu langer Dauer und abgerundet
    /// (v1 hob nur an und rundete auf); der neue Schluessel laesst die Reparatur
    /// fuer Geraete, auf denen v1 schon lief, noch einmal laufen.
    static let doneKey = "migration_session_duration_repair_v2"

    /// - Returns: Anzahl der angepassten Sessions.
    @discardableResult
    public static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) -> Int {
        guard !defaults.bool(forKey: doneKey) else { return 0 }
        guard let repaired = repairAll(in: context) else { return 0 }
        defaults.set(true, forKey: doneKey)
        return repaired
    }

    /// - Returns: Anzahl der angepassten Sessions.
    @discardableResult
    public static func repairAfterImport(in context: ModelContext) -> Int {
        repairAll(in: context) ?? 0
    }

    /// `nil`, wenn die Sessions nicht geladen werden konnten.
    private static func repairAll(in context: ModelContext) -> Int? {
        // Wie im Export-Service nur das einfache Bool-Predicate; alles andere
        // entscheidet der Code im Speicher.
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false }
        )
        guard let sessions = try? context.fetch(descriptor) else { return nil }

        var repaired = 0
        for session in sessions {
            guard session.importSourceName == nil,
                  session.healthKitSampleUUID == nil,
                  session.timeFormatSnapshot == nil
            else { continue }
            if session.repairDuration() { repaired += 1 }
        }
        if repaired > 0 { try? context.save() }
        return repaired
    }
}
#endif
