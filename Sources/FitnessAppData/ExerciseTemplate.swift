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

    // MARK: - DEL-098 Training-Intelligence-Metadaten
    //
    // Statische Belastungsfaktoren, die vom `LibrarySeeder` aus dem
    // `ExerciseTemplateSpec` propagiert und beim DayEditor-Picker-Pick
    // (`Exercise(from: template)`) auf die Plan-Uebung weitergereicht
    // werden. Defaults entsprechen "moderate Isolationsuebung" — damit
    // Lightweight-Migration der pre-DEL-098-Templates sinnvolle Startwerte
    // erhaelt, statt durchgaengig 0 zu liefern.
    public var systemicFatigueFactor: Double = 0.35
    public var localMuscleDamageFactor: Double = 0.35
    public var cnsDemandFactor: Double = 0.25
    public var axialLoadFactor: Double = 0.20
    public var technicalComplexityFactor: Double = 0.30
    /// Persistiert als String (rawValue), damit Lightweight-Migration auf
    /// pre-DEL-098-Daten funktioniert. Convenience-Accessor via `recoveryClass`.
    public var recoveryClassRaw: String = ExerciseRecoveryClass.medium.rawValue

    public var recoveryClass: ExerciseRecoveryClass {
        get { ExerciseRecoveryClass(rawValue: recoveryClassRaw) ?? .medium }
        set { recoveryClassRaw = newValue.rawValue }
    }

    public init(
        name: String,
        equipment: Equipment,
        primaryMuscle: MuscleGroup,
        isCustom: Bool = false,
        difficultyLevel: DifficultyLevel = .intermediate,
        isSystemCompound: Bool = false,
        isTimeBased: Bool = false,
        isCardio: Bool = false,
        systemicFatigueFactor: Double = 0.35,
        localMuscleDamageFactor: Double = 0.35,
        cnsDemandFactor: Double = 0.25,
        axialLoadFactor: Double = 0.20,
        technicalComplexityFactor: Double = 0.30,
        recoveryClass: ExerciseRecoveryClass = .medium
    ) {
        self.name = name
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.isCustom = isCustom
        self.difficultyLevel = difficultyLevel
        self.isSystemCompound = isSystemCompound
        self.isTimeBased = isTimeBased
        self.isCardio = isCardio
        self.systemicFatigueFactor = systemicFatigueFactor
        self.localMuscleDamageFactor = localMuscleDamageFactor
        self.cnsDemandFactor = cnsDemandFactor
        self.axialLoadFactor = axialLoadFactor
        self.technicalComplexityFactor = technicalComplexityFactor
        self.recoveryClassRaw = recoveryClass.rawValue
    }
}
#endif
