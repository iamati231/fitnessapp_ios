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
