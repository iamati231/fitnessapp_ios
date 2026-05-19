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

    // MARK: - DEL-098 Training-Intelligence-Metadaten
    //
    // Statische Pro-Uebung-Belastungsfaktoren. Werden in `LibrarySeeder` auf
    // den persistierten `ExerciseTemplate` propagiert und dann beim Picker-
    // Pick auf die `Exercise` im Plan. Die laufzeitliche Score-Berechnung
    // (siehe DEL-099 + `ExerciseScoring` in Core) multipliziert sie mit
    // Satz-Daten (RIR, reps, weight, duration).
    //
    // Wertebereich konzeptionell 0.0 ... 1.0, harte Caps macht der Scorer
    // nicht — sehr hohe Faktoren bedeuten einfach groessere Recovery-Last.
    // Defaults entsprechen einer "moderaten Isolationsuebung", sodass Library-
    // Eintraege ohne explizite Annotation NICHT bei 0 landen.

    /// Wie stark belastet die Uebung das Gesamtsystem (Atmung, Kreislauf,
    /// HRV)? Beispiele: Kreuzheben 0.95, Bizeps-Curl 0.15.
    public let systemicFatigueFactor: Double

    /// Wie stark ist lokale muskulaere Erholung betroffen? Korreliert grob
    /// mit dem zu erwartenden DOMS-Volumen — Wall Sit hat hohen lokalen
    /// Score (Quads brennen), aber moderaten systemic.
    public let localMuscleDamageFactor: Double

    /// Wie "neuronal schwer" ist die Uebung? Hohe Werte fuer schwere
    /// Compounds und Olympic-Lifts; niedrige Werte fuer Maschinen-Isolation.
    public let cnsDemandFactor: Double

    /// Axiale Belastung — relevant fuer Wirbelsaeulen-/Ganzkoerperlast.
    /// Kreuzheben 1.00, freistehende Hantel-Squats 0.95, Maschinen-Curls 0.00.
    public let axialLoadFactor: Double

    /// Koordinative Komplexitaet. Olympic Snatch 0.95, Maschinen-Leg-Extension
    /// 0.05.
    public let technicalComplexityFactor: Double

    /// Grobe Einordnung fuer Quick-Decisions im UI. Default `.medium`.
    public let recoveryClass: ExerciseRecoveryClass

    /// DEL-111: i18n-Lookup-Key fuer den Display-Namen. Optional —
    /// nur fuer kanonische Lifts gesetzt, fuer die wir Multi-Locale-
    /// Uebersetzungen pflegen (siehe `exercise.name.*` im Catalog).
    /// Wird vom `LibrarySeeder` 1:1 auf das `ExerciseTemplate`
    /// propagiert.
    public let localizationKey: String?

    public init(
        name: String,
        equipment: Equipment,
        primaryMuscle: MuscleGroup,
        difficultyLevel: DifficultyLevel = .intermediate,
        isSystemCompound: Bool = false,
        isTimeBased: Bool = false,
        isCardio: Bool = false,
        // DEL-098: defensive Defaults (moderate Isolationsuebung). Library-
        // Eintraege koennen jeden Faktor pro Eintrag ueberschreiben.
        systemicFatigueFactor: Double = 0.35,
        localMuscleDamageFactor: Double = 0.35,
        cnsDemandFactor: Double = 0.25,
        axialLoadFactor: Double = 0.20,
        technicalComplexityFactor: Double = 0.30,
        recoveryClass: ExerciseRecoveryClass = .medium,
        localizationKey: String? = nil
    ) {
        self.name = name
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.difficultyLevel = difficultyLevel
        self.isSystemCompound = isSystemCompound
        self.isTimeBased = isTimeBased
        self.isCardio = isCardio
        self.systemicFatigueFactor = systemicFatigueFactor
        self.localMuscleDamageFactor = localMuscleDamageFactor
        self.cnsDemandFactor = cnsDemandFactor
        self.axialLoadFactor = axialLoadFactor
        self.technicalComplexityFactor = technicalComplexityFactor
        self.recoveryClass = recoveryClass
        self.localizationKey = localizationKey
    }
}
