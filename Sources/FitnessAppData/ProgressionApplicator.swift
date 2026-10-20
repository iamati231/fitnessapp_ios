#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// DEL-052 + DEL-053: Wendet den `ProgressionEvaluator` auf eine
/// abgeschlossene `WorkoutSession` an. Pro Plan-Uebung in der Session:
///
///   1. Logs filtern auf DIESE Uebung
///   2. In `ProgressionInputSet` projizieren (RIR + reps)
///   3. Evaluator-Action holen
///   4. Bei `.increaseWeight` / `.deload` das `Exercise.suggestedWeight`
///      aktualisieren — naechstes Mal startet der User mit dem neuen Ziel.
///   5. UI-Layer bekommt eine Liste `[ProgressionOutcome]` zurueck fuer
///      die Celebration in WorkoutSummary.
///
/// Wird aus `ActiveWorkoutView.finishWorkout()` aufgerufen, NACH dem
/// PR-Sync. Pure side-effects: schreibt Felder, ruft NICHT `save()` — der
/// modelContext-autosave handled das.
public enum ProgressionApplicator {

    /// Resultat pro Uebung — wird vom UI fuer die Celebration-Liste benutzt.
    public struct ProgressionOutcome: Sendable, Identifiable {
        public let id: UUID
        public let exerciseName: String
        public let action: ProgressionAction
        /// Neues Ziel-Gewicht NACH Anwendung der Action (= Wert, der jetzt
        /// in `Exercise.suggestedWeight` steht). Nil wenn die Uebung kein
        /// Gewicht trackt (Cardio / TimeBased) — dann ist die Progression
        /// rein informational.
        public let newSuggestedWeight: Double?

        public init(exerciseName: String, action: ProgressionAction, newSuggestedWeight: Double?) {
            self.id = UUID()
            self.exerciseName = exerciseName
            self.action = action
            self.newSuggestedWeight = newSuggestedWeight
        }
    }

    /// Wendet die Progression-Logik auf alle Plan-Uebungen der `session.day`
    /// an. Returns `[ProgressionOutcome]` fuer UI-Render, gefiltert auf
    /// `.increaseWeight` und `.deload` — `.hold` wird ueberschlagen (nichts
    /// zu feiern, kein Toast).
    ///
    /// DEL-057: liest `session.sessionFeeling` und veto'd jede
    /// `.increaseWeight`-Action zu `.hold`, wenn der User das Workout als
    /// "sehr schwer" oder "zerstoert" markiert hat (Erschoepfungs-Schutz).
    @discardableResult
    public static func apply(
        to session: WorkoutSession,
        in context: ModelContext
    ) -> [ProgressionOutcome] {
        guard let day = session.day else { return [] }
        // `activeExercises` filtert DEL-049-Archive aus. Cardio + TimeBased
        // werden im Inner-Loop noch mal explizit gechecked.
        let exercises = day.activeExercises

        // DEL-057: Session-Feeling-Veto vorab abfragen, damit wir es im
        // Loop nicht jedes Mal neu auswerten.
        let feelingVetoActive: Bool = {
            guard let raw = session.sessionFeeling,
                  let feeling = SessionFeeling(rawValue: raw)
            else { return false }
            return feeling.vetoesProgression
        }()

        var outcomes: [ProgressionOutcome] = []

        for exercise in exercises {
            // Opt-In Toggle pro Uebung — DEL-052 Akzeptanzkriterium 1.
            guard exercise.smartProgressionEnabled else { continue }
            // Cardio + TimeBased: kein Gewichts-Tracking. Skip.
            guard !exercise.isCardio, !exercise.isTimeBased else { continue }
            // DEL-087: Warmup + Cooldown haben semantisch keinen Progressions-
            // Reiz — sie sind Vorbereitung bzw. Recovery, nicht Hypertrophie.
            guard !exercise.role.skipsProgression else { continue }

            // Saetze dieser Uebung aus der Session-Liste filtern. Snapshot-
            // first (DEL-051) damit auch nullify'd-Logs gefasst werden —
            // sollte hier aber irrelevant sein, da die Session frisch ist.
            let exerciseLogs = session.logs.filter { log in
                if log.exercise?.persistentModelID == exercise.persistentModelID {
                    return true
                }
                // Fallback fuer den theoretischen Fall, dass der Backref
                // mid-session genullt wurde: Snapshot-Name vergleichen.
                return log.resolvedExerciseName == exercise.name
            }
            guard !exerciseLogs.isEmpty else { continue }

            // In ProgressionInputSet projizieren.
            let inputSets = exerciseLogs.map { log in
                ProgressionInputSet(
                    setIndex: log.setIndex,
                    reps: log.reps,
                    rir: log.rir
                )
            }

            // User-Override vom Plan ziehen (kann nil sein → Default).
            let override = exercise.day?.plan?.progressionTargetRIROverride

            var action = ProgressionEvaluator.evaluate(
                loggedSets: inputSets,
                targetRepsRange: exercise.repsMin...max(exercise.repsMin, exercise.repsMax),
                targetSetCount: exercise.sets,
                isCompound: exercise.isCompound,
                incrementStep: exercise.progressionStep,
                targetRIROverride: override
            )

            // DEL-057 Erschoepfungs-Veto. Deload bleibt erlaubt (Sicherheits-
            // Netz), nur `.increaseWeight` wird zu `.hold` umgebogen.
            if feelingVetoActive, case .increaseWeight = action {
                action = .hold
            }

            // F08-Fund (Dok. 03 §5: "nicht dieselbe Uebung gleichzeitig
            // steigern und reduzieren"): waehrend `DeloadManager` ein
            // reduziertes Gewicht fuer diese Uebung eingefroren haelt
            // (`deloadOriginalWeight != nil`), darf Progression es nicht
            // ueberschreiben — sonst wird der Deload sofort unterlaufen UND
            // `endDeload()` wuerde den waehrenddessen erarbeiteten
            // Fortschritt beim Zurueckschreiben des alten Originals wieder
            // verwerfen. Deload selbst bleibt erlaubt (Sicherheitsnetz).
            if exercise.deloadOriginalWeight != nil, case .increaseWeight = action {
                action = .hold
            }

            // Auswirkungen auf das suggestedWeight schreiben.
            let baseWeight = exercise.suggestedWeight ?? lastLoggedWeight(in: exerciseLogs)
            var newWeight: Double? = exercise.suggestedWeight
            switch action {
            case .increaseWeight(let by):
                let updated = (baseWeight ?? 0) + by
                exercise.suggestedWeight = updated
                newWeight = updated
            case .deload(let by):
                // Defensive: kein negatives Gewicht; minimum auf step-size
                // halten (Bodyweight-Uebungen koennen suggestedWeight nil
                // lassen — die landen aber gar nicht hier, weil weight==0
                // ist und der Algorithmus den catastrophic-Fall durch das
                // Rep-Limit auswertet).
                let updated = max(0, (baseWeight ?? 0) - by)
                exercise.suggestedWeight = updated
                newWeight = updated
            case .hold:
                // Kein Schreibvorgang.
                break
            }

            // Hold-Outcomes sammeln wir nicht — sie generieren kein UI.
            if case .hold = action { continue }
            outcomes.append(
                ProgressionOutcome(
                    exerciseName: exercise.name,
                    action: action,
                    newSuggestedWeight: newWeight
                )
            )
        }

        return outcomes
    }

