import Foundation

/// DEL-090: Tag fuer den Onboarding-Quiz-Matchmaker. Plan-Templates tragen
/// `targetExperience: [ExperienceLevel]` + `targetGoals: [TrainingGoal]` —
/// der `PlanMatchmaker` ranked die Plaene gegen die User-Antworten ueber ein
/// einfaches Punkte-System (Match = +Punkte, Mismatch ignoriert).
///
/// Smart-Onboarding-Epic: das frühere zweite Tag-Enum `GoalType` (eigene,
/// nie persistierte Quiz-Achse) wurde entfernt und in `TrainingGoal`
/// (`FitnessAppCore/Coaching/CoachingTypes.swift`, DEL-100, persistiert auf
/// `UserBodyProfile.trainingGoalRaw`) konsolidiert — es gibt jetzt nur noch
/// EIN Ziel-Enum für Quiz-Matching UND Coaching. Der ehemalige verlustbehaftete
/// Brücken-Mapper `OnboardingView.mappedQuizGoal` entfällt dadurch.
///
/// `ExperienceLevel` bleibt bewusst unverändert und getrennt vom neuen
/// `ExperienceTrack` (siehe `ExperienceTrack.swift`): hier geht es um
/// selbst eingeschätzte Technik-/Trainingserfahrung für das Plan-Matching,
/// dort um eine aus Verhalten/Pausenlänge hergeleitete Coaching-Achse
/// (Einstieg/Wiedereinstieg/volle Automatik).
///
/// Das Enum ist public + RawRepresentable damit es spaeter ohne
/// Schema-Migration in SwiftData persistiert werden koennte (z.B. fuer
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
