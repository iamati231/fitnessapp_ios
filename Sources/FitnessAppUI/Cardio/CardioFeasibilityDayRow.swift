#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Eine Zeile der Wochen-Vorschau in den drei Machbarkeits-Check-Karten
/// (Profil/Dashboard/Plan-Tab). Bewusst schlanker als
/// `PlanBuilderView.resultDayRow`: der hier gerechnete Mix ist immer nur
/// Laufen (eine Cardio-Uebung, Zeitziel) oder Koerpergewicht-Kraft (mehrere
/// Uebungen, kein Zeitformat) - AMRAP/EMOM/Auf-Zeit kommen aus dem Generator
/// fuer diesen Mix nie vor, die volle `scopeLine`-Fallunterscheidung braucht
/// es hier nicht.
struct CardioFeasibilityDayRow: View {
    let day: PlanGenerator.Result.GeneratedDay

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.spec.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            Spacer(minLength: 8)
            Text(day.loadLevel.localizedName)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(day.loadLevel.displayColor.opacity(0.16))
                .foregroundStyle(day.loadLevel.displayColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        // Bugfix (Review): vorher wurde die Cardio-Erkennung an
        // `targetDurationMinutes` festgemacht - Intervalle
        // (`PlanGenerator.RunZone.interval`) tragen aber `targetDistanceKm`
        // statt einer Dauer und fielen dadurch auf "Krafttraining" zurueck,
        // obwohl der Titel bereits "Intervalle" zeigt.
        guard day.spec.exercises.count == 1, let exercise = day.spec.exercises.first, exercise.isCardio else {
            return String(localized: "cardioFeasibility.day.strength", bundle: .module)
        }
        if let minutes = exercise.targetDurationMinutes {
            let runText = String(format: String(localized: "cardioFeasibility.day.run", bundle: .module), minutes)
            // Task 9: Pace kommt aus einer `CardioRunProfile`-Referenzzeit
            // (Task 3) und existiert deshalb nicht immer - ein
            // qualitativer Hinweis statt `PaceCalculator.formatPace(nil)`s
            // "—:—— /km" (das ist ein Platzhalter fuer ein LEERES
            // Eingabefeld, keine fertige Anzeige-Zeile).
            if let pace = exercise.targetPaceMinutesPerKm {
                return "\(runText) · \(PaceCalculator.formatPace(pace))"
            }
            return "\(runText) · \(String(localized: "cardioFeasibility.day.paceUnknown", bundle: .module))"
        }
        if let distanceKm = exercise.targetDistanceKm {
            return String(
                format: String(localized: "cardioFeasibility.day.interval", bundle: .module),
                exercise.sets, distanceKm.formattedOneDecimal
            )
        }
        return String(localized: "cardioFeasibility.day.runFallback", bundle: .module)
    }
}
#endif
