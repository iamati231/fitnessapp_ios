import XCTest
@testable import FitnessAppCore

final class GoalDrivenPlanSelectionBuilderTests: XCTestCase {

    // MARK: - preferredStrengthKind

    func testPreferredStrengthKindPrefersBarbellOverEverything() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKind(from: [.barbell, .dumbbell, .kettlebell]),
            .barbell
        )
    }

    func testPreferredStrengthKindFallsBackToDumbbellWithoutBarbell() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKind(from: [.dumbbell, .kettlebell]),
            .dumbbell
        )
    }

    func testPreferredStrengthKindFallsBackToKettlebellWithoutBarbellOrDumbbell() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKind(from: [.kettlebell, .band]),
            .kettlebell
        )
    }

    func testPreferredStrengthKindFallsBackToBodyweightWhenNothingElseAvailable() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKind(from: [.bodyweight]),
            .bodyweight
        )
        XCTAssertEqual(GoalDrivenPlanSelectionBuilder.preferredStrengthKind(from: []), .bodyweight)
    }

    // MARK: - makeSelections: reine Kraftziele

    func testHypertrophyGoalProducesSingleStrengthSelectionWithAllDays() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hypertrophy, enduranceModality: nil, totalDaysPerWeek: 4,
            sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.barbell]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.kind, .barbell)
        XCTAssertEqual(selections.first?.daysPerWeek, 4)
        XCTAssertEqual(selections.first?.sessionDurationMinutes, 45)
        XCTAssertEqual(selections.first?.experience, .intermediate)
    }

    func testStrengthGoalUsesEquipmentDerivedKindNotBarbellByDefault() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .strength, enduranceModality: nil, totalDaysPerWeek: 3,
            sessionDurationMinutes: 60, experience: .advanced, equipmentPreferences: [.kettlebell]
        )
        XCTAssertEqual(selections.map(\.kind), [.kettlebell])
    }

    func testFunctionalGoalFallsBackToBodyweightWithoutAnyEquipment() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .functional, enduranceModality: nil, totalDaysPerWeek: 3,
            sessionDurationMinutes: 40, experience: .beginner, equipmentPreferences: [.bodyweight]
        )
        XCTAssertEqual(selections.map(\.kind), [.bodyweight])
    }

    // MARK: - makeSelections: reine Ausdauerziele

    func testEnduranceGoalWithRunningModalityProducesSingleRunningSelection() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .endurance, enduranceModality: .running, totalDaysPerWeek: 4,
            sessionDurationMinutes: 35, experience: .intermediate, equipmentPreferences: []
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.kind, .running)
        XCTAssertEqual(selections.first?.daysPerWeek, 4)
    }

    func testEnduranceGoalWithCyclingModalityProducesSingleCyclingSelection() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .endurance, enduranceModality: .cycling, totalDaysPerWeek: 3,
            sessionDurationMinutes: 50, experience: .beginner, equipmentPreferences: []
        )
        XCTAssertEqual(selections.map(\.kind), [.cycling])
    }

    /// `.both` verteilt die Tage 50/50, Laufen bekommt bei ungerader Zahl den
    /// zusaetzlichen Tag (`trainingTypeKinds` liefert `[.running, .cycling]`
    /// in dieser Reihenfolge).
    func testEnduranceGoalWithBothModalitySplitsDaysWithRunningGettingTheExtraDay() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .endurance, enduranceModality: .both, totalDaysPerWeek: 5,
            sessionDurationMinutes: 30, experience: .intermediate, equipmentPreferences: []
        )
        XCTAssertEqual(selections.count, 2)
        XCTAssertEqual(selections[0].kind, .running)
        XCTAssertEqual(selections[0].daysPerWeek, 3)
        XCTAssertEqual(selections[1].kind, .cycling)
        XCTAssertEqual(selections[1].daysPerWeek, 2)
    }

    func testEnduranceGoalWithBothModalityEvenSplitHasNoRemainderDay() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .endurance, enduranceModality: .both, totalDaysPerWeek: 4,
            sessionDurationMinutes: 30, experience: .intermediate, equipmentPreferences: []
        )
        XCTAssertEqual(selections.map(\.daysPerWeek), [2, 2])
    }

    /// Defensive: fehlt die Modalitaet (sollte die aufrufende UI immer vorher
    /// erfragen), wird NICHT stillschweigend "nichts geplant", sondern auf
    /// Laufen zurueckgefallen statt eine leere Auswahl zu erzeugen.
    func testEnduranceGoalWithoutModalityFallsBackToRunning() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .endurance, enduranceModality: nil, totalDaysPerWeek: 3,
            sessionDurationMinutes: 30, experience: .intermediate, equipmentPreferences: []
        )
        XCTAssertEqual(selections.map(\.kind), [.running])
    }

    // MARK: - makeSelections: Hybrid (Kraft + Ausdauer kombinieren)

    func testHybridGoalSplitsDaysBetweenStrengthAndEnduranceWithStrengthGettingExtraDay() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hybrid, enduranceModality: .running, totalDaysPerWeek: 5,
            sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.barbell]
        )
        XCTAssertEqual(selections.count, 2)
        XCTAssertEqual(selections[0].kind, .barbell)
        XCTAssertEqual(selections[0].daysPerWeek, 3)
        XCTAssertEqual(selections[1].kind, .running)
        XCTAssertEqual(selections[1].daysPerWeek, 2)
    }

    func testHybridGoalWithBothEnduranceModalityProducesThreeSelections() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hybrid, enduranceModality: .both, totalDaysPerWeek: 6,
            sessionDurationMinutes: 45, experience: .advanced, equipmentPreferences: [.dumbbell]
        )
        // 6 Tage: 3 Kraft, 3 Ausdauer (2 Laufen + 1 Radfahren)
        XCTAssertEqual(selections.map(\.kind), [.dumbbell, .running, .cycling])
        XCTAssertEqual(selections.map(\.daysPerWeek), [3, 2, 1])
        XCTAssertEqual(selections.reduce(0) { $0 + $1.daysPerWeek }, 6)
    }

    /// Geraete-Abnahme (Runde 11, "GoalDrivenPlanSelectionBuilder": feste
    /// Aufteilung koennte bei "beides" eine gewaehlte Sportart ohne
    /// sichtbaren Konflikt verlieren): `totalDaysPerWeek = 3` ist der
    /// tatsaechliche UI-Default (`PlanBuilderView.totalDaysPerWeek`,
    /// Slider startet bei 3) — der haeufigste, unveraenderte Fall, den ein
    /// Nutzer erreicht, der Hybrid + "Both" (Laufen+Radfahren) waehlt, ohne
    /// den Tage-Slider anzufassen. `strengthDays = ceil(3/2) = 2` laesst nur
    /// 1 Tag fuer die Ausdauer-Haelfte; `enduranceSelections(.both,
    /// totalDays: 1, ...)` kann aber nicht BEIDE Modalitaeten mit je
    /// mindestens 1 Tag bedienen und laesst Radfahren MIT NULL Tagen
    /// komplett aus der generierten Auswahl heraus — exakt das vom
    /// Vorgesetzten vermutete stille Verlieren einer gewaehlten Sportart,
    /// hier mit dem konkreten, realistischen Standard-Tageswert bestaetigt.
    ///
    /// Dies ist bewusst NICHT gefixt: die Spezifikation (Pruefall "zu
    /// wenige Einheiten fuer alle gewaehlten Sportarten") verlangt eine
    /// SICHTBARE Entscheidung/Konflikt-Anzeige statt eines stillen
    /// Weglassens — das ist eine Produktentscheidung (neue Konflikt-UI),
    /// keine begrenzte Code-Korrektur, und wird daher als fachlicher
    /// Widerspruch dokumentiert (siehe docs/DELTIQ_DEVICE_ACCEPTANCE.md,
    /// Runde 11) statt hier eigenmaechtig aufgeloest. Dieser Test PINNT das
    /// aktuelle (spezifikationswidrige) Verhalten, damit ein kuenftiger,
    /// bewusster Fix hier sichtbar etwas aendern MUSS, statt dass die
    /// Luecke unbemerkt bleibt.
    func testHybridGoalWithBothModalityAtTheDefaultThreeDaysSilentlyDropsCycling() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hybrid, enduranceModality: .both, totalDaysPerWeek: 3,
            sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.barbell]
        )
        XCTAssertEqual(
            selections.map(\.kind), [.barbell, .running],
            "Bekannte Luecke (Runde 11): Radfahren wird bei 3 Default-Tagen trotz expliziter " +
                "\"Both\"-Wahl ohne jede sichtbare Meldung komplett aus der Auswahl entfernt."
        )
        XCTAssertFalse(
            selections.map(\.kind).contains(.cycling),
            "Dieser Assert dokumentiert die Luecke, er bestaetigt sie NICHT als gewuenscht - siehe " +
                "Testdoku oben und die Matrix-Dokumentation zu Runde 11."
        )
    }

    func testHybridGoalWithSingleDayGivesTheOnlyDayToStrength() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hybrid, enduranceModality: .running, totalDaysPerWeek: 1,
            sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.bodyweight]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.kind, .bodyweight)
        XCTAssertEqual(selections.first?.daysPerWeek, 1)
    }

    // MARK: - Randfaelle

    func testZeroDaysProducesNoSelections() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hybrid, enduranceModality: .running, totalDaysPerWeek: 0,
            sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.barbell]
        )
        XCTAssertTrue(selections.isEmpty)
    }

    /// Jede erzeugte Selection-Menge summiert sich exakt auf die angeforderte
    /// Gesamttagzahl — keine stillschweigend verlorenen oder doppelten Tage.
    func testAllSelectionsAlwaysSumToTotalDaysPerWeek() {
        for goal: TrainingGoal in [.hypertrophy, .strength, .hybrid, .functional, .endurance, .weightLoss] {
            for modality: EnduranceModality? in [nil, .running, .cycling, .both] {
                for days in 1...7 {
                    let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
                        goal: goal, enduranceModality: modality, totalDaysPerWeek: days,
                        sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.barbell]
                    )
                    let sum = selections.reduce(0) { $0 + $1.daysPerWeek }
                    XCTAssertEqual(sum, days, "goal=\(goal) modality=\(String(describing: modality)) days=\(days)")
                }
            }
        }
    }
}
