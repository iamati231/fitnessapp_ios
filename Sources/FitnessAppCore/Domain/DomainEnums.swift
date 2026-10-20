import Foundation

/// Equipment categories used to classify exercises and filter the library.
public enum Equipment: String, Codable, Sendable, CaseIterable {
    case barbell
    case dumbbell
    case bodyweight
    case machine
    case cable
    case kettlebell
    /// Resistance bands — typical for home/bodyweight training (F154).
    case band
}

/// DEL-155: Equipment-Auswahl speziell fuer Cardio-Uebungen. Beschreibt das
/// GERAET, mit dem eine Cardio-Einheit ausgefuehrt wurde — orthogonal zum
/// Strength-`Equipment`. Relevant fuer die PR-/Trend-Trennung (ein
/// Laufband-Lauf ist eine andere Modalitaet als eine Fahrradfahrt) und im
/// Verlauf pro Cardio-Uebung editierbar.
///
/// `.none` = kein/ohne Geraet (z.B. Lauf draussen ohne weitere Zuordnung).
/// Wird als String-RawValue persistiert (SwiftData-Lightweight-Migration +
/// stabile Identitaet fuer Gruppierungs-Keys).
public enum CardioEquipment: String, Codable, Sendable, CaseIterable {
    case none
    case treadmill
    case bikeOutdoor
    case ergometer
    case rowingMachine
}

/// Where the user trains. Drives plan recommendations and the equipment filter
/// for the "swap exercise" feature. Hierarchy: gym ⊇ homeGym ⊇ noEquipment.
public enum EnvironmentType: String, Codable, Sendable, CaseIterable {
    case gym
    case homeGym
    case noEquipment

    // DEL-242: `allowedEquipment` entfernt. Es hatte repo-weit genau eine
    // Referenz — die eigene Deklaration — UND war inhaltlich die abweichende
    // von drei Fassungen derselben Regel: nur hier war `.barbell` im Home-Gym
    // erlaubt. Die beiden LEBENDEN Fassungen (`ExerciseLibraryData.isEquipment`
    // und `OnboardingView.defaultEquipment(for:)`) fuehren die Langhantel dort
    // nicht. Bewusst nicht "wieder verdrahtet", sondern gestrichen: die
    // Wahrheit steht schon zweimal woanders.
    //
    // Enum und Cases bleiben unangetastet — die RawValues sind persistiert
    // (UserBodyProfile.environment, TrainingPlan.targetEnvironment) und
    // CSV-Spalten.

    /// True when a user training in `self` can physically execute a plan
    /// designed for `planEnv`. Mirrors Android's `canExecutePlan`.
    public func canExecute(planEnvironment planEnv: EnvironmentType) -> Bool {
        switch self {
        case .gym:         return true
        case .homeGym:     return planEnv == .homeGym || planEnv == .noEquipment
        case .noEquipment: return planEnv == .noEquipment
        }
    }
}

public enum MuscleGroup: String, Codable, Sendable, CaseIterable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case quads
    case hamstrings
    case glutes
    case calves
    case core
}

public enum DayType: String, Codable, Sendable, CaseIterable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case push
    case pull
    case upper
    case lower
    case fullBody
    case rest
    case custom
    /// DEL-055: Dedizierte Run-/Cardio-Tage fuer Hybrid-Plaene. Trainingstag
    /// (nicht rest), aber Inhalt ist eine zeitbasierte Cardio-Einheit —
    /// kein Strength-Logging, vom Progressions-Algorithmus uebersprungen.
    case cardio
}

public enum DayIntensity: String, Codable, Sendable, CaseIterable {
    case normal
    case light
    case heavy
}

