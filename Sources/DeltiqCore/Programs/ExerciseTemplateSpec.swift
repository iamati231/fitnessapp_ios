import Foundation

/// Movement pattern for an exercise. Used in baseline substitution to prevent
/// cross-category replacements (e.g. Hyperextension returned for Klimmzüge).
/// nil = not annotated; substitution uses primaryMuscle match only.
/// Only back exercises are currently annotated because that is the only muscle
/// group with meaningfully different patterns in the same primaryMuscle bucket.
public enum MovementPattern: String, Sendable, Codable, Hashable, CaseIterable {
    case verticalPull    // pull-ups, lat pulldowns
    case horizontalPull  // rows (barbell, dumbbell, cable, bodyweight)
    case spinalExtension // hyperextension, good morning
    case hipHinge        // deadlifts (axial spinal load from hip hinging)
    case carry           // farmer's walk, suitcase carry
}

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

    /// Issue #29: Sportart fuer Cardio-Uebungen (Laufen vs. Radfahren).
    /// Nil fuer mehrdeutige Geraete (Crosstrainer, Stepper). Wird vom
    /// LibrarySeeder und DayEditor auf Exercise propagiert, damit
    /// spontane Trainings dieselbe Klassifizierung erhalten wie
    /// plan-generierte.
    public let enduranceSportKind: TrainingTypeKind?

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

    /// Smart-Onboarding-Epic Phase 2 (PLAN_EQUIPMENT_MATCHING_AUDIT.md
    /// Abschnitt 4): feingranulare AND/OR/Anzahl-Voraussetzung fuer DIESE
    /// konkrete Variante, zusaetzlich zum groben `equipment`-Feld oben
    /// (das bleibt unveraendert die Pro-Uebung-Klassifikation). `nil` =
    /// noch nicht erfasst — KEIN Hinweis auf "keine Voraussetzung",
    /// sondern "fuer dieses Katalog-Phase noch nicht modelliert" (nur ein
    /// kleiner, explizit verifizierter Teil der 229 Uebungen traegt diese
    /// Struktur bereits; die vollstaendige Katalog-Erfassung ist ein
    /// separater, spaeterer Schritt — Audit Abschnitt 9).
    public let equipmentRequirement: ExerciseRequirement?

    /// Issue #51: minimum baseline band required for this exercise. `nil` = no
    /// restriction (accessible to all). Used by PlanGenerator to skip gated
    /// exercises (e.g. standard push-ups) for users who scored veryLow.
    public let baselineMinBand: BaselineBand?

    /// Movement pattern used for substitution category matching. See `MovementPattern`.
    public let movementPattern: MovementPattern?

    /// Issue #51 R3: nur eine Handvoll Uebungen tragen ein explizites
    /// `baselineMinBand` — alle anderen liefen bislang UNGEFILTERT durch
    /// jede Baseline-Pruefung, auch objektiv anspruchsvolle
    /// (`difficultyLevel: .advanced`, z.B. Kreuzheben/Pistol Squat/Muscle-Up).
    /// Leitet fuer die restlichen Uebungen einen konservativen Mindest-Band
    /// aus dem ohnehin fuer JEDE Uebung gepflegten `difficultyLevel` her,
    /// statt eine nie vollstaendige manuelle Annotation jeder einzelnen
    /// Uebung zu verlangen. Ein explizites `baselineMinBand` hat weiterhin
    /// Vorrang (gezielt von Hand kalibriert, praeziser als diese grobe
    /// Herleitung).
    ///
    /// Bewusst NUR zwei Stufen (`.beginner` → kein Gate, alles andere →
    /// `.low`), nicht fein nach `.intermediate`/`.advanced` gestaffelt: eine
    /// `.advanced`-Stufe, die `.moderate` verlangt, haette unter
    /// `BaselineBands.conservative` (push/legs/pull/core alle `.low` — der
    /// Default fuer uebersprungene Tests) ploetzlich auch fuer diesen bisher
    /// unauffaelligen Pfad gegriffen (`.low` erfuellt `.moderate` nicht) und
    /// damit potenziell ganze Tage ohne jede explizite Annotation leeren
    /// koennen — nicht risikofrei pruefbar ueber alle 20 Templates ohne
    /// lokalen Build/Test (siehe PR-Beschreibung). `.low` als Schranke
    /// aendert am `.conservative`-Pfad NICHTS (`.low` erfuellt `.low`), haelt
    /// aber `veryLow`-getestete Nutzer (das eigentliche Problem: "besonders
    /// anspruchsvolle Uebungen duerfen nicht ungeprueft im Anfaengerplan
    /// landen") weiterhin fern von jeder nicht als `.beginner` eingestuften
    /// Uebung.
    public var effectiveBaselineMinBand: BaselineBand? {
        if let baselineMinBand { return baselineMinBand }
        return difficultyLevel == .beginner ? nil : .low
    }

    public init(
        name: String,
        equipment: Equipment,
        primaryMuscle: MuscleGroup,
        difficultyLevel: DifficultyLevel = .intermediate,
        isSystemCompound: Bool = false,
        isTimeBased: Bool = false,
        isCardio: Bool = false,
        enduranceSportKind: TrainingTypeKind? = nil,
        // DEL-098: defensive Defaults (moderate Isolationsuebung). Library-
        // Eintraege koennen jeden Faktor pro Eintrag ueberschreiben.
        systemicFatigueFactor: Double = 0.35,
        localMuscleDamageFactor: Double = 0.35,
        cnsDemandFactor: Double = 0.25,
        axialLoadFactor: Double = 0.20,
        technicalComplexityFactor: Double = 0.30,
        recoveryClass: ExerciseRecoveryClass = .medium,
        localizationKey: String? = nil,
        equipmentRequirement: ExerciseRequirement? = nil,
        baselineMinBand: BaselineBand? = nil,
        movementPattern: MovementPattern? = nil
    ) {
        // Modul-2-Audit (P2, dormant): `.unknown` ist nur als Nutzer-Zustand
        // sinnvoll (Test uebersprungen). Als REQUIRED-Seite wuerde es die
        // Uebung fuer JEDEN Nutzer unerreichbar machen (`BaselineBand.
        // meetsMinimum` erfuellt `.unknown` fuer niemanden, nicht mal fuer
        // `.unknown` selbst). Katalog-Daten duerfen das nie setzen.
        assert(baselineMinBand != .unknown,
               "'\(name)': baselineMinBand must never be .unknown — that would make this exercise unreachable for every user")
        self.name = name
        self.equipment = equipment
        self.primaryMuscle = primaryMuscle
        self.difficultyLevel = difficultyLevel
        self.isSystemCompound = isSystemCompound
        self.isTimeBased = isTimeBased
        self.isCardio = isCardio
        self.enduranceSportKind = enduranceSportKind
        self.systemicFatigueFactor = systemicFatigueFactor
        self.localMuscleDamageFactor = localMuscleDamageFactor
        self.cnsDemandFactor = cnsDemandFactor
        self.axialLoadFactor = axialLoadFactor
        self.technicalComplexityFactor = technicalComplexityFactor
        self.recoveryClass = recoveryClass
        self.localizationKey = localizationKey
        self.equipmentRequirement = equipmentRequirement
        self.baselineMinBand = baselineMinBand
        self.movementPattern = movementPattern
    }
}
