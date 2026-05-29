import Foundation

/// DEL-090: Antworten aus dem Onboarding-Quiz, die der `PlanMatchmaker`
/// gegen die `ProgramTemplate`-Library scort.
public struct QuizAnswers: Sendable, Equatable {
    public let goal: GoalType
    public let experience: ExperienceLevel
    public let preferredDays: Int          // 2–6 typischerweise
    public let environment: EnvironmentType
    /// DEL-170: Vom User gepflegte Equipment-Präferenzen. Leeres Set = nicht
    /// gepflegt → der Matcher wendet keinen zusätzlichen Equipment-Filter an
    /// (Backward-Compat-Pfad für pre-DEL-170-Profile).
    public let equipmentPreferences: Set<Equipment>

    public init(
        goal: GoalType,
        experience: ExperienceLevel,
        preferredDays: Int,
        environment: EnvironmentType,
        equipmentPreferences: Set<Equipment> = []
    ) {
        self.goal = goal
        self.experience = experience
        self.preferredDays = preferredDays
        self.environment = environment
        self.equipmentPreferences = equipmentPreferences
    }
}

/// DEL-090: Pure-Logik-Scorer. Filtert Templates ueber K.O.-Kriterien
/// (Environment + maxDays) und ranked den Rest ueber ein einfaches
/// Punkte-System (Goal-Match = +3, Experience-Match = +2, exakte Day-Count =
/// +1). Lebt in Core, damit der Algorithmus auf Windows-CI getestbar bleibt.
public enum PlanMatchmaker {

    /// Gefiltertes + sortiertes Ergebnis. Die `[ProgramTemplate]` ist
    /// absteigend nach Score sortiert — `first` ist die Top-Empfehlung.
    /// Bei Score-Gleichstand bleibt die ursprueengliche Display-Reihenfolge
    /// aus `ProgramTemplates.all` erhalten (Stable-Sort).
    public static func rankPlans(
        for answers: QuizAnswers,
        templates: [ProgramTemplate]
    ) -> [ProgramTemplate] {
        // 1) K.O.-Kriterien (Hard Filters).
        let eligible = templates.filter { template in
            envMatches(plan: template.targetEnvironment, user: answers.environment)
                && template.daysPerWeek <= answers.preferredDays
                && equipmentMatches(template: template, user: answers.equipmentPreferences)
        }

        // Wenn alles raus-gefiltert wurde, fallback auf BW-/Anfaenger-Pfad.
        if eligible.isEmpty {
            return fallback(for: answers, allTemplates: templates)
        }

        // 2) Scoring (Soft Filters). Stable-Sort: gleiche Scores behalten
        //    die ursprueengliche Reihenfolge.
        let scored = eligible.enumerated().map { (index, plan) -> (plan: ProgramTemplate, score: Int, origin: Int) in
            var score = 0
            if plan.targetGoals.contains(answers.goal)            { score += 3 }
            if plan.targetExperience.contains(answers.experience) { score += 2 }
            if plan.daysPerWeek == answers.preferredDays          { score += 1 }
            return (plan: plan, score: score, origin: index)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.origin < rhs.origin
            }
            .map { $0.plan }
    }

    /// DEL-170: Hard-Filter für Equipment. Templates ohne `equipmentVariants`
    /// haben keine Equipment-spezifische Anforderung (Backward-Compat).
    /// Templates MIT Variants müssen vom User abgedeckt sein — entweder über
    /// die implizite Basis-Variante (`template.days`, Konvention: barbellGym)
    /// ODER mindestens eine der gelisteten `equipmentVariants`. Leeres
    /// User-Preference-Set wird als "nicht gepflegt" interpretiert und passiert
    /// den Filter (Onboarding-Skip / pre-DEL-170-Bestand).
    private static func equipmentMatches(template: ProgramTemplate, user: Set<Equipment>) -> Bool {
        guard !user.isEmpty else { return true }
        guard let variants = template.equipmentVariants else { return true }
        let baseRequires = EquipmentProfile.barbellGym.requiredEquipment
        if baseRequires.isSubset(of: user) { return true }
        return variants.contains { $0.profile.requiredEquipment.isSubset(of: user) }
    }

    /// Hard-Filter-Logik fuer das Environment:
    ///   * User `.gym` → akzeptiert alle Templates (Gym hat alles)
    ///   * User `.homeGym` → akzeptiert `.homeGym` UND `.noEquipment`
    ///   * User `.noEquipment` → akzeptiert nur `.noEquipment`
    private static func envMatches(plan: EnvironmentType, user: EnvironmentType) -> Bool {
        switch user {
        case .gym:         return true
        case .homeGym:     return plan == .homeGym || plan == .noEquipment
        case .noEquipment: return plan == .noEquipment
        }
    }

    /// Wenn die K.O.-Kriterien ALLES rausfiltern (extrem strenge Auswahl
    /// wie "Powerlifting + No-Equipment + 2 Tage"), liefern wir wenigstens
    /// die "harmlosen" Bodyweight-Plaene zurueck statt einer leeren Liste.
    /// Verhindert dass der Quiz-Result-Screen leer dasteht.
    private static func fallback(
        for answers: QuizAnswers,
        allTemplates: [ProgramTemplate]
    ) -> [ProgramTemplate] {
        // Bodyweight-Plaene laufen ueberall, daher sicherer Fallback.
        return allTemplates.filter { $0.targetEnvironment == .noEquipment }
    }
}
