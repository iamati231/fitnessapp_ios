#if canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore

/// AI-Running-Coach Phase 2, Work Package 2A: SwiftData-Glue zwischen
/// echten `WorkoutSession`/`ExerciseLog`-Objekten und dem reinen
/// `TrainingLoadAggregator` (DeltiqCore).
///
/// **Keine redundante Klassifikation** (Ticket Teil 5): die Cardio-/
/// Laufsport-Klassifikation kommt unveraendert aus `CardioHistoryExtractor.
/// loggedSessions` (Phase 1, hier nur aufgerufen, nie neu geschrieben). Nur
/// die Krafttrainings-Kennzahlen (hier nirgends sonst verfuegbar) werden
/// zusaetzlich berechnet - mit der bereits bestehenden, kanonischen Formel
/// `SessionAggregator.totals` (identisch zu der, die `WorkoutSession.
/// recomputeTotals()` fuer `totalSets`/`totalVolumeKg` benutzt), angewandt
/// NUR auf den Kraft-Anteil der Session (`loggedSets.filter { !$0.
/// resolvedIsCardio }`) - `session.totalVolumeKg`/`totalSets` selbst werden
/// bewusst NICHT direkt verwendet: sie zaehlen Cardio-"Saetze" (ein Lauf-Log
/// ist ebenfalls ein "Satz" im Sinne von DEL-223) in `totalSets` mit, waeren
/// also fuer eine reine Krafttrainings-Satzzahl verfaelscht.
public enum TrainingActivityExtractor {

    /// Baut die vereinheitlichte Aktivitaetsliste aus den tatsaechlichen
    /// `WorkoutSession`s eines Profils. Eine Aktivitaet pro echter Session
    /// (`isRealWorkout`) - identische Granularitaet wie `CardioHistoryExtractor`,
    /// damit sich Lauf- und Kraftanteil derselben Session nie in zwei
    /// getrennten Eintraegen auseinanderdividieren und so zu einer
    /// doppelten Woche-Zuordnung fuehren koennten.
    public static func extract(from sessions: [WorkoutSession]) -> [TrainingActivity] {
        let realSessions = sessions.filter(\.isRealWorkout)
        // `CardioHistoryExtractor.loggedSessions` filtert intern identisch
        // auf `isRealWorkout` und erhaelt dabei die Eingabe-Reihenfolge -
        // beide Listen sind daher Position-fuer-Position dieselbe Session.
        let cardioSessions = CardioHistoryExtractor.loggedSessions(from: sessions)

        return zip(realSessions, cardioSessions).map { session, cardio in
            let strengthSets = session.loggedSets
                .filter { !$0.resolvedIsCardio }
                .map { SessionAggregator.LoggedSet(weightKg: $0.weight, reps: $0.reps) }
            let strengthTotals = SessionAggregator.totals(for: strengthSets)

            return TrainingActivity(
                date: cardio.date,
                runningDistanceKm: cardio.runningDistanceKm,
                runningDurationSeconds: cardio.runningDurationSeconds,
                isRunning: cardio.isRunning,
                isCrossTrainingOnly: cardio.isCrossTrainingOnly,
                hasAmbiguousCardio: cardio.hasAmbiguousCardio,
                hasStrengthActivity: session.containsStrengthWork,
                strengthSetCount: strengthTotals.setCount,
                strengthVolumeKg: strengthTotals.volumeKg
            )
        }
    }
}
#endif
