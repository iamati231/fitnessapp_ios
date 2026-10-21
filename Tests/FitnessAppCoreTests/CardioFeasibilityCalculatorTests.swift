import XCTest
@testable import FitnessAppCore

final class CardioFeasibilityCalculatorTests: XCTestCase {

    // Ticket-Beispiel: Marathon, 19. Okt. 2026, 22,4 km/Woche Start.
    private let referenceToday = Date(timeIntervalSince1970: 1_700_000_000)
    private let startWeeklyVolumeKm = 22.4

    private func raceDate(weeksFromToday weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: referenceToday) ?? referenceToday
    }

    // MARK: - targetWeeklyVolumeKm

    func testGeneralFitnessHasNoTargetVolume() {
        XCTAssertNil(CardioFeasibilityCalculator.targetWeeklyVolumeKm(for: .generalFitness))
    }

    func testTargetVolumesMatchTicketTable() {
        XCTAssertEqual(CardioFeasibilityCalculator.targetWeeklyVolumeKm(for: .fiveK), 20)
        XCTAssertEqual(CardioFeasibilityCalculator.targetWeeklyVolumeKm(for: .tenK), 30)
        XCTAssertEqual(CardioFeasibilityCalculator.targetWeeklyVolumeKm(for: .halfMarathon), 45)
        XCTAssertEqual(CardioFeasibilityCalculator.targetWeeklyVolumeKm(for: .marathon), 65)
    }

    // MARK: - weeksNeeded (Ticket-Rechenbeispiel)

    func testMarathonNeedsFourteenWeeksFromTicketExample() {
        XCTAssertEqual(
            CardioFeasibilityCalculator.weeksNeeded(for: .marathon, startWeeklyVolumeKm: startWeeklyVolumeKm),
            14
        )
    }

    func testHalfMarathonNeedsTenWeeksFromTicketExample() {
        XCTAssertEqual(
            CardioFeasibilityCalculator.weeksNeeded(for: .halfMarathon, startWeeklyVolumeKm: startWeeklyVolumeKm),
            10
        )
    }

    func testWeeksNeededIsJustTaperWhenAlreadyAtTargetVolume() {
        // 5-km-Ziel (20 km/Woche) liegt unter dem Start von 22,4 - keine Rampe
        // noetig, nur die zwei Taper-Wochen.
        XCTAssertEqual(
            CardioFeasibilityCalculator.weeksNeeded(for: .fiveK, startWeeklyVolumeKm: startWeeklyVolumeKm),
            2
        )
    }

    func testWeeksNeededIsNilForGeneralFitness() {
        XCTAssertNil(CardioFeasibilityCalculator.weeksNeeded(for: .generalFitness, startWeeklyVolumeKm: 10))
    }

    func testWeeksNeededIsNilForNonPositiveStartVolume() {
        XCTAssertNil(CardioFeasibilityCalculator.weeksNeeded(for: .marathon, startWeeklyVolumeKm: 0))
        XCTAssertNil(CardioFeasibilityCalculator.weeksNeeded(for: .marathon, startWeeklyVolumeKm: -5))
    }

    // Bugfix (Review): `target / startWeeklyVolumeKm` kann bei einer
    // winzigen, aber technisch positiven Basis auf +Infinity ueberlaufen -
    // `Int(ceil(...))` wuerde dann traps statt nil zu liefern. Nicht ueber
    // die UI erreichbar (das Feld ist ein normales Dezimal-Textfeld), aber
    // `weeklyBaseVolumeKm` kommt auch aus einem CSV-Import (siehe
    // `DataImportService.importProfile`), also ohne Garantie am Aufrufer.
    func testWeeksNeededDoesNotTrapOnVanishinglySmallStartVolume() {
        XCTAssertNil(CardioFeasibilityCalculator.weeksNeeded(for: .marathon, startWeeklyVolumeKm: .leastNonzeroMagnitude))
    }

    // MARK: - evaluate: Gates

    func testEvaluateReturnsNilForGeneralFitness() {
        let result = CardioFeasibilityCalculator.evaluate(
            goal: .generalFitness, raceDate: raceDate(weeksFromToday: 20),
            weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        )
        XCTAssertNil(result)
    }

    func testEvaluateReturnsNilWithoutRaceDate() {
        let result = CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: nil, weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        )
        XCTAssertNil(result)
    }

    func testEvaluateReturnsNilWithoutBaseVolume() {
        let result = CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: raceDate(weeksFromToday: 20), weeklyBaseVolumeKm: nil, today: referenceToday
        )
        XCTAssertNil(result)
    }

    func testEvaluateReturnsNilForRaceDateInThePast() {
        let result = CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: raceDate(weeksFromToday: -1),
            weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        )
        XCTAssertNil(result)
    }

    // MARK: - evaluate: Machbarkeit + Vorschlag

    func testMarathonFeasibleWithEnoughWeeks() throws {
        let result = try XCTUnwrap(CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: raceDate(weeksFromToday: 16),
            weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        ))
        XCTAssertTrue(result.feasible)
        XCTAssertEqual(result.weeksNeeded, 14)
        XCTAssertEqual(result.weeksAvailable, 16)
        XCTAssertNil(result.suggestedGoal)
    }

    func testMarathonInfeasibleSuggestsHalfMarathon() throws {
        // 11 Wochen verfuegbar: reicht nicht fuer Marathon (14), aber fuer
        // Halbmarathon (10).
        let result = try XCTUnwrap(CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: raceDate(weeksFromToday: 11),
            weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        ))
        XCTAssertFalse(result.feasible)
        XCTAssertEqual(result.weeksNeeded, 14)
        XCTAssertEqual(result.weeksAvailable, 11)
        XCTAssertEqual(result.suggestedGoal, .halfMarathon)
    }

    func testMarathonInfeasibleSkipsHalfMarathonSuggestsTenK() throws {
        // 7 Wochen: weder Marathon (14) noch Halbmarathon (10) gehen auf,
        // 10 km (6) reicht.
        let result = try XCTUnwrap(CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: raceDate(weeksFromToday: 7),
            weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        ))
        XCTAssertFalse(result.feasible)
        XCTAssertEqual(result.suggestedGoal, .tenK)
    }

    func testMarathonInfeasibleWithNoSuggestionWhenEvenFiveKDoesNotFit() throws {
        // Nur 1 Woche verfuegbar - selbst 5 km (2 Wochen Taper) passt nicht.
        let result = try XCTUnwrap(CardioFeasibilityCalculator.evaluate(
            goal: .marathon, raceDate: raceDate(weeksFromToday: 1),
            weeklyBaseVolumeKm: startWeeklyVolumeKm, today: referenceToday
        ))
        XCTAssertFalse(result.feasible)
        XCTAssertNil(result.suggestedGoal)
    }

    func testFiveKGoalHasNoSmallerGoalToSuggestWhenInfeasible() throws {
        // 5 km ist das kleinste geprüfte Ziel - selbst wenn es nicht aufgeht,
        // gibt es nichts Kleineres vorzuschlagen (Allgemeine Fitness hat kein
        // Zielvolumen und ist daher kein Rueckfall).
        let result = try XCTUnwrap(CardioFeasibilityCalculator.evaluate(
            goal: .fiveK, raceDate: raceDate(weeksFromToday: 1),
            weeklyBaseVolumeKm: 1.0, today: referenceToday
        ))
        XCTAssertFalse(result.feasible)
        XCTAssertNil(result.suggestedGoal)
    }

    // MARK: - suppressionFingerprint

    func testSuppressionFingerprintIsDeterministic() {
        let date = raceDate(weeksFromToday: 10)
        let a = CardioFeasibilityCalculator.suppressionFingerprint(goal: .marathon, raceDate: date, weeklyBaseVolumeKm: 22.4)
        let b = CardioFeasibilityCalculator.suppressionFingerprint(goal: .marathon, raceDate: date, weeklyBaseVolumeKm: 22.4)
        XCTAssertEqual(a, b)
    }

    func testSuppressionFingerprintChangesWithGoal() {
        let date = raceDate(weeksFromToday: 10)
        let a = CardioFeasibilityCalculator.suppressionFingerprint(goal: .marathon, raceDate: date, weeklyBaseVolumeKm: 22.4)
        let b = CardioFeasibilityCalculator.suppressionFingerprint(goal: .halfMarathon, raceDate: date, weeklyBaseVolumeKm: 22.4)
        XCTAssertNotEqual(a, b)
    }

    func testSuppressionFingerprintChangesWithWeeklyVolume() {
        let date = raceDate(weeksFromToday: 10)
        let a = CardioFeasibilityCalculator.suppressionFingerprint(goal: .marathon, raceDate: date, weeklyBaseVolumeKm: 22.4)
        let b = CardioFeasibilityCalculator.suppressionFingerprint(goal: .marathon, raceDate: date, weeklyBaseVolumeKm: 30.0)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - planGeneratorInput (Kraft-/Lauf-Mix-Tabelle)

    func testGeneralFitnessAndFiveKMixIsTwoRunTwoStrength() {
        for goal in [CardioGoal.generalFitness, .fiveK] {
            let input = CardioFeasibilityCalculator.planGeneratorInput(for: goal)
            XCTAssertEqual(input.selections.count, 2)
            XCTAssertEqual(input.selections.first { $0.kind == .running }?.daysPerWeek, 2)
            XCTAssertEqual(input.selections.first { $0.kind == .bodyweight }?.daysPerWeek, 2)
        }
    }

    func testTenKAndHalfMarathonMixIsThreeRunTwoStrength() {
        for goal in [CardioGoal.tenK, .halfMarathon] {
            let input = CardioFeasibilityCalculator.planGeneratorInput(for: goal)
            XCTAssertEqual(input.selections.count, 2)
            XCTAssertEqual(input.selections.first { $0.kind == .running }?.daysPerWeek, 3)
            XCTAssertEqual(input.selections.first { $0.kind == .bodyweight }?.daysPerWeek, 2)
        }
    }

    func testMarathonMixIsFiveRunNoStrength() {
        let input = CardioFeasibilityCalculator.planGeneratorInput(for: .marathon)
        XCTAssertEqual(input.selections.count, 1)
        XCTAssertEqual(input.selections.first?.kind, .running)
        XCTAssertEqual(input.selections.first?.daysPerWeek, 5)
    }

    func testAllMixesStayWithinSevenDaysPerWeek() {
        for goal in CardioGoal.allCases {
            let input = CardioFeasibilityCalculator.planGeneratorInput(for: goal)
            XCTAssertLessThanOrEqual(input.totalDaysPerWeek, 7)
        }
    }
}
