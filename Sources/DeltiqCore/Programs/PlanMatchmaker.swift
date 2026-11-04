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
    /// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md
    /// Abschnitt 13): die praezise, dreiwertige Equipment-Pruefung. `nil`
    /// bedeutet reiner Legacy-Pfad — Equipment-Filter/-Begruendung laufen
    /// dann unveraendert ueber `equipmentPreferences` (Set-Teilmengen-
    /// Pruefung). Sobald ein Profil mitgegeben wird, ist DIESES fuer Filter
    /// UND Begruendungen massgeblich; `equipmentPreferences` bleibt daneben
    /// nur noch eine Kompatibilitaetsprojektion (z.B. fuer Call-Sites, die
    /// noch nicht umgestellt sind) und darf eine ueber dieses Profil
    /// bestaetigte Unvereinbarkeit nicht uebersteuern.
    public let equipmentProfile: UserEquipmentProfile?

    public init(
        goal: TrainingGoal,
        experience: ExperienceLevel,
        preferredDays: Int,
        environment: EnvironmentType,
        equipmentPreferences: Set<Equipment> = [],
        equipmentProfile: UserEquipmentProfile? = nil
    ) {
        self.goal = goal
        self.experience = experience
        self.preferredDays = preferredDays
        self.environment = environment
        self.equipmentPreferences = equipmentPreferences
        self.equipmentProfile = equipmentProfile
    }
}

/// Fix "Badge fast ueberall": die vier unabhaengigen Gruende, aus denen ein
/// Template zu den Onboarding-Antworten passt. Jede UI-Badge rendert genau
/// EIN Feld — nie alle pauschal, nie wenn `false`.
public struct PlanMatchReasons: Sendable, Equatable {
    public let goalMatch: Bool
    public let daysMatch: Bool
    public let levelMatch: Bool
    /// `true` ausschliesslich bei vollstaendig bestaetigter Equipment-Passung
    /// — niemals bei unbekannten Voraussetzungen (Smart-Onboarding-Epic
    /// Phase 4, Punkt 5). Rueckwaerts-kompatibler Bool-Zugriff: wird `nil`
    /// (reiner Legacy-Pfad ohne `UserEquipmentProfile`), aus
    /// `equipmentStatus` gespiegelt, sonst die alte grobe Pruefung.
    public let equipmentMatch: Bool
    /// Smart-Onboarding-Epic Phase 4: die volle, dreiwertige Equipment-
    /// Pruefung der tatsaechlich fuer dieses Template gewaehlten Variante —
    /// `nil` nur im reinen Legacy-Pfad (kein `UserEquipmentProfile`
    /// uebergeben). Traegt die konkreten Luecken (fehlend/unbekannt/nicht
    /// annotiert) fuer eine transparente UI-Anzeige, statt nur eines Bools.
    public let equipmentStatus: PlanEquipmentStatus?

    public init(goalMatch: Bool, daysMatch: Bool, levelMatch: Bool, equipmentMatch: Bool, equipmentStatus: PlanEquipmentStatus? = nil) {
        self.goalMatch = goalMatch
        self.daysMatch = daysMatch
        self.levelMatch = levelMatch
        self.equipmentMatch = equipmentMatch
        self.equipmentStatus = equipmentStatus
    }
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
                && equipmentMatches(template: template, user: answers.equipmentPreferences, profile: answers.equipmentProfile)
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
            if plan.targetGoals.contains(answers.goal) {
                score += 3
            } else if goalIsSupportedButNotPrimaryFocus(answers.goal, of: plan) {
                // Szenario 8 (PLAN_MATCHING_AND_EQUIPMENT_COMBINED.md): ohne
                // diesen Term konnte ein inhaltlich passender Kraft-Split wie
                // Upper-Lower bei "Abnehmen" rechnerisch nie mit einem
                // explizit weightLoss-getaggten Zirkel-/CrossFit-Programm
                // konkurrieren, selbst wenn Tage/Erfahrung/Equipment exakt
                // passten — ein fehlender Zieltag allein hat ihn komplett
                // aus dem Rennen genommen. +1 reichte empirisch nicht: ein
                // rein praeferenzgetriebenes Zirkel-/CrossFit-Template mit
                // echtem weightLoss-Tag blieb trotzdem vor einem inhaltlich
                // passenden Kraft-Split, obwohl keine explizite CrossFit-
                // Praeferenz vorlag (Epic-Vorgabe: das darf nicht sein). +2
                // hebt den Support-Fall auf Augenhoehe mit dem Level-Term,
                // genug um echte Zirkel-/CrossFit-Praeferenz-Programme zu
                // ueberholen, aber weiterhin klar hinter Templates mit echtem
                // weightLoss-PRIMAERfokus (+3), die zu Recht vorne bleiben.
                score += 2
            }
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

