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

    /// Equipment types available in this environment.
    public var allowedEquipment: [Equipment] {
        switch self {
        case .gym:         return Equipment.allCases
        case .homeGym:     return [.barbell, .dumbbell, .bodyweight, .kettlebell, .band]
        case .noEquipment: return [.bodyweight, .band]
        }
    }

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