/// Zeitformat eines Trainingstags — orthogonal zu `DayType` (das beschreibt
/// den Muskelfokus, nicht die Struktur). `nil` auf `TrainingDay.timeFormat`
/// ist der bisherige Normalfall: ganz gewöhnliches Satz/Wiederholungs-
/// Krafttraining, ungeaendertes Verhalten. Ein gesetzter Case bedeutet,
/// dass `ActiveWorkoutView` statt der gepagten Uebungs-Navigation den
/// `TimedWorkoutPlayerView` fuer dieses Format rendert.
///
/// String-RawValue, damit SwiftData-Lightweight-Migration + CSV-Export
/// (siehe `DataExportService`) stabile, lesbare Werte persistieren —
/// gleiches Muster wie `CardioEquipment`/`EnvironmentType`.
public enum WorkoutTimeFormat: String, Codable, Sendable, CaseIterable {
    /// As Many Rounds/Reps As Possible in `timeCapMinutes`.
    case amrap
    /// Every Minute On the Minute — eine Uebung pro 60s-Intervall,
    /// wiederholt ueber `timeCapMinutes`.
    case emom
    /// Vorgegebenes Pensum so schnell wie moeglich; `timeCapMinutes`
    /// optional als Abbruch-Deckel.
    case forTime
    /// Nutzer-Feedback (Kettlebell-Komplexe): feste Rundenzahl
    /// (`TrainingDay.circuitRounds`), zwischen den Runden eine feste,
    /// konfigurierbare Pause (`circuitRestSeconds`). Anders als AMRAP/EMOM
    /// keine gemeinsame Uhr fuer den ganzen Tag — jede Runde endet einzeln,
    /// je nach `circuitMode` entweder automatisch (alle Uebungs-Ziele der
    /// Runde abgehakt) oder manuell ("Runde beenden"-Knopf bei einer
    /// Ausbelastungs-Runde ohne festes Wiederholungsziel).
    case circuit
    /// Paket 2 (Laufcoach-Konzept, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
    /// Einlaufen (`enduranceWarmupDurationSeconds`) -> N Runden
    /// Belastung/Erholung (`enduranceIntervalRounds`,
    /// `enduranceWorkDurationSeconds`/`enduranceWorkDistanceKm` fuer die
    /// Belastung, `enduranceRestDurationSeconds` fuer die Erholung) ->
    /// Auslaufen (`enduranceCooldownDurationSeconds`). Fuer Laufen/
    /// Radfahren, nicht fuer Kraft-Komplexe (dafuer bleibt `.circuit`
    /// zustaendig). Analog zu `.circuit`s Zwei-Phasen-Modell, aber BEIDE
    /// Phasen (Belastung UND Erholung) sind hier gezeitet/streckenbasiert
    /// statt einer ungezeiteten Arbeitsphase.
    case enduranceIntervals
}

/// Nur relevant, wenn `TrainingDay.timeFormat == .circuit` — legt fest, wie
/// eine einzelne Runde als "fertig" erkannt wird.
public enum CircuitRoundMode: String, Codable, Sendable, CaseIterable {
    /// Runde endet automatisch, sobald alle Uebungen ihr Wiederholungsziel
    /// erreicht haben (Checkbox-UI wie bei Auf-Zeit, aber pro Runde
    /// zurueckgesetzt statt kumulativ ueber die ganze Session).
    case fixedReps
    /// Runde endet erst, wenn der User selbst "Runde beenden" antippt -
    /// fuer Vorgaben wie "wiederholen, bis keine saubere Wiederholung mehr
    /// moeglich ist".
    case toFailure
}

/// Vorschlagswert fuer die Rundenzahl eines neu angelegten Zirkel-Tages,
/// solange `circuitRounds` noch `nil` ist. In Core statt in FitnessAppUI,
/// weil sowohl `DayAnalyzer` (FitnessAppData) als auch `DayEditorView`/
/// `DashboardView` (FitnessAppUI) denselben Vorschlag brauchen.
public func defaultCircuitRounds() -> Int { 5 }

/// Vorschlagswert fuer die Pause zwischen zwei Runden in Sekunden, solange
/// `circuitRestSeconds` noch `nil` ist - 90s ist der Wert, den jeder
/// Kettlebell-Komplex aus der Nutzer-Vorlage durchgehend verwendet.
public func defaultCircuitRestSeconds() -> Int { 90 }

/// Difficulty classification for exercise templates — used by the library filter (F99).
public enum DifficultyLevel: String, Codable, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

/// DEL-087: Welche Rolle hat dieser Satz im Workout-Flow?
///   * `.warmup` — Aufwaerm-Satz vor den Working-Sets. UI rendert in grau,
///     keine Progression, kein RIR, kein Volumen-Eintrag.
///   * `.workingSet` — Standard-Arbeitssatz. Default-Wert.
///   * `.cooldown` — Abwaerm-/Mobility-Satz nach dem Workout. Selbe
///     UI-Behandlung wie Warmup, semantisch aber "Cool-Down".
public enum ExerciseRole: String, Codable, Sendable, CaseIterable {
    case warmup
    case workingSet
    case cooldown

    /// True wenn dieser Lift vom Progressions-Algorithmus geskippt werden
    /// soll — Warmup + Cooldown sind kein Hypertrophie-Reiz und sollten
    /// keine `.increaseWeight`-Actions triggern.
    public var skipsProgression: Bool {
        switch self {
        case .warmup, .cooldown: return true
        case .workingSet:        return false
        }
    }
}
