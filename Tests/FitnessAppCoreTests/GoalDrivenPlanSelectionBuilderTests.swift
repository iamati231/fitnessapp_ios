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

    /// writing-block.md 3.2: Maschine reiht sich NACH Kettlebell und VOR
    /// Koerpergewicht ein.
    func testPreferredStrengthKindFallsBackToMachineWithoutFreeWeights() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKind(from: [.machine, .bodyweight]),
            .machine
        )
    }

    // MARK: - preferredStrengthKinds (Bugfix Epic #3.1, plural)

    /// Regression (Epic-Fund #3.1): "Kurzhantel + Kettlebell" muss BEIDE
    /// liefern, nicht nur Kurzhantel (wie `preferredStrengthKind` es durch
    /// Prioritaet still verwirft).
    func testPreferredStrengthKindsReturnsBothDumbbellAndKettlebell() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.dumbbell, .kettlebell]),
            [.dumbbell, .kettlebell]
        )
    }

    /// Regression (Epic-Fund #3.1): "Langhantel + Kurzhantel" — der Report
    /// nennt genau dieses Beispiel ("der Plan verwendet nur die Langhantel").
    func testPreferredStrengthKindsReturnsBothBarbellAndDumbbell() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.barbell, .dumbbell]),
            [.barbell, .dumbbell]
        )
    }

    func testPreferredStrengthKindsOrderIsStablePriorityRegardlessOfSetOrder() {
        // Set hat keine garantierte Iterationsreihenfolge — das Ergebnis muss
        // trotzdem immer in derselben (Prioritaets-)Reihenfolge kommen.
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.kettlebell, .barbell, .dumbbell]),
            [.barbell, .dumbbell, .kettlebell]
        )
    }

    func testPreferredStrengthKindsFallsBackToBodyweightForUnmappedEquipmentOnly() {
        // Kabelzug/Band haben weiterhin keine TrainingTypeKind-Entsprechung
        // — bekannter, dokumentierter Scope-Rand (writing-block.md 3.2,
        // siehe TrainingTypeKind's eigener Doc-Kommentar fuer die konkreten
        // Katalog-Abdeckungszahlen), kein Regress durch diesen Fix.
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.cable, .band]),
            [.bodyweight]
        )
        XCTAssertEqual(GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: []), [.bodyweight])
    }

    /// writing-block.md 3.2: `.machine` bekommt jetzt einen eigenen
    /// `TrainingTypeKind` — anders als `.cable`/`.band` oben darf eine
    /// reine Maschinen-Auswahl nicht mehr auf Koerpergewicht zurueckfallen.
    func testPreferredStrengthKindsMapsMachineInsteadOfFallingBackToBodyweight() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.machine]),
            [.machine]
        )
    }

    /// Maschine + nicht-abgebildete Ausstattung: nur die abgebildeten
    /// Anteile (hier Maschine) landen im Ergebnis, Kabelzug/Band werden wie
    /// zuvor stillschweigend ignoriert, aber OHNE auf Koerpergewicht
    /// zurueckzufallen (es gibt ja einen echten Treffer).
    func testPreferredStrengthKindsMachinePlusUnmappedEquipmentStillMapsMachine() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.cable, .machine, .band]),
            [.machine]
        )
    }

    /// Prioritaetsreihenfolge Langhantel > Kurzhantel > Kettlebell > Maschine
    /// > Koerpergewicht gilt auch, wenn Maschine Teil der Auswahl ist.
    func testPreferredStrengthKindsOrdersMachineAfterKettlebellAndBeforeBodyweight() {
        XCTAssertEqual(
            GoalDrivenPlanSelectionBuilder.preferredStrengthKinds(from: [.machine, .kettlebell, .bodyweight]),
            [.kettlebell, .machine, .bodyweight]
        )
    }

    // MARK: - makeSelections: mehrere Ausstattungsarten (Device-Bugreport
    // "Plan wird nach Geraeteart statt Trainingstagen aufgeteilt")

    /// Mehrere Gerätearten muessen in EINER Selection landen, die ALLE
    /// gewaehlten Tage traegt — nicht mehr in separaten, pro-Geraeteart
    /// exklusiven Selections (das war der gemeldete Bug: 3 Gerätearten
    /// ergaben 3 reine Ein-Geraeteart-Tage statt eines gemischten Pools).
    func testStrengthGoalWithTwoEquipmentTypesMergesIntoOneSelection() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .strength, enduranceModality: nil, totalDaysPerWeek: 4,
            sessionDurationMinutes: 45, experience: .intermediate,
            equipmentPreferences: [.dumbbell, .kettlebell]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.kind, .dumbbell)
        XCTAssertEqual(selections.first?.daysPerWeek, 4)
        XCTAssertEqual(selections.first?.equipmentPool, [.dumbbell, .kettlebell])
    }

    func testStrengthGoalWithThreeEquipmentTypesMergesIntoOneSelectionCoveringAll() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .weightLoss, enduranceModality: nil, totalDaysPerWeek: 6,
            sessionDurationMinutes: 45, experience: .advanced,
            equipmentPreferences: [.barbell, .dumbbell, .kettlebell]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.kind, .barbell)
        XCTAssertEqual(selections.first?.daysPerWeek, 6)
        XCTAssertEqual(selections.first?.equipmentPool, [.barbell, .dumbbell, .kettlebell])
    }

    /// writing-block.md 3.2: Maschine + Kurzhantel landen genauso in einem
    /// gemeinsamen Pool wie jede andere Zwei-Ausstattungs-Kombination.
    func testStrengthGoalWithDumbbellAndMachineMergesIntoOneSelection() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .strength, enduranceModality: nil, totalDaysPerWeek: 4,
            sessionDurationMinutes: 45, experience: .intermediate,
            equipmentPreferences: [.dumbbell, .machine]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.equipmentPool, [.dumbbell, .machine])
    }

    /// Mehr Ausstattungsarten als Tage ist kein Sonderfall mehr — alle
    /// gewaehlten Gerätearten bleiben im gemeinsamen Pool, unabhaengig von
    /// der Tageszahl (es gibt ja keine pro-Geraeteart-Tageszuteilung mehr,
    /// die eine Ausstattung auf 0 Tage bringen koennte).
    func testStrengthGoalKeepsAllEquipmentInPoolEvenWithFewerDaysThanEquipmentTypes() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .strength, enduranceModality: nil, totalDaysPerWeek: 2,
            sessionDurationMinutes: 45, experience: .intermediate,
            equipmentPreferences: [.barbell, .dumbbell, .kettlebell]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.daysPerWeek, 2)
        XCTAssertEqual(selections.first?.equipmentPool, [.barbell, .dumbbell, .kettlebell])
    }

    /// Genau eine Geraeteart darf weiterhin KEINEN `equipmentPool` setzen —
    /// unveraendertes Verhalten, `PlanGenerator` faellt dann auf
    /// `kind.equipmentFilter` zurueck (siehe dortige Doku).
    func testStrengthGoalWithSingleEquipmentTypeLeavesEquipmentPoolNil() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .strength, enduranceModality: nil, totalDaysPerWeek: 3,
            sessionDurationMinutes: 45, experience: .intermediate,
            equipmentPreferences: [.kettlebell]
        )
        XCTAssertEqual(selections.count, 1)
        XCTAssertNil(selections.first?.equipmentPool)
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

    /// A12-Fix (Paket 1, nach Runde-11-Fund): `totalDaysPerWeek = 3` ist der
    /// tatsaechliche UI-Default (`PlanBuilderView.totalDaysPerWeek`, Slider
    /// startet bei 3). Vorher liess die feste 50/50-Kraft/Ausdauer-
    /// Aufteilung (2 Kraft/1 Ausdauer) Radfahren bei "Both" komplett ohne
    /// Meldung aus der Auswahl fallen. Jetzt: transparente Alternative
    /// 1 Kraft + 1 Laufen + 1 Radfahren - jede explizit gewaehlte Sportart
    /// bekommt mindestens einen Tag, keine verschwindet still.
    func testHybridGoalWithBothModalityAtTheDefaultThreeDaysGivesEachDisciplineOneDay() {
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .hybrid, enduranceModality: .both, totalDaysPerWeek: 3,
            sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: [.barbell]
        )
        XCTAssertEqual(selections.map(\.kind), [.barbell, .running, .cycling])
        XCTAssertEqual(selections.map(\.daysPerWeek), [1, 1, 1])
    }

    /// A12: bei nur 2 Tagen/Woche reicht selbst 1 Kraft + je 1 Tag pro
    /// Ausdauer-Disziplin nicht (3 Disziplinen noetig) - das ist ein
    /// echter `distributionConflict`, kein Fall, den `makeSelections`
    /// selbst loesen kann/soll.
    func testDistributionConflictDetectsHybridBothShortfall() {
        let conflict = GoalDrivenPlanSelectionBuilder.distributionConflict(
            goal: .hybrid, enduranceModality: .both, totalDaysPerWeek: 2
        )
        XCTAssertEqual(conflict, .init(requiredDays: 3, availableDays: 2))
    }

    func testDistributionConflictIsNilWhenEnoughDaysForAllDisciplines() {
        XCTAssertNil(GoalDrivenPlanSelectionBuilder.distributionConflict(
            goal: .hybrid, enduranceModality: .both, totalDaysPerWeek: 3
        ))
        XCTAssertNil(GoalDrivenPlanSelectionBuilder.distributionConflict(
            goal: .hybrid, enduranceModality: .running, totalDaysPerWeek: 2
        ))
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

    /// Same invariant as above, specifically with MULTIPLE equipment types
    /// selected (Epic #3.1) — days must still sum exactly, for any equipment
    /// combination and any day count, never silently dropping a day.
    func testAllSelectionsAlwaysSumToTotalDaysPerWeekWithMultipleEquipmentTypes() {
        let equipmentCombos: [Set<Equipment>] = [
            [.barbell, .dumbbell], [.dumbbell, .kettlebell], [.barbell, .dumbbell, .kettlebell]
        ]
        for goal: TrainingGoal in [.hypertrophy, .strength, .functional, .weightLoss] {
            for equipment in equipmentCombos {
                for days in 1...7 {
                    let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
                        goal: goal, enduranceModality: nil, totalDaysPerWeek: days,
                        sessionDurationMinutes: 45, experience: .intermediate, equipmentPreferences: equipment
                    )
                    let sum = selections.reduce(0) { $0 + $1.daysPerWeek }
                    XCTAssertEqual(sum, days, "goal=\(goal) equipment=\(equipment) days=\(days)")
                    XCTAssertTrue(selections.allSatisfy { $0.daysPerWeek > 0 }, "no zero-day selection should ever be produced")
                }
            }
        }
    }
}
