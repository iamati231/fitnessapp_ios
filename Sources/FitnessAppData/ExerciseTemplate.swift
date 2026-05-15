#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Exercise definition — system-seeded canonical lifts plus user-custom entries.
/// Backs the Exercise Library and the "swap exercise" flow.
@Model
public final class ExerciseTemplate {
    public var name: String
    public var equipment: Equipment
    public var primaryMuscle: MuscleGroup
    public var isCustom: Bool
    public var difficultyLevel: DifficultyLevel
    /// True for the 5 canonical compound barbell lifts. Used by `CompoundLiftChart`
    /// to find logs via a flag-based join rather than a locale-dependent name (F137).
    public var isSystemCompound: Bool
    /// True for isometric/time-based exercises — reps records seconds held (F161).
    public var isTimeBased: Bool

    /// DEL-080: True fuer Cardio-Lifts. Wird vom DayEditor beim Picker-Pick
    /// auf `Exercise.isCardio` propagiert — sodass Ad-Hoc-Cardio-Einheiten
    /// (z.B. "Freier Lauf" am Ende eines Strength-Tags) automatisch korrekt
    /// klassifiziert sind. Default false → bestehende Library-Eintraege
    /// (Strength) bleiben unangetastet.
    public var isCardio: Bool = false

    public init(
        name: String,
        equipment: Equipment,
        primaryMuscle: MuscleGroup,
        isCustom: Bool = false,
        difficultyLevel: DifficultyLevel = .intermediate,
        isSystemCompound: Bool = false,
        isTimeBased: Bool = false,
        isCardio: Bool = false
    ) {
        self.name = name
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.isCustom = isCustom
        self.difficultyLevel = difficultyLevel
        self.isSystemCompound = isSystemCompound
        self.isTimeBased = isTimeBased
        self.isCardio = isCardio
    }
}
#endif
