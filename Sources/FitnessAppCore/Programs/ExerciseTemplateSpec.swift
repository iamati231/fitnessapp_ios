import Foundation

/// Pure-data spec for one exercise in the seed library. `LibrarySeeder` converts
/// these into `ExerciseTemplate` @Model rows on first app launch. Duplicating the
/// fields rather than referencing the @Model directly keeps Core SwiftData-free
/// (so library data is testable on Windows / Linux / iOS without divergence).
public struct ExerciseTemplateSpec: Sendable, Hashable {
    public let name: String
    public let equipment: Equipment
    public let primaryMuscle: MuscleGroup
    public let difficultyLevel: DifficultyLevel
    /// True for the canonical compound barbell lifts (Squat, Bench, Deadlift, OHP, Row).
    public let isSystemCompound: Bool
    /// True for isometric / time-based exercises — repsMin/repsMax then carry seconds.
    public let isTimeBased: Bool

    /// DEL-080: True fuer Cardio-Lifts (Lauf, Bike, Rudermaschine, Stepper).
    /// Wird beim Picker-Pick auf `Exercise.isCardio` propagiert, sodass der
    /// User auch Ad-Hoc / "freies Training" eine Cardio-Einheit einfach
    /// dazupacken kann.
    public let isCardio: Bool

    public init(
        name: String,
        equipment: Equipment,
        primaryMuscle: MuscleGroup,
        difficultyLevel: DifficultyLevel = .intermediate,
        isSystemCompound: Bool = false,
        isTimeBased: Bool = false,
        isCardio: Bool = false
    ) {
        self.name = name
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.difficultyLevel = difficultyLevel
        self.isSystemCompound = isSystemCompound
        self.isTimeBased = isTimeBased
        self.isCardio = isCardio
    }
}