    /// Read-only Variante fuer WorkoutSummary-Replay. Gleicher Algorithmus
    /// wie `apply`, aber OHNE Mutation der `Exercise.suggestedWeight`. UI
    /// nutzt das, um die Celebration auch beim Wiederoeffnen einer frisch
    /// abgeschlossenen Session korrekt zu rendern, ohne den Wert ein
    /// zweites Mal weiterzuschieben.
    public static func evaluateOnly(
        for session: WorkoutSession
    ) -> [ProgressionOutcome] {
        guard let day = session.day else { return [] }
        let feelingVetoActive: Bool = {
            guard let raw = session.sessionFeeling,
                  let feeling = SessionFeeling(rawValue: raw)
            else { return false }
            return feeling.vetoesProgression
        }()
        var outcomes: [ProgressionOutcome] = []
        for exercise in day.activeExercises {
            guard exercise.smartProgressionEnabled,
                  !exercise.isCardio, !exercise.isTimeBased
            else { continue }
            let exerciseLogs = session.logs.filter { log in
                if log.exercise?.persistentModelID == exercise.persistentModelID {
                    return true
                }
                return log.resolvedExerciseName == exercise.name
            }
            guard !exerciseLogs.isEmpty else { continue }
            let inputSets = exerciseLogs.map {
                ProgressionInputSet(setIndex: $0.setIndex, reps: $0.reps, rir: $0.rir)
            }
            let override = exercise.day?.plan?.progressionTargetRIROverride
            var action = ProgressionEvaluator.evaluate(
                loggedSets: inputSets,
                targetRepsRange: exercise.repsMin...max(exercise.repsMin, exercise.repsMax),
                targetSetCount: exercise.sets,
                isCompound: exercise.isCompound,
                incrementStep: exercise.progressionStep,
                targetRIROverride: override
            )
            if feelingVetoActive, case .increaseWeight = action {
                action = .hold
            }
            // Spiegelt denselben Deload-Veto wie `apply` (siehe dessen
            // Dokumentation) — sonst wuerde dieses Replay eine Steigerung
            // feiern, die `apply` tatsaechlich nie geschrieben hat.
            if exercise.deloadOriginalWeight != nil, case .increaseWeight = action {
                action = .hold
            }
            if case .hold = action { continue }
            outcomes.append(
                ProgressionOutcome(
                    exerciseName: exercise.name,
                    action: action,
                    newSuggestedWeight: exercise.suggestedWeight
                )
            )
        }
        return outcomes
    }

    /// Wenn `suggestedWeight` nicht gesetzt war, nehmen wir das hoechste
    /// Gewicht aus den geloggten Saetzen als Basis fuer die +/- step-
    /// Rechnung. So funktioniert die Progression auch beim allerersten
    /// Logging einer neuen Uebung.
    private static func lastLoggedWeight(in logs: [ExerciseLog]) -> Double? {
        logs.map(\.weight).max()
    }
}
#endif
