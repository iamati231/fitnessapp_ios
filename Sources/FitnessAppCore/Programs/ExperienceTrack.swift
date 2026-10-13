import Foundation

/// Smart-Onboarding-Epic: verhaltens-/pausenbasierte Trainingshistorie-Achse.
///
/// **Separat von `ExperienceLevel`** (`OnboardingTags.swift`, Selbstauskunft
/// zur Technik-Erfahrung fuer das Quiz-/Template-Matching). `ExperienceTrack`
/// beschreibt stattdessen, WIE die App gerade coacht (Einstieg/Wiedereinstieg/
/// volle Automatik) — hergeleitet aus Trainingsverhalten und Pausenlaenge,
/// nicht aus einer Selbsteinschaetzung der Technik. Ein Nutzer kann z.B.
/// `.advanced` (ExperienceLevel, kennt die Technik) UND `.returner`
/// (ExperienceTrack, hat gerade eine lange Pause) gleichzeitig sein.
///
/// Bewusst nicht "Level" im Namen: es gibt mit `ExperienceLevel` (Technik)
/// und `DifficultyLevel` (Uebungsschwierigkeit, `DomainEnums.swift`) bereits
/// zwei "Level"-Konzepte — ein drittes, aehnlich benanntes Enum wuerde sie
/// leicht verwechselbar machen.
///
/// `ExperienceTrack` ist nicht fix: ein Starter, der ueber Wochen sauber
/// abliefert, kann spaeter auf `.experienced` vorgeschlagen werden (Epic
/// §3) — diese Re-Evaluation ist aber nicht Teil dieser Datenmodell-Phase.
public enum ExperienceTrack: String, Sendable, Codable, CaseIterable, Hashable {
    /// Noch nie oder < 3 Monate regelmaessig trainiert.
    case starter
    /// Frueher trainiert, aktuell eine laengere Pause (>= 6 Wochen).
    case returner
    /// Trainiert aktuell regelmaessig, kennt die Technik.
    case experienced

    /// Fix "doppeltes Onboarding": seit der Quiz-Entfernung ist dies die
    /// EINZIGE Quelle fuer `PlanMatchmaker`/`QuizAnswers.experience` — es
    /// gibt keine separate Selbsteinschaetzungs-Frage mehr (das waere
    /// genau die redundante zweite Frage, die das Epic vermeiden will).
    ///
    /// Starter UND Returner werden bewusst GLEICH behandelt (beide ->
    /// `.beginner`): ein Wiedereinsteiger braucht dieselbe konservative
    /// Technik-Fuehrung wie ein echter Anfaenger, auch wenn `ComebackAdvisor`
    /// seine Last separat ueber die Pausenlaenge dosiert. `.experienced`
    /// mappt auf `.intermediate`, nicht `.advanced` — "trainiert gerade
    /// regelmaessig" ist keine Aussage ueber Elite-Technik, und
    /// `.intermediate`-Templates sind fuer diese Gruppe die sicherere
    /// Standard-Annahme als `.advanced`-exklusive Programme.
    public var asExperienceLevel: ExperienceLevel {
        switch self {
        case .starter, .returner: return .beginner
        case .experienced: return .intermediate
        }
    }
}

/// Epic §4.3, Hauptfrage zur Trainingshistorie (vier Antworten, verhaltens-
/// statt etikettenbasiert — "Kompetenz vor Etikett").
public enum TrainingHistoryAnswer: String, Sendable, Codable, CaseIterable, Hashable {
    /// "Ich habe noch nie regelmäßig trainiert"
    case neverTrained
    /// "Ich habe schon trainiert, aber vor langer Pause (> 3 Monate)"
    case longBreakAfterTraining
    /// "Ich trainiere gerade unregelmäßig"
    case trainingIrregularly
    /// "Ich trainiere regelmäßig (>= 3 Monate, mind. 2x/Woche)"
    case trainingRegularly

    /// SF-Symbol fuers Onboarding — analog zu `TrainingGoal.symbol`/
    /// `ExperienceLevel.symbol` in Core definiert, lokalisierte Texte dazu
    /// leben wie dort in `FitnessAppUI/DomainEnums+Localization.swift`.
    public var symbol: String {
        switch self {
        case .neverTrained:          return "leaf.fill"
        case .longBreakAfterTraining: return "arrow.triangle.2.circlepath"
        case .trainingIrregularly:   return "shuffle"
        case .trainingRegularly:     return "bolt.fill"
        }
    }
}

