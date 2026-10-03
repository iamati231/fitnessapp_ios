#if canImport(SwiftData)
import Foundation
import SwiftData

/// Der lokale Marker "schon nach Apple Health gesendet"
/// (`WorkoutSession.healthKitExportedAt`): zaehlen und zuruecksetzen.
///
/// Der Marker ist nur ein lokales Gedaechtnis. Loescht der Nutzer die Eintraege in
/// Health (z.B. "Alle Daten von Deltiq loeschen" in der Health-App), erfaehrt
/// Deltiq davon nichts: Jede markierte Session gilt weiter als erledigt, der
/// Export fruehere Trainings meldet "Nichts zu exportieren" und waere eine
/// Sackgasse. `reset` ist der ausdrueckliche Ausweg: Danach gleicht der naechste
/// Export alle Sessions neu mit Health ab — was dort noch steht, wird nicht
/// doppelt geschrieben, was fehlt, wird neu gesendet.
public enum HealthExportMarker {

    /// Sessions, die als "gesendet" gelten: abgeschlossene Trainings mit Marker.
    /// Ruhetage und aus Health importierte Sessions zaehlen nicht — sie werden nie
    /// nach Health geschrieben (`HealthWorkoutPlanner` ueberspringt sie vor dem
    /// Marker).
    public static func markedSessions(in context: ModelContext) -> [WorkoutSession] {
        // Bewusst nur das einfache Bool-Predicate wie im Export-Service; alles
        // andere entscheidet der Code im Speicher (Predicates auf Optionals sind
        // unter iOS 17 fehleranfaellig).
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true && $0.isRestDay == false }
        )
        guard let sessions = try? context.fetch(descriptor) else { return [] }
        return sessions.filter {
            $0.healthKitExportedAt != nil
                && $0.importSourceName == nil
                && $0.healthKitSampleUUID == nil
        }
    }

    public static func markedCount(in context: ModelContext) -> Int {
        markedSessions(in: context).count
    }

    /// Entfernt den Marker aller markierten Sessions und speichert.
    /// - Returns: Anzahl der zurueckgesetzten Sessions.
    @discardableResult
    public static func reset(in context: ModelContext) -> Int {
        let sessions = markedSessions(in: context)
        guard !sessions.isEmpty else { return 0 }
        for session in sessions {
            session.healthKitExportedAt = nil
        }
        try? context.save()
        return sessions.count
    }
}
#endif
