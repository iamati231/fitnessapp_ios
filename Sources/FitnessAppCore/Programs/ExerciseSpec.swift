import Foundation

/// Pure-data spec for one planned exercise inside a `ProgramTemplate`. Used to seed
/// `Exercise` rows when a user picks a template from the library.
///
/// Lives in Core (no SwiftData dependency) so the templates are testable on every
/// platform — only `ProgramInstantiator` (in `FitnessAppData`) materializes them
/// into actual `Exercise` @Model rows.
public struct ExerciseSpec: Sendable, Hashable {
    public let name: String
    public let sets: Int
    public let repsMin: Int
    public let repsMax: Int
    public let restSeconds: Int
    public let targetRir: Float
    /// True for cardio finishers — UI shows duration/level fields instead of kg/reps.
    public let isCardio: Bool

    /// DEL-058: Ziel-Distanz fuer Cardio-Lifts (z.B. 5.0 km Easy Run). Nil
    /// fuer Strength + Time-Based. UI nutzt das als Placeholder im
    /// CardioSetRow-Distanz-Feld.
    public let targetDistanceKm: Double?

    /// DEL-058: Ziel-Dauer in Minuten. Bei Cardio-Lifts ohne fixe Distanz
    /// (z.B. "30 Min Easy Run") setzt der Plan diesen Wert; UI nutzt ihn
    /// als Placeholder im Dauer-Feld.
    public let targetDurationMinutes: Int?

    /// Laufcoaching-Plan-Integration (Task 3): einmalig zum Erzeugungszeitpunkt
    /// aus `PlanGeneratorTypeSelection.cardioRunProfile` berechnete Ziel-Pace
    /// fuer `.easy`/`.tempo`-Lauf-Zonen (siehe `PlanGenerator.cardioCandidates`).
    /// Nil wenn keine Baseline bekannt war, oder fuer jeden anderen Lift
    /// (`.interval` bleibt distanzbasiert, Kraft/Rad unveraendert). Keine
    /// gespeicherte "Wahrheit" - Anzeige-Code leitet die Pace bei Bedarf live
    /// neu her, wenn eine frischere Baseline existiert (siehe Task 9).
    public let targetPaceMinutesPerKm: Double?

    /// DEL-087: Rolle des Lifts im Workout. Default `.workingSet`. Warmup
    /// und Cooldown werden vom Progressions-Algorithmus geskippt.
    public let role: ExerciseRole

    /// Paket 2 (Sportart-Unterscheidung): nur fuer `isCardio == true`
    /// relevant, nur `.running`/`.cycling` gueltig. `nil` = nicht festgelegt
    /// - siehe `TrainingDay.enduranceSportKind`-Doku (niemals aus `name`
    /// zurueckgeraten).
    public let enduranceSportKind: TrainingTypeKind?

    public init(
        name: String,
        sets: Int,
        repsMin: Int,
        repsMax: Int,
        restSeconds: Int = 90,
        targetRir: Float = 2.0,
        isCardio: Bool = false,
        targetDistanceKm: Double? = nil,
        targetDurationMinutes: Int? = nil,
        targetPaceMinutesPerKm: Double? = nil,
        role: ExerciseRole = .workingSet,
        enduranceSportKind: TrainingTypeKind? = nil
    ) {
        self.name = name
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
        self.targetRir = targetRir
        self.isCardio = isCardio
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMinutes = targetDurationMinutes
        self.targetPaceMinutesPerKm = targetPaceMinutesPerKm
        self.role = role
        self.enduranceSportKind = enduranceSportKind
    }
}
