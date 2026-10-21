#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Smart-Onboarding-Epic: Bestandsnutzer haben kein `OnboardingProfile` und
/// damit keine explizite Antwort auf die Trainingshistorie-Frage. Statt sie
/// pauschal auf `.experienced` zu setzen UND es dabei zu belassen, nähert
/// dieser einmalige Backfill den Track aus der vorhandenen Trainingshistorie
/// an (`ExperienceTrackResolver.trackFromHistory`, dieselbe Lücken-Schwelle
/// wie `ComebackAdvisor`).
///
/// Idempotent — Predicate filtert auf `experienceTrackRaw == nil`, läuft
/// also nach dem ersten Erfolg leer durch. Überschreibt NIE einen bereits
/// gesetzten Wert (weder einen früheren Backfill-Lauf noch eine später vom
/// echten Onboarding-Flow gesetzte, explizite Antwort).
public enum ExperienceTrackBackfill {

    @MainActor
    public static func runIfNeeded(in context: ModelContext) {
        let predicate = #Predicate<UserBodyProfile> { $0.experienceTrackRaw == nil }
        guard let profiles = try? context.fetch(FetchDescriptor(predicate: predicate)),
              !profiles.isEmpty else { return }

        let sessions = allRealSessions(in: context)
        let strengthSessions = sessions
            .filter(\.containsStrengthWork)
            .sorted { $0.endTime < $1.endTime }

        let gapDays: Int? = strengthSessions.last.map { last in
            Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: last.endTime),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? 0
        }

        let track = ExperienceTrackResolver.trackFromHistory(
            gapDaysSinceLastStrengthSession: gapDays,
            priorStrengthSessionCount: strengthSessions.count
        )

        for profile in profiles {
            profile.experienceTrack = track
        }
    }

    /// Gleiche Definition von "echte Session" wie `AbsenceDeload`.
    private static func allRealSessions(in context: ModelContext) -> [WorkoutSession] {
        let all = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return all.filter { $0.isCompleted && !$0.isRestDay }
    }
}
#endif