/// Epic §4.3, Folgefrage A — nur bei `.longBreakAfterTraining`: wie lang die
/// aktuelle Pause ist. Kalibriert spaeter die Laenge der Wiedereinstiegs-
/// Rampe (Epic §5.3, `RampPlanner` — nicht Teil dieser Phase); NICHT zu
/// verwechseln mit der Lastreduktion, die `ComebackAdvisor.prescription(
/// forGapDays:)` anhand der tatsaechlichen Tageszahl berechnet.
public enum PauseLength: String, Sendable, Codable, CaseIterable, Hashable {
    case sixToTwelveWeeks
    case threeToTwelveMonths
    case overOneYear
}

/// Epic §4.3, Folgefrage B — nur bei `.trainingIrregularly`: seit wann
/// ueberhaupt trainiert wird. Unterscheidet "noch keine 3 Monate am Stueck
/// geschafft, also eigentlich Starter" von "jahrelange Erfahrung, nur
/// gerade unregelmaessig" (eher `.experienced`).
public enum PriorExperienceDuration: String, Sendable, Codable, CaseIterable, Hashable {
    case underOneYear
    case oneToThreeYears
    case overThreeYears
}

/// Reine, testbare Herleitung von `ExperienceTrack` — einmal aus einer
/// expliziten Onboarding-Antwort, einmal (fuer Bestandsnutzer ohne eine
/// solche Antwort) aus der vorhandenen Trainingshistorie.
public enum ExperienceTrackResolver {

    /// Herleitung aus der Onboarding-Quiz-Antwort (Epic §4.3).
    ///
    /// - Parameter priorExperience: nur bei `.trainingIrregularly` relevant;
    ///   wird sonst ignoriert.
    public static func track(
        for answer: TrainingHistoryAnswer,
        priorExperience: PriorExperienceDuration? = nil
    ) -> ExperienceTrack {
        switch answer {
        case .neverTrained:
            return .starter
        case .longBreakAfterTraining:
            return .returner
        case .trainingRegularly:
            return .experienced
        case .trainingIrregularly:
            // Ohne mehrjaehrige Vorerfahrung wie einen Starter behandeln:
            // Konsistenz ist hier das eigentliche Problem, nicht Technik.
            switch priorExperience {
            case .oneToThreeYears, .overThreeYears:
                return .experienced
            case .underOneYear, nil:
                return .starter
            }
        }
    }

    /// Fuer Bestandsnutzer OHNE Onboarding-Profil-Antwort: Naeherung aus dem
    /// Trainingsverlauf statt einer blinden Pauschale. Nutzt dieselbe
    /// Luecken-Schwelle wie `ComebackAdvisor` (`minimumGapDays`), damit beide
    /// Systeme konsistent urteilen — wer hier als `.returner` eingestuft
    /// wird, bekommt auch von `ComebackAdvisor` eine Lastreduktion
    /// vorgeschlagen.
    ///
    /// Liefert NIE `.starter`: ein Bestandsnutzer hat per Definition
    /// irgendeine Historie und soll nicht in einen Einsteiger-Plan
    /// gezwungen werden, nur weil diese Historie kurz ist.
    ///
    /// - Parameters:
    ///   - gapDaysSinceLastStrengthSession: Tage seit der letzten Session
    ///     mit Kraftanteil, `nil` wenn es nie eine gab.
    ///   - priorStrengthSessionCount: Kraft-Sessions in der GESAMTEN
    ///     Historie.
    public static func trackFromHistory(
        gapDaysSinceLastStrengthSession: Int?,
        priorStrengthSessionCount: Int
    ) -> ExperienceTrack {
        guard priorStrengthSessionCount >= ComebackAdvisor.minimumPriorStrengthSessions,
              let gapDays = gapDaysSinceLastStrengthSession else {
            return .experienced
        }
        return gapDays >= ComebackAdvisor.minimumGapDays ? .returner : .experienced
    }
}
