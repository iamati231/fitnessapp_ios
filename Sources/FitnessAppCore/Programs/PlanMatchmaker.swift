import Foundation

/// DEL-090: Antworten aus dem Onboarding-Quiz, die der `PlanMatchmaker`
/// gegen die `ProgramTemplate`-Library scort.
public struct QuizAnswers: Sendable, Equatable {
    /// Smart-Onboarding-Epic: vormals `GoalType` — auf `TrainingGoal`
    /// konsolidiert (siehe `ProgramTemplate.targetGoals`).
    public let goal: TrainingGoal
    public let experience: ExperienceLevel
    public let preferredDays: Int          // 2–6 typischerweise
    public let environment: EnvironmentType
    /// DEL-170: Vom User gepflegte Equipment-Präferenzen. Leeres Set = nicht
    /// gepflegt → der Matcher wendet keinen zusätzlichen Equipment-Filter an
    /// (Backward-Compat-Pfad für pre-DEL-170-Profile).
    public let equipmentPreferences: Set<Equipment>

    public init(
        goal: TrainingGoal,
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

/// Fix "Badge fast ueberall": die vier unabhaengigen Gruende, aus denen ein
/// Template zu den Onboarding-Antworten passt. Jede UI-Badge rendert genau
/// EIN Feld — nie alle pauschal, nie wenn `false`.
public struct PlanMatchReasons: Sendable, Equatable {
    public let goalMatch: Bool
    public let daysMatch: Bool
    public let levelMatch: Bool
    public let equipmentMatch: Bool
}

/// DEL-090: Pure-Logik-Scorer. Filtert Templates ueber K.O.-Kriterien
/// (Environment + maxDays) und ranked den Rest ueber ein einfaches
/// Punkte-System (Goal-Match = +3, Experience-Match = +2, exakte Day-Count =
/// +1). Lebt in Core, damit der Algorithmus auf Windows-CI getestbar bleibt.
public enum PlanMatchmaker {

    /// UX-Fix "Empfehlung wirkt immer gleich" Punkt 5: `rankPlans` allein
    /// konnte der UI nicht sagen, ob die zurueckgelieferte Liste eine echte
    /// Uebereinstimmung ist oder aus dem Fallback-Pfad (`fallback(...)`,
    /// greift wenn die Hard-Filter ALLES rausgefiltert haben) stammt. Ohne
    /// diese Unterscheidung zeigte das Onboarding auf einer reinen Notloesung
    /// trotzdem "Empfohlen fuer dich" an — die UI soll stattdessen
    /// "Beste verfuegbare Option mit deinen Angaben" zeigen.
    public struct RankedPlanResult: Sendable, Equatable {
        public let templates: [ProgramTemplate]
        public let isFallback: Bool

        public init(templates: [ProgramTemplate], isFallback: Bool) {
            self.templates = templates
            self.isFallback = isFallback
        }
    }

    /// Gefiltertes + sortiertes Ergebnis samt Fallback-Kennzeichnung. Die
    /// `templates`-Liste ist absteigend nach Score sortiert — `first` ist
    /// die Top-Empfehlung. Bei Score-Gleichstand bleibt die urspruengliche
    /// Display-Reihenfolge aus `ProgramTemplates.all` erhalten (Stable-Sort).
    ///
    /// - Parameter experienceTrack: Fix "doppeltes Onboarding" — zusaetzlich
    ///   zum weichen Experience-Score (`answers.experience`, +2) ein harter
    ///   K.O.-Filter fuer Starter/Wiedereinsteiger: reine Expertenplaene
    ///   (kein `.beginner`/`.intermediate` in `targetExperience`) fliegen
    ///   komplett raus, keine Deprioritisierung. Default `nil` erhaelt das
    ///   bisherige Verhalten (alle bestehenden Call-Sites/Tests).
    public static func rankPlansDetailed(
        for answers: QuizAnswers,
        templates: [ProgramTemplate],
        experienceTrack: ExperienceTrack? = nil
    ) -> RankedPlanResult {
        // 1) K.O.-Kriterien (Hard Filters).
        let eligible = templates.filter { template in
            envMatches(plan: template.targetEnvironment, user: answers.environment)
                && template.daysPerWeek <= answers.preferredDays
                && equipmentMatches(template: template, user: answers.equipmentPreferences)
                && experienceTrackMatches(template: template, track: experienceTrack)
        }

        // Wenn alles raus-gefiltert wurde, fallback auf BW-/Anfaenger-Pfad.
        if eligible.isEmpty {
            let fallbackPlans = fallback(for: answers, allTemplates: templates, experienceTrack: experienceTrack)
            return RankedPlanResult(templates: fallbackPlans, isFallback: true)
        }

        // 2) Scoring (Soft Filters). Stable-Sort: gleiche Scores behalten
        //    die ursprueengliche Reihenfolge.
        let scored = eligible.enumerated().map { (index, plan) -> (plan: ProgramTemplate, score: Int, origin: Int) in
            var score = 0
            if plan.targetGoals.contains(answers.goal)            { score += 3 }
            if plan.targetExperience.contains(answers.experience) { score += 2 }
            if plan.daysPerWeek == answers.preferredDays          { score += 1 }
            // UX-Fix "Empfehlung wirkt immer gleich": zusaetzliche, explizit
            // dokumentierte Track-Praeferenz (siehe `ExperienceTrack.
            // templateScoreBonus`) — ohne `experienceTrack` (bestehende
            // Aufrufer, Default `nil`) bleibt das Scoring unveraendert.
            if let experienceTrack {
                score += experienceTrack.templateScoreBonus(template: plan, answers: answers)
            }
            return (plan: plan, score: score, origin: index)
        }

        let ranked = scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.origin < rhs.origin
            }
            .map { $0.plan }
        return RankedPlanResult(templates: ranked, isFallback: false)
    }

    /// Bestehende, einfache Schnittstelle — bleibt fuer alle bisherigen
    /// Aufrufer/Tests unveraendert, liefert nur noch `templates` aus
    /// `rankPlansDetailed(...)` ohne die Fallback-Kennzeichnung.
    public static func rankPlans(
        for answers: QuizAnswers,
        templates: [ProgramTemplate],
        experienceTrack: ExperienceTrack? = nil
    ) -> [ProgramTemplate] {
        rankPlansDetailed(for: answers, templates: templates, experienceTrack: experienceTrack).templates
    }

    /// Fix "Badge fast ueberall": liefert, WARUM ein Template fuer diese
    /// Antworten infrage kommt, statt der bisherigen einzelnen
    /// `targetGoals.contains(goal)`-Pruefung, die bei mehrfach-getaggten
    /// Templates ("Passt zu deinem Ziel" auf fast jedem Plan) nichtssagend
    /// wurde. Die UI zeigt ein Badge NUR, wenn das jeweilige Feld `true` ist
    /// — nie pauschal.
    public static func matchReasons(for template: ProgramTemplate, answers: QuizAnswers) -> PlanMatchReasons {
        PlanMatchReasons(
            goalMatch: template.targetGoals.contains(answers.goal),
            daysMatch: template.daysPerWeek == answers.preferredDays,
            levelMatch: template.targetExperience.contains(answers.experience),
            // Plan-Katalog-Audit, Befund 2: Equipment ist ein harter K.O.-
            // Filter in rankPlans, aber `equipmentMatches` war bis zum Audit
            // fuer Templates ohne `equipmentVariants` ein Blindgaenger (immer
            // `true`) — das Badge pruefte deshalb nur "hat der Nutzer
            // UEBERHAUPT Praeferenzen gepflegt", nie ob DIESES Template
            // tatsaechlich passt. Jetzt dieselbe echte Pruefung wie der
            // Hard-Filter, nur zusaetzlich an "ueberhaupt gepflegt" geknuepft
            // (leeres Set = "nicht gepflegt", kein Badge noetig).
            equipmentMatch: !answers.equipmentPreferences.isEmpty
                && equipmentMatches(template: template, user: answers.equipmentPreferences)
        )
    }

    /// DEL-170 + Plan-Katalog-Audit Befund 1: Hard-Filter fuer Equipment.
    /// Templates MIT `equipmentVariants` pruefen wie bisher (Basis-Variante =
    /// `barbellGym`-Konvention ODER eine der gelisteten Varianten). Templates
    /// OHNE `equipmentVariants` galten bisher als "keine Equipment-
    /// spezifische Anforderung" und liessen JEDEN Nutzer durch — das betraf
    /// 17 von 20 Templates, darunter reine Langhantel-Programme wie
    /// Push-Pull-Legs/Upper-Lower/Arnold-Split/Bro-Split/Powerlifting (siehe
    /// docs/PLAN_CATALOG_AUDIT.md). Fuer diese wird das tatsaechlich
    /// benoetigte Equipment jetzt aus den referenzierten Uebungen hergeleitet.
    /// Leeres User-Preference-Set bleibt "nicht gepflegt" und passiert den
    /// Filter unveraendert.
    private static func equipmentMatches(template: ProgramTemplate, user: Set<Equipment>) -> Bool {
        guard !user.isEmpty else { return true }
        if let variants = template.equipmentVariants {
            let baseRequires = EquipmentProfile.barbellGym.requiredEquipment
            if baseRequires.isSubset(of: user) { return true }
            return variants.contains { $0.profile.requiredEquipment.isSubset(of: user) }
        }
        return requiredEquipment(for: template).isSubset(of: user)
    }

    /// Leitet das tatsaechlich benoetigte Equipment eines Templates OHNE
    /// `equipmentVariants` aus seinen Uebungen her (Name-Join gegen
    /// `ExerciseLibraryData.byName`). `.bodyweight` zaehlt nicht als
    /// Anforderung — dafuer muss der Nutzer nichts besitzen. Ein unbekannter
    /// Uebungsname wird uebersprungen statt den gesamten Filter zu blockieren
    /// (sollte laut `ExerciseLibraryDataTests` nicht vorkommen, ist aber kein
    /// Grund, allen Nutzern das Template zu verweigern).
    static func requiredEquipment(for template: ProgramTemplate) -> Set<Equipment> {
        var result: Set<Equipment> = []
        for day in template.days {
            for exercise in day.exercises {
                guard let spec = ExerciseLibraryData.byName[exercise.name], spec.equipment != .bodyweight else { continue }
                result.insert(spec.equipment)
            }
        }
        return result
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

    /// Fix "doppeltes Onboarding", verschaerft durch Plan-Katalog-Audit
    /// Befund 3: Starter/Wiedereinsteiger duerfen keine Plaene vorgeschlagen
    /// bekommen, die nicht nachgewiesen einsteigertauglich sind. Die fruehere
    /// Fassung liess ein Template schon durch, wenn es IRGENDWO
    /// `.intermediate` trug — damit bestanden reine Intermediate/Advanced-
    /// Programme wie Push-Pull-Legs (119 Saetze/Woche, 6 Tage, 5 freie
    /// Compound-Lifts), Upper-Lower, Bro-Split und Powerlifting 3x5 den
    /// Filter trotz fehlendem `.beginner`-Tag. Jetzt verlangt der Filter
    /// explizit `.beginner` — "intermediate-getaggt" allein ist keine
    /// Freigabe (siehe docs/PLAN_CATALOG_AUDIT.md). `nil`/`.experienced`
    /// filtert nichts zusaetzlich raus (bestehendes Verhalten, nur der
    /// weiche Score ueber `answers.experience` gilt).
    private static func experienceTrackMatches(template: ProgramTemplate, track: ExperienceTrack?) -> Bool {
        switch track {
        case .starter, .returner:
            return template.targetExperience.contains(.beginner)
        case .experienced, nil:
            return true
        }
    }

    /// Wenn die K.O.-Kriterien ALLES rausfiltern (extrem strenge Auswahl
    /// wie "Powerlifting + No-Equipment + 2 Tage"), liefern wir wenigstens
    /// die "harmlosen" Bodyweight-Plaene zurueck statt einer leeren Liste.
    /// Verhindert dass der Quiz-Result-Screen leer dasteht.
    ///
    /// Plan-Katalog-Audit Befund 4: die fruehere Fassung ignorierte
    /// `preferredDays` komplett und konnte, falls die Track-Filterung leer
    /// ausging, auf die KOMPLETT ungefilterte Bodyweight-Liste zurueckfallen
    /// — die `crossfit_bodyweight_rx` (rein `.advanced`) enthaelt. Jetzt drei
    /// Stufen, strikt in dieser Prioritaet:
    ///   1. Tage-Obergrenze UND Track respektiert.
    ///   2. Nur Track respektiert (ein laengerer, aber sicherer Plan schlaegt
    ///      einen kurzen ungeeigneten — Sicherheit vor Tages-Praeferenz).
    ///   3. Absoluter Notfall ohne Track-Filter — `isFallback` ist in diesem
    ///      Pfad ohnehin `true`, die UI zeigt bereits "Beste verfuegbare
    ///      Option" statt "Empfohlen" (UX-Fix "Empfehlung wirkt immer
    ///      gleich", Punkt 5).
    private static func fallback(
        for answers: QuizAnswers,
        allTemplates: [ProgramTemplate],
        experienceTrack: ExperienceTrack?
    ) -> [ProgramTemplate] {
        // Bodyweight-Plaene laufen ueberall, daher sicherer Fallback.
        let bodyweight = allTemplates.filter { $0.targetEnvironment == .noEquipment }

        let daysAndTrack = bodyweight.filter {
            $0.daysPerWeek <= answers.preferredDays && experienceTrackMatches(template: $0, track: experienceTrack)
        }
        if !daysAndTrack.isEmpty { return daysAndTrack }

        let trackOnly = bodyweight.filter { experienceTrackMatches(template: $0, track: experienceTrack) }
        if !trackOnly.isEmpty { return trackOnly }

        return bodyweight
    }
}
