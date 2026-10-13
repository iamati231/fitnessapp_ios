import XCTest
@testable import FitnessAppCore

/// DEL-090: Tests fuer den Quiz-Score-Algorithmus.
final class PlanMatchmakerTests: XCTestCase {

    private let allTemplates = ProgramTemplates.all

    /// Hauptbeispiel aus dem Ticket: "Athletischer werden + Fortgeschritten +
    /// 5 Tage + Gym" → Top-Match sollte Hybrid Balanced sein.
    func testHybridBalancedTopMatchForAthletischFortgeschritten5DayGym() {
        let answers = QuizAnswers(
            goal: .hybrid,
            experience: .intermediate,
            preferredDays: 5,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertEqual(ranked.first?.id, "hybrid_balanced")
    }

    /// Powerlifting-User mit 3 Tagen Gym → 5x5 oder 3x5 sollten oben sein.
    func testPowerlifting3DayTopMatchIsAPowerliftingProgram() {
        let answers = QuizAnswers(
            goal: .strength,
            experience: .intermediate,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        let topID = ranked.first?.id ?? ""
        XCTAssertTrue(topID.contains("powerlifting"),
                      "Top-Match sollte ein Powerlifting-Plan sein, ist: \(topID)")
    }

    /// User mit kleiner Trainings-Zeit (2 Tage) → Plaene mit daysPerWeek > 2
    /// fliegen raus. Top sollte 2-Tage-Plan oder 1-Tage-Plan sein.
    func testKOMaxDaysFiltersOutLongerPlans() {
        let answers = QuizAnswers(
            goal: .hybrid,
            experience: .intermediate,
            preferredDays: 2,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        for plan in ranked {
            XCTAssertLessThanOrEqual(plan.daysPerWeek, 2,
                                     "\(plan.name) hat \(plan.daysPerWeek) Tage > 2 — Hard-Filter hat versagt")
        }
    }

    /// No-Equipment-User → nur Bodyweight-Plan sollte durchkommen.
    func testKOEnvFiltersOutGymPlans() {
        let answers = QuizAnswers(
            goal: .functional,
            experience: .beginner,
            preferredDays: 3,
            environment: .noEquipment
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        for plan in ranked {
            XCTAssertEqual(plan.targetEnvironment, .noEquipment,
                           "\(plan.name) ist nicht noEquipment, sollte aber gefiltert sein")
        }
    }

    /// Home-Gym-User → kein reines Gym-Programm sollte durchkommen, aber
    /// Bodyweight-Plaene (.noEquipment) bleiben drin.
    func testHomeGymUserAcceptsHomeGymAndBodyweight() {
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: .beginner,
            preferredDays: 3,
            environment: .homeGym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        for plan in ranked {
            XCTAssertNotEqual(plan.targetEnvironment, .gym,
                              "\(plan.name) ist .gym, sollte fuer HomeGym-User raus")
        }
    }

    /// Ergebnis-Sortierung: Goal-Match (+3) schlaegt Experience-Match (+2)
    /// schlaegt exakte Day-Count (+1). Plan mit Goal + Experience + exakter
    /// Day-Count rankt hoeher als Plan mit nur Goal.
    func testScoreOrderingMostMatchesFirst() {
        let answers = QuizAnswers(
            goal: .strength,
            experience: .intermediate,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertFalse(ranked.isEmpty)
        // Top-Plan muss mindestens das Goal teilen.
        XCTAssertTrue(ranked.first!.targetGoals.contains(.strength),
                      "Top-Match muss das User-Goal beruehren")
    }

    /// Fix "Doppelte Abnehmen-Semantik": eine fruehere Phase-2-Fassung hatte
    /// Templates mit `.fatloss` getaggt, waehrend Quiz/Persistenz `.weightLoss`
    /// nutzten — zwei Enum-Faelle fuer dieselbe Sache, Abnehmen-User bekamen
    /// dadurch NIE einen Ziel-Matchbonus. `.fatloss` ist entfernt, alle
    /// Templates taggen jetzt `.weightLoss`.
    func testWeightLossGoalGetsTemplateMatchBonusAndTopsWithFatburnPlan() {
        let answers = QuizAnswers(
            goal: .weightLoss,
            experience: .beginner,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertFalse(ranked.isEmpty)
        XCTAssertTrue(ranked.contains { $0.targetGoals.contains(.weightLoss) },
                      "Mindestens ein Template muss .weightLoss tragen und so den Zielbonus bekommen")
        XCTAssertEqual(ranked.first?.id, "fat_loss_fullbody",
                       "Top-Match fuer Abnehmen sollte das Fatburn-Ganzkoerper-Template sein, ist: \(ranked.first?.id ?? "nil")")
    }

    // MARK: Fix "doppeltes Onboarding" — Persona-Tests (ExperienceTrack statt Quiz)

    /// Persona "Abnehmen, 3 Tage, Gym, Starter" -> Ganzkoerper-Plan
    /// (Fatburn-Ganzkoerper). `experienceTrack` nutzt hier den echten
    /// Pfad ueber `asExperienceLevel`, nicht eine hart eingesetzte
    /// `ExperienceLevel` — so wie es die Onboarding-UI jetzt tut.
    func testStarterWeightLossThreeDaysGymTopsWithFullBodyPlan() {
        let track = ExperienceTrack.starter
        let answers = QuizAnswers(
            goal: .weightLoss,
            experience: track.asExperienceLevel,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "fat_loss_fullbody")
    }

    /// Persona "Muskelaufbau, 5 Tage, Gym, Erfahren" -> Split-Plan (Bro
    /// Split ist das einzige Template mit genau 5 Tagen, das zusaetzlich
    /// Hypertrophie UND Intermediate/Advanced traegt).
    func testExperiencedHypertrophyFiveDaysGymTopsWithSplitPlan() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: track.asExperienceLevel,
            preferredDays: 5,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "bro_split")
    }

    /// Harter Filter: ein Starter sieht `arnold_split` (reiner Expertenplan,
    /// `targetExperience: [.advanced]`) ueberhaupt nicht in der Liste, auch
    /// nicht weit hinten — unabhaengig vom Score.
    func testStarterNeverSeesExpertOnlyPlans() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .beginner, preferredDays: 6, environment: .gym)
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: .starter)
        XCTAssertFalse(ranked.contains { $0.id == "arnold_split" })
    }

    /// Ohne `experienceTrack` (Default `nil`, z.B. bestehende Aufrufer) bleibt
    /// der reine Expertenplan weiterhin sichtbar — der harte Filter ist
    /// optional, kein globales Verhalten.
    func testExpertOnlyPlanStaysVisibleWithoutExperienceTrack() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .beginner, preferredDays: 6, environment: .gym)
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertTrue(ranked.contains { $0.id == "arnold_split" })
    }

    // MARK: Fix "Badge fast ueberall" — matchReasons

    func testMatchReasonsAreTrueOnlyForActualMatches() {
        let answers = QuizAnswers(goal: .strength, experience: .intermediate, preferredDays: 3, environment: .gym)
        guard let template = allTemplates.first(where: { $0.id == "powerlifting_3x5" }) else {
            return XCTFail("powerlifting_3x5 template not found")
        }
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: answers)
        XCTAssertTrue(reasons.goalMatch, "powerlifting_3x5 tags .strength")
        XCTAssertTrue(reasons.daysMatch, "powerlifting_3x5 runs 3 days")
        XCTAssertTrue(reasons.levelMatch, "powerlifting_3x5 tags .intermediate")
    }

    func testMatchReasonsAreFalseWhenNothingMatches() {
        // powerlifting_3x5 tagt targetGoals: [.strength], targetExperience:
        // [.intermediate, .advanced], daysPerWeek: 3 — .weightLoss/.beginner/6
        // treffen keins davon.
        let answers = QuizAnswers(goal: .weightLoss, experience: .beginner, preferredDays: 6, environment: .gym)
        guard let template = allTemplates.first(where: { $0.id == "powerlifting_3x5" }) else {
            return XCTFail("powerlifting_3x5 template not found")
        }
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: answers)
        XCTAssertFalse(reasons.goalMatch, "powerlifting_3x5 tags only .strength, not .weightLoss")
        XCTAssertFalse(reasons.daysMatch, "powerlifting_3x5 runs 3 days, not 6")
        XCTAssertFalse(reasons.levelMatch, "powerlifting_3x5 does not tag .beginner")
    }

    // MARK: Fix "doppeltes Onboarding" — Fallback respektiert ExperienceTrack

    /// Der Fallback-Pfad (alles rausgefiltert) muss den experienceTrack-
    /// Filter weiterhin respektieren: `crossfit_bodyweight_rx` ist
    /// `.noEquipment` aber `targetExperience: [.advanced]` — ein Starter im
    /// Fallback darf ihn nicht vorgeschlagen bekommen.
    func testFallbackRespectsExperienceTrackWhenPossible() {
        // Extremfilter wie testFallbackProducesBodyweightPlansWhenAllFiltered,
        // zusaetzlich als Starter.
        let answers = QuizAnswers(goal: .strength, experience: .advanced, preferredDays: 2, environment: .noEquipment)
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: .starter)
        XCTAssertFalse(ranked.isEmpty, "Fallback sollte weiterhin mindestens einen Plan liefern")
        XCTAssertFalse(ranked.contains { $0.id == "crossfit_bodyweight_rx" },
                       "crossfit_bodyweight_rx ist reiner Expertenplan, darf im Starter-Fallback nicht auftauchen")
        XCTAssertTrue(ranked.allSatisfy { $0.targetEnvironment == .noEquipment })
    }

    /// Fallback: Extrem-Filter "Strength + No-Equipment + 2 Tage" wuerde
    /// nichts treffen → wir liefern wenigstens die BW-Plaene zurueck.
    func testFallbackProducesBodyweightPlansWhenAllFiltered() {
        let answers = QuizAnswers(
            goal: .strength,
            experience: .advanced,
            preferredDays: 2,
            environment: .noEquipment
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertFalse(ranked.isEmpty, "Fallback sollte mindestens einen BW-Plan liefern")
        XCTAssertTrue(ranked.allSatisfy { $0.targetEnvironment == .noEquipment })
    }
}