    /// Szenario 8 (PLAN_MATCHING_AND_EQUIPMENT_COMBINED.md): trennt
    /// Ziel-UNTERSTUETZUNG vom Ziel-PRIMAERFOKUS (`targetGoals.contains`,
    /// weiterhin der staerkere +3-Term oben). Ein Krafttraining-Split traegt
    /// Muskelmasse im Kaloriendefizit genauso bei wie ein explizit
    /// `weightLoss`-getaggter Plan — Fettverlust kommt aus dem Defizit, nicht
    /// aus der Trainingsform (siehe `fat_loss_fullbody`s eigene Beschreibung).
    /// Bewusst NICHT die vom Auftrag ausdruecklich verbotene "pauschale
    /// weightLoss-Freigabe fuer alle Templates": nur Templates mit echtem
    /// Hypertrophie-/Kraft-Fokus qualifizieren inhaltlich begruendet.
    /// Funktionelle/Zirkel-Programme (CrossFit, Kettlebell-Komplexe) bekommen
    /// HIER keinen Zusatz-Punkt — CrossFit/Zirkel ist eine Trainings-
    /// PRAEFERENZ, keine automatische Konsequenz aus "Abnehmen" (Epic-
    /// Vorgabe); deren eigene `weightLoss`-Tags (wo vorhanden) zaehlen
    /// bereits ueber den Primaerfokus-Term oben.
    ///
    /// Nur fuer `.weightLoss` aktiv — die anderen Ziele haben keine analoge
    /// "jedes Krafttraining hilft auch hierbei"-Begruendung.
    static func goalIsSupportedButNotPrimaryFocus(_ goal: TrainingGoal, of template: ProgramTemplate) -> Bool {
        guard goal == .weightLoss else { return false }
        return template.targetGoals.contains(.hypertrophy) || template.targetGoals.contains(.strength)
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
        if let profile = answers.equipmentProfile {
            // Smart-Onboarding-Epic Phase 4, Punkt 5: "Equipment passend" nur
            // bei vollstaendig bestaetigter Passung der tatsaechlich
            // gewaehlten Variante — niemals bei `.unknown` (unbekannte
            // Voraussetzungen werden sichtbar gemacht, nie als sicher
            // passend dargestellt).
            let status = template.bestEquipmentCheckedVariant(against: profile).equipmentStatus
            return PlanMatchReasons(
                goalMatch: template.targetGoals.contains(answers.goal),
                daysMatch: template.daysPerWeek == answers.preferredDays,
                levelMatch: template.targetExperience.contains(answers.experience),
                equipmentMatch: status.isAvailable,
                equipmentStatus: status
            )
        }
        return PlanMatchReasons(
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
            // (leeres Set = "nicht gepflegt", kein Badge noetig). Reiner
            // Legacy-Pfad (kein `UserEquipmentProfile` uebergeben).
            equipmentMatch: !answers.equipmentPreferences.isEmpty
                && equipmentMatches(template: template, user: answers.equipmentPreferences, profile: nil)
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
    ///
    /// Vor-Phase-4-Praezisierung (PLAN_EQUIPMENT_MATCHING_AUDIT.md): "Nur
    /// Koerpergewicht bestaetigt" (`UserEquipmentProfile.legacyEquipmentPreferences`
    /// nach `confirmEquipmentProfileComplete()`, liefert IMMER mindestens
    /// `{.bodyweight}`) und "Ausstattung unbekannt" (`[]`, nie bestaetigt)
    /// sind hier bewusst NICHT dieselbe Sache: `[]` ist leer und nimmt oben
    /// den fruehen Ausstieg, `{.bodyweight}` ist nicht leer und durchlaeuft
    /// die echte Pruefung. Das traegt zuverlaessig, weil `.bodyweight` nie
    /// Teil eines `requiredEquipment`-Ergebnisses ist (weder hier noch in
    /// `EquipmentProfile.requiredEquipment`) — ein bestaetigter Nur-
    /// Koerpergewicht-Nutzer besteht deshalb korrekt KEIN Template, das
    /// tatsaechlich Geraete braucht. Siehe
    /// `PlanMatchmakerTests.testEmptyEquipmentIsNoFilterButConfirmedBodyweightOnlyActuallyFilters`.
    ///
    /// Smart-Onboarding-Epic Phase 4: wenn `profile` gesetzt ist, entscheidet
    /// AUSSCHLIESSLICH die praezise Pro-Uebung-Pruefung
    /// (`bestEquipmentCheckedVariant`) — `user`/die grobe Set-Pruefung werden
    /// dann ignoriert, das ist die "legacy bleibt nur Kompatibilitaets-
    /// projektion, darf eine bestaetigte Unvereinbarkeit nicht uebersteuern"-
    /// Vorgabe. Nur `.unavailable` (definitiv fehlendes Equipment bei
    /// mindestens einer annotierten Uebung) schliesst aus — `.unknown`
    /// (unklar oder noch nicht annotiert) lässt das Template bewusst durch,
    /// sonst wuerde eine fehlende Annotation wie eine automatische Ablehnung
    /// wirken, was die Audit-Vorgabe ausdruecklich verbietet.
    private static func equipmentMatches(template: ProgramTemplate, user: Set<Equipment>, profile: UserEquipmentProfile?) -> Bool {
        if let profile {
            return !template.bestEquipmentCheckedVariant(against: profile).equipmentStatus.isUnavailable
        }
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
    ///   * User `.homeGym`/`.noEquipment` → akzeptiert `.homeGym` UND `.noEquipment`
    ///
    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §3): `.noEquipment` war bis Phase 5 auf `plan == .noEquipment`
    /// beschraenkt — das blockierte ein Home-Gym-getaggtes Template allein
    /// wegen des Orts, selbst wenn der User ueber die neue "kleine
    /// Trainingshilfen"-Frage z.B. Kurzhanteln bestaetigt hat, mit denen das
    /// Template tatsaechlich ausfuehrbar waere ("Massgeblich sind konkrete
    /// Voraussetzungen... nicht der Ort", Vorgabe woertlich). Sicher, weil
    /// `envMatches` nur EINER von zwei UND-verknuepften Hard-Filtern ist —
    /// `equipmentMatches` (unveraendert) schliesst ein Home-Gym-Template fuer
    /// einen `.noEquipment`-User weiterhin aus, sobald mindestens eine
    /// annotierte Uebung definitiv fehlendes Equipment braucht. Ein
    /// `.gym`-getaggtes Template bleibt fuer `.noEquipment`/`.homeGym`-User in
    /// jedem Fall ausgeschlossen ("Ein Gym-Plan darf nicht allein deshalb
    /// zugelassen werden, weil eine Kurzhantel vorhanden ist").
    private static func envMatches(plan: EnvironmentType, user: EnvironmentType) -> Bool {
        switch user {
        case .gym:                    return true
        case .homeGym, .noEquipment:  return plan == .homeGym || plan == .noEquipment
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
    /// die "harmlosen" Bodyweight-Plaene zurueck statt einer leeren Liste —
    /// aber NUR, solange sie tatsaechlich bestaetigt Track- und Equipment-
    /// vertraeglich sind. Zwei Stufen, strikt in dieser Prioritaet:
    ///   1. Tage-Obergrenze UND Track UND Equipment respektiert.
    ///   2. Nur Track UND Equipment respektiert (Tage-Obergrenze faellt als
    ///      einzige Praeferenz zuerst — ein laengerer, aber sicherer Plan
    ///      schlaegt einen kurzen ungeeigneten).
    ///
    /// Plan-Katalog-Audit Befund 4, verschaerft: eine fruehere Fassung hatte
    /// zwei weitere, noch laxere Notfall-Stufen ("nur Equipment, Track faellt"
    /// / "weder Track noch Equipment") — mit dem heutigen Katalog unerreichbar
    /// (siehe `testFallbackNeverDropsConfirmedTrackOrEquipmentEvenAsLastResort`:
    /// `bodyweight_mastery` ist komplett unannotiert und damit IMMER
    /// equipment-ok, egal was der Nutzer bestaetigt hat), aber als Garantie
    /// der Funktion selbst falsch: eine kuenftige Katalog-Aenderung (z.B. die
    /// in PLAN_CATALOG_AUDIT.md dokumentierte Luecke "Tuerrahmen/Dip-Barren
    /// nicht modelliert" wird irgendwann geschlossen) haette diese Stufen
    /// scharf geschaltet und dann STILLSCHWEIGEND einen bestaetigt
    /// ungeeigneten Plan geliefert. Gibt es also auch mit respektiertem
    /// Track+Equipment keinen Kandidaten, liefern wir ehrlich eine leere
    /// Liste — die UI (`OnboardingView.rankedTemplates.first`) zeigt dann
    /// einfach keine Empfehlungs-Sektion, der "Baue deinen eigenen Plan"-
    /// Einstieg bleibt trotzdem sichtbar. Eine stillschweigend unpassende
    /// Empfehlung ist niemals besser als ein ehrlicher Leer-Treffer.
    private static func fallback(
        for answers: QuizAnswers,
        allTemplates: [ProgramTemplate],
        experienceTrack: ExperienceTrack?
    ) -> [ProgramTemplate] {
        // Bodyweight-Plaene laufen ueberall, daher sicherer Fallback.
        let bodyweight = allTemplates.filter { $0.targetEnvironment == .noEquipment }

        func equipmentOK(_ template: ProgramTemplate) -> Bool {
            equipmentMatches(template: template, user: answers.equipmentPreferences, profile: answers.equipmentProfile)
        }

        let daysTrackEquipment = bodyweight.filter {
            $0.daysPerWeek <= answers.preferredDays
                && experienceTrackMatches(template: $0, track: experienceTrack)
                && equipmentOK($0)
        }
        if !daysTrackEquipment.isEmpty { return daysTrackEquipment }

        return bodyweight.filter {
            experienceTrackMatches(template: $0, track: experienceTrack) && equipmentOK($0)
        }
    }
}
