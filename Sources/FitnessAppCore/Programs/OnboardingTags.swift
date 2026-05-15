import Foundation

/// DEL-090: Tags fuer den Onboarding-Quiz-Matchmaker. Plan-Templates tragen
/// `targetExperience: [ExperienceLevel]` + `targetGoals: [GoalType]` — der
/// `PlanMatchmaker` ranked die Plaene gegen die User-Antworten ueber ein
/// einfaches Punkte-System (Match = +Punkte, Mismatch ignoriert).
///
/// Die Enums sind public + RawRepresentable damit sie spaeter ohne
/// Schema-Migration in SwiftData persistiert werden koennen (z.B. fuer
/// einen "deine letzte Quiz-Auswahl"-Restore-Pfad).

public enum ExperienceLevel: String, Sendable, Codable, CaseIterable, Hashable {
    case beginner
    case intermediate
    case advanced

    public var label: String {
        switch self {
        case .beginner:     return "Anfänger"
        case .intermediate: return "Fortgeschritten"
        case .advanced:     return "Experte"
        }
    }

    public var symbol: String {
        switch self {
        case .beginner:     return "leaf.fill"
        case .intermediate: return "bolt.fill"
        case .advanced:     return "flame.fill"
        }
    }
}

public enum GoalType: String, Sendable, Codable, CaseIterable, Hashable {
    case hypertrophy
    case strength
    case fatloss
    case hybrid
    case functional

    public var label: String {
        switch self {
        case .hypertrophy: return "Muskeln aufbauen"
        case .strength:    return "Maximalkraft"
        case .fatloss:     return "Fett verbrennen"
        case .hybrid:      return "Athletisch werden"
        case .functional:  return "Funktionelle Fitness"
        }
    }

    public var symbol: String {
        switch self {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength:    return "scalemass.fill"
        case .fatloss:     return "flame.fill"
        case .hybrid:      return "figure.mixed.cardio"
        case .functional:  return "figure.cooldown"
        }
    }
}
