import XCTest
@testable import FitnessAppCore

final class HealthWorkoutPlannerTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
    private var now: Date { start.addingTimeInterval(24 * 3600) }
    private let both: Set<HealthWorkoutCategory> = [.strength, .cardio]

    private func minutes(_ n: Double) -> Date {
        start.addingTimeInterval(n * 60)
    }

    private func strengthLog(_ name: String = "Kniebeuge") -> HealthWorkoutLogInput {
        HealthWorkoutLogInput(exerciseName: name, isCardio: false)
    }

    private func cardioLog(
        _ name: String,
        km: Double? = nil,
        seconds: Int? = nil,
        equipment: CardioEquipment = .none
    ) -> HealthWorkoutLogInput {
        HealthWorkoutLogInput(
            exerciseName: name, isCardio: true,
            distanceKm: km, durationSeconds: seconds, equipment: equipment
        )
    }

    /// Eine konsistente Session (`endTime = start + minutes`).
    private func candidate(
        minutes m: Int = 45,
        logs: [HealthWorkoutLogInput] = [],
        hasTimeFormat: Bool = false,
        dayIsAllCardio: Bool? = nil,
        isCompleted: Bool = true,
        isRestDay: Bool = false,
        isImported: Bool = false,
        hasExportMarker: Bool = false,
        totalSets: Int = 0,
        totalVolumeKg: Double = 0
    ) -> HealthWorkoutCandidate {
        HealthWorkoutCandidate(
            startTime: start,
            endTime: start.addingTimeInterval(Double(m) * 60),
            durationMinutes: m,
            isCompleted: isCompleted,
            isRestDay: isRestDay,
            isImported: isImported,
            hasExportMarker: hasExportMarker,
            hasTimeFormat: hasTimeFormat,
            dayIsAllCardio: dayIsAllCardio,
            logs: logs,
            totalSets: totalSets,
            totalVolumeKg: totalVolumeKg
        )
    }

    private func decide(
        _ c: HealthWorkoutCandidate,
        enabled: Set<HealthWorkoutCategory>? = nil,
        windows: [(start: Date, end: Date)] = [],
        own: [(start: Date, end: Date)] = []
    ) -> HealthWorkoutDecision {
        HealthWorkoutPlanner.decide(
            c, enabledCategories: enabled ?? both,
            existingWindows: windows, ownWindows: own, now: now
        )
    }

    private func plan(
        _ decision: HealthWorkoutDecision,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> HealthWorkoutPlan? {
        guard case .write(let plan) = decision else {
            XCTFail("erwartet .write, war \(decision)", file: file, line: line)
            return nil
        }
        return plan
    }

    // MARK: - Eligibility

    func testNotCompletedRestDayImportedAndMarkedAreIneligible() {
        let logs = [strengthLog()]
        XCTAssertEqual(decide(candidate(logs: logs, isCompleted: false)), .skip(.notCompleted))
        XCTAssertEqual(decide(candidate(logs: logs, isRestDay: true)), .skip(.restDay))
        XCTAssertEqual(decide(candidate(logs: logs, isImported: true)), .skip(.imported))
        XCTAssertEqual(decide(candidate(logs: logs, hasExportMarker: true)), .skip(.alreadyExported))
    }

    func testSkipReasonGroups() {
        XCTAssertTrue(HealthWorkoutSkipReason.imported.isIneligible)
        XCTAssertTrue(HealthWorkoutSkipReason.alreadyExported.isIneligible)
        XCTAssertFalse(HealthWorkoutSkipReason.tooShort.isIneligible)
        XCTAssertTrue(HealthWorkoutSkipReason.noContent.isNotExportable)
        XCTAssertTrue(HealthWorkoutSkipReason.tooLong.isNotExportable)
        XCTAssertTrue(HealthWorkoutSkipReason.inFuture.isNotExportable)
        XCTAssertFalse(HealthWorkoutSkipReason.alreadyInHealth.isNotExportable)
        XCTAssertFalse(HealthWorkoutSkipReason.categoryDisabled.isNotExportable)
    }

    func testSessionWithoutLogsAndWithoutTimeFormatHasNoContent() {
        XCTAssertEqual(decide(candidate()), .skip(.noContent))
    }

    func testTimeFormatSessionCountsAsContentEvenWithoutLogs() {
        XCTAssertNotNil(plan(decide(candidate(hasTimeFormat: true))))
    }

    // MARK: - Zeitfenster

    func testConsistentSessionKeepsItsEndTime() {
        let c = candidate(minutes: 45, logs: [strengthLog()])
        let p = plan(decide(c))
        XCTAssertEqual(p?.start, start)
        XCTAssertEqual(p?.end, minutes(45))
    }

    /// Der History-Editor aendert nur `durationMinutes` (und `startTime`),
    /// nie `endTime`: nach einem Edit gilt `start + durationMinutes`.
    func testStaleEndTimeAfterHistoryEditFallsBackToStartPlusDuration() {
        let c = HealthWorkoutCandidate(
            startTime: start,
            endTime: start.addingTimeInterval(9 * 3600),   // veraltet
            durationMinutes: 45,
            logs: [strengthLog()]
        )
        let p = plan(decide(c))
        XCTAssertEqual(p?.end, minutes(45))
    }

    func testEffectiveWindowHelper() {
        let consistent = HealthWorkoutPlanner.effectiveWindow(
            startTime: start, endTime: minutes(30), durationMinutes: 30
        )
        XCTAssertEqual(consistent.end, minutes(30))

        let stale = HealthWorkoutPlanner.effectiveWindow(
            startTime: start, endTime: minutes(500), durationMinutes: 30
        )
        XCTAssertEqual(stale.end, minutes(30))

        let negative = HealthWorkoutPlanner.effectiveWindow(
            startTime: start, endTime: minutes(-10), durationMinutes: 20
        )
        XCTAssertEqual(negative.end, minutes(20), "Ende vor Start ist inkonsistent")
    }

    /// `durationMinutes` ist abgerundet (`floor`); das Ende passt bis 59 s
    /// darueber. Eine Rundung (oder Toleranz) wuerde diese Grenzen verschieben.
    func testEffectiveWindowTruncationBoundaries() {
        func end(of window: (start: Date, end: Date)) -> Date { window.end }
        let atEnd = start.addingTimeInterval(45 * 60 + 59)
        XCTAssertEqual(
            end(of: HealthWorkoutPlanner.effectiveWindow(startTime: start, endTime: atEnd, durationMinutes: 45)),
            atEnd, "45:59 gehoert noch zu 45 Minuten"
        )
        XCTAssertEqual(
            end(of: HealthWorkoutPlanner.effectiveWindow(
                startTime: start, endTime: start.addingTimeInterval(46 * 60), durationMinutes: 45
            )),
            minutes(45), "46:00 waere 46 Minuten: inkonsistent"
        )
        XCTAssertEqual(
            end(of: HealthWorkoutPlanner.effectiveWindow(
                startTime: start, endTime: start.addingTimeInterval(44 * 60 + 59), durationMinutes: 45
            )),
            minutes(45), "44:59 waere 44 Minuten: inkonsistent"
        )
    }

    func testDurationBounds() {
        // 59 s: zu kurz
        let tooShort = HealthWorkoutCandidate(
            startTime: start, endTime: start.addingTimeInterval(59),
            durationMinutes: 0, logs: [strengthLog()]
        )
        XCTAssertEqual(decide(tooShort), .skip(.tooShort))

        // 1 min: gerade ok
        XCTAssertNotNil(plan(decide(candidate(minutes: 1, logs: [strengthLog()]))))

        // 0 min bei Dauer 0 und Ende == Start
        XCTAssertEqual(decide(candidate(minutes: 0, logs: [strengthLog()])), .skip(.tooShort))

        // 6 h: gerade ok, 6 h 1 min: zu lang
        XCTAssertNotNil(plan(decide(candidate(minutes: 360, logs: [strengthLog()]))))
        XCTAssertEqual(decide(candidate(minutes: 361, logs: [strengthLog()])), .skip(.tooLong))
    }

    func testFutureSessionsAreNotExportable() {
        let tolerated = HealthWorkoutCandidate(
            startTime: now.addingTimeInterval(-30 * 60),
            endTime: now.addingTimeInterval(60),   // genau an der Toleranzgrenze
            durationMinutes: 31, logs: [strengthLog()]
        )
        XCTAssertNotNil(plan(decide(tolerated)))

        let future = HealthWorkoutCandidate(
            startTime: now.addingTimeInterval(-30 * 60),
            endTime: now.addingTimeInterval(120),
            durationMinutes: 32, logs: [strengthLog()]
        )
        XCTAssertEqual(decide(future), .skip(.inFuture))

        let startsLater = HealthWorkoutCandidate(
            startTime: now.addingTimeInterval(3600),
            endTime: now.addingTimeInterval(3600 + 30 * 60),
            durationMinutes: 30, logs: [strengthLog()]
        )
        XCTAssertEqual(decide(startsLater), .skip(.inFuture))
    }

    /// Reihenfolge laut Doku: Eligibility -> Inhalt -> Zeitfenster -> Kategorie.
    func testSkipReasonsAreCheckedInTheDocumentedOrder() {
        // Zu kurz schlaegt "Kategorie aus".
        let shortRun = candidate(minutes: 0, logs: [cardioLog("Freier Lauf", km: 1, seconds: 30)])
        XCTAssertEqual(decide(shortRun, enabled: [.strength]), .skip(.tooShort))
        // Kein Inhalt schlaegt "zu kurz".
        XCTAssertEqual(decide(candidate(minutes: 0)), .skip(.noContent))
        // Marker schlaegt Inhalt.
        XCTAssertEqual(decide(candidate(hasExportMarker: true)), .skip(.alreadyExported))
        // Import schlaegt Marker.
        XCTAssertEqual(
            decide(candidate(logs: [strengthLog()], isImported: true, hasExportMarker: true)),
            .skip(.imported)
        )
    }

    // MARK: - Kraft

    func testStrengthSessionPlan() {
        let c = candidate(logs: [strengthLog(), strengthLog("Bankdruecken")], totalSets: 12, totalVolumeKg: 4200)
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .strength)
        XCTAssertEqual(p?.category, .strength)
        XCTAssertEqual(p?.isIndoor, true)
        XCTAssertEqual(p?.totalSets, 12)
        XCTAssertEqual(p?.totalVolumeKg, 4200)
        XCTAssertNil(p?.distanceKm)
    }

    func testTimeFormatSessionIsStrengthUnlessTheDayIsAllCardio() {
        XCTAssertEqual(plan(decide(candidate(hasTimeFormat: true, dayIsAllCardio: nil)))?.activity, .strength)
        XCTAssertEqual(plan(decide(candidate(hasTimeFormat: true, dayIsAllCardio: false)))?.activity, .strength)

        let cardioDay = plan(decide(candidate(hasTimeFormat: true, dayIsAllCardio: true)))
        XCTAssertEqual(cardioDay?.activity, .mixedCardio)
        XCTAssertEqual(cardioDay?.category, .cardio)
        XCTAssertNil(cardioDay?.isIndoor)
    }

    // MARK: - Cardio: Art, Ort, Distanz

    func testOutdoorRunWithDistanceAndPace() {
        let c = candidate(minutes: 30, logs: [cardioLog("Freier Lauf", km: 5, seconds: 1800)])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertEqual(p?.category, .cardio)
        XCTAssertEqual(p?.isIndoor, false)
        XCTAssertEqual(p?.distanceKm, 5)
        XCTAssertEqual(p?.totalDistanceKm, 5)
        XCTAssertEqual(p?.averagePaceMinPerKm ?? 0, 6.0, accuracy: 0.0001)
        XCTAssertNil(p?.totalSets)
    }

    /// Vorher wurde ein reines Cardio-Training OHNE Distanz als Krafttraining
    /// nach Health geschrieben.
    func testCardioWithoutDistanceStaysCardio() {
        let c = candidate(logs: [cardioLog("Laufband")])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertEqual(p?.isIndoor, true)
        XCTAssertNil(p?.distanceKm)
        XCTAssertNil(p?.averagePaceMinPerKm)
    }

    func testCyclingIsNotWrittenAsRunningAndHasNoDistanceSample() {
        let outdoor = plan(decide(candidate(logs: [cardioLog("Radfahren (outdoor)", km: 20, seconds: 2400)])))
        XCTAssertEqual(outdoor?.activity, .cycling)
        XCTAssertEqual(outdoor?.isIndoor, false)
        XCTAssertNil(outdoor?.distanceKm, "Rad-Distanz hat einen eigenen Health-Typ und wird nicht als Sample geschrieben")
        XCTAssertEqual(outdoor?.totalDistanceKm, 20, "die Strecke bleibt in den Metadaten")

        let ergometer = plan(decide(candidate(logs: [cardioLog("Fahrradergometer", seconds: 1800)])))
        XCTAssertEqual(ergometer?.activity, .cycling)
        XCTAssertEqual(ergometer?.isIndoor, true)
    }

    func testMachinesAndSwimmingAndCustomExercisesAreMixedCardio() {
        let rowing = plan(decide(candidate(logs: [cardioLog("Rudermaschine", seconds: 1200)])))
        XCTAssertEqual(rowing?.activity, .mixedCardio)
        XCTAssertEqual(rowing?.isIndoor, true)

        let elliptical = plan(decide(candidate(logs: [cardioLog("Crosstrainer", seconds: 1200)])))
        XCTAssertEqual(elliptical?.activity, .mixedCardio)
        XCTAssertEqual(elliptical?.isIndoor, true)

        let swimming = plan(decide(candidate(logs: [cardioLog("Schwimmen", seconds: 1200)])))
        XCTAssertEqual(swimming?.activity, .mixedCardio)
        XCTAssertNil(swimming?.isIndoor, "Pool oder Freiwasser ist unbekannt")

        let custom = plan(decide(candidate(logs: [cardioLog("Mein eigenes Cardio", seconds: 1200)])))
        XCTAssertEqual(custom?.activity, .mixedCardio)
        XCTAssertNil(custom?.isIndoor)
    }

    /// Das vom Nutzer gesetzte Geraet schlaegt den Namen.
    func testEquipmentOverridesTheName() {
        let easyRunOnTreadmill = plan(decide(candidate(
            logs: [cardioLog("Easy Run", km: 5, seconds: 1800, equipment: .treadmill)]
        )))
        XCTAssertEqual(easyRunOnTreadmill?.activity, .running)
        XCTAssertEqual(easyRunOnTreadmill?.isIndoor, true)

        let walkOnTreadmill = plan(decide(candidate(
            logs: [cardioLog("Gehen / Einlaufen", seconds: 900, equipment: .treadmill)]
        )))
        XCTAssertEqual(walkOnTreadmill?.activity, .walking)
        XCTAssertEqual(walkOnTreadmill?.isIndoor, true)

        let customOnTreadmill = plan(decide(candidate(
            logs: [cardioLog("Mein eigenes Cardio", seconds: 900, equipment: .treadmill)]
        )))
        XCTAssertEqual(customOnTreadmill?.activity, .running)

        let customBike = plan(decide(candidate(
            logs: [cardioLog("Mein eigenes Cardio", seconds: 900, equipment: .bikeOutdoor)]
        )))
        XCTAssertEqual(customBike?.activity, .cycling)
        XCTAssertEqual(customBike?.isIndoor, false)

        let runOnErgometer = plan(decide(candidate(
            logs: [cardioLog("Freier Lauf", seconds: 900, equipment: .ergometer)]
        )))
        XCTAssertEqual(runOnErgometer?.activity, .cycling)
        XCTAssertEqual(runOnErgometer?.isIndoor, true)

        let customRower = plan(decide(candidate(
            logs: [cardioLog("Mein eigenes Cardio", seconds: 900, equipment: .rowingMachine)]
        )))
        XCTAssertEqual(customRower?.activity, .mixedCardio)
        XCTAssertEqual(customRower?.isIndoor, true)
    }

    func testMixedIndoorAndOutdoorRunsHaveUnknownLocation() {
        let c = candidate(logs: [
            cardioLog("Freier Lauf", km: 3, seconds: 900),
            cardioLog("Laufband", km: 3, seconds: 900),
        ])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertNil(p?.isIndoor)
    }

    // MARK: - Cardio: Gewinner-Modalitaet

    func testModalityWithTheMostTimeWins() {
        let c = candidate(logs: [
            cardioLog("Freier Lauf", km: 2, seconds: 600),
            cardioLog("Radfahren (outdoor)", km: 15, seconds: 1200),
        ])
        XCTAssertEqual(plan(decide(c))?.activity, .cycling)
    }

    /// Gleichstand entscheidet die feste Reihenfolge (Laufen vor Rad vor
    /// Gehen) — unabhaengig von der Log-Reihenfolge, damit Live-Pfad und
    /// Export nie voneinander abweichen.
    func testTieIsBrokenDeterministically() {
        let run = cardioLog("Freier Lauf", seconds: 900)
        let bike = cardioLog("Radfahren (outdoor)", seconds: 900)
        let walk = cardioLog("Gehen / Einlaufen", seconds: 900)

        XCTAssertEqual(plan(decide(candidate(logs: [run, bike, walk])))?.activity, .running)
        XCTAssertEqual(plan(decide(candidate(logs: [walk, bike, run])))?.activity, .running)
        XCTAssertEqual(plan(decide(candidate(logs: [walk, bike])))?.activity, .cycling)
        XCTAssertEqual(plan(decide(candidate(logs: [bike, walk])))?.activity, .cycling)
    }

    func testWithoutAnyDurationTheDistanceDecides() {
        let c = candidate(logs: [
            cardioLog("Freier Lauf", km: 3),
            cardioLog("Radfahren (outdoor)", km: 10),
        ])
        XCTAssertEqual(plan(decide(c))?.activity, .cycling)

        let equal = candidate(logs: [
            cardioLog("Radfahren (outdoor)", km: 5),
            cardioLog("Freier Lauf", km: 5),
        ])
        XCTAssertEqual(plan(decide(equal))?.activity, .running)
    }

    /// Laufen und Gehen (Einlaufen) teilen sich den Distanz-Typ; die Pace
    /// kommt aus derselben Menge.
    func testRunAndWarmupWalkShareDistanceAndPace() {
        let c = candidate(minutes: 40, logs: [
            cardioLog("Gehen / Einlaufen", km: 1, seconds: 600),
            cardioLog("Freier Lauf", km: 4, seconds: 1800),
        ])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertEqual(p?.distanceKm, 5)
        XCTAssertEqual(p?.totalDistanceKm, 5)
        // 2400 s = 40 min fuer 5 km -> 8,0 min/km
        XCTAssertEqual(p?.averagePaceMinPerKm ?? 0, 8.0, accuracy: 0.0001)
    }

    func testNonFiniteOrNegativeDistancesAreIgnored() {
        let c = candidate(logs: [
            cardioLog("Freier Lauf", km: .infinity, seconds: 600),
            cardioLog("Freier Lauf", km: -2, seconds: 600),
        ])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertNil(p?.distanceKm)
    }

    func testWalkingOnlySessionHasDistanceAndPace() {
        let c = candidate(minutes: 30, logs: [cardioLog("Gehen / Einlaufen", km: 3, seconds: 1800)])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .walking)
        XCTAssertEqual(p?.distanceKm, 3)
        XCTAssertEqual(p?.averagePaceMinPerKm ?? 0, 10.0, accuracy: 0.0001)
    }

    /// Das Geraet "Laufband" gewinnt auch gegen einen Rad-Namen.
    func testTreadmillEquipmentOverridesACyclingName() {
        let p = plan(decide(candidate(logs: [
            cardioLog("Radfahren (outdoor)", seconds: 900, equipment: .treadmill)
        ])))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertEqual(p?.isIndoor, true)
    }

    /// Ein Zeitformat folgt allein dem Tages-Flag; vorhandene Cardio-Logs
    /// aendern daran nichts.
    func testTimeFormatFollowsTheDayFlagEvenWithCardioLogs() {
        let logs = [cardioLog("Freier Lauf", km: 2, seconds: 600)]
        XCTAssertEqual(
            plan(decide(candidate(logs: logs, hasTimeFormat: true, dayIsAllCardio: false)))?.activity,
            .strength
        )
        XCTAssertEqual(
            plan(decide(candidate(logs: logs, hasTimeFormat: true, dayIsAllCardio: true)))?.category,
            .cardio
        )
    }

    // MARK: - Cardio: teilweise gefuellte Logs

    /// Ein Einlaufen nur mit Dauer neben einem Lauf nur mit km: die Dauer ist
    /// nicht vergleichbar, die Distanz entscheidet — und es entsteht keine
    /// Pace aus Zeit und Strecke verschiedener Logs.
    func testDurationOnlyWalkNextToDistanceOnlyRunDecidesByDistance() {
        let c = candidate(minutes: 40, logs: [
            cardioLog("Gehen / Einlaufen", seconds: 300),
            cardioLog("Easy Run", km: 8),
        ])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertEqual(p?.distanceKm, 8)
        XCTAssertNil(p?.averagePaceMinPerKm, "kein Log hat km UND Dauer")
    }

    func testPaceComesOnlyFromLogsWithDistanceAndDuration() {
        // Einlaufen ohne km zaehlt nicht in die Pace: 30 min / 5 km = 6,0.
        let c = candidate(minutes: 35, logs: [
            cardioLog("Gehen / Einlaufen", seconds: 300),
            cardioLog("Freier Lauf", km: 5, seconds: 1800),
        ])
        let p = plan(decide(c))
        XCTAssertEqual(p?.activity, .running)
        XCTAssertEqual(p?.averagePaceMinPerKm ?? 0, 6.0, accuracy: 0.0001)
        XCTAssertEqual(p?.distanceKm, 5)

        // Drei Intervalle a 0,4 km, nur zwei mit Dauer: 180 s / 0,8 km = 3,75.
        let intervals = candidate(minutes: 20, logs: [
            cardioLog("Intervalle", km: 0.4, seconds: 90),
            cardioLog("Intervalle", km: 0.4, seconds: 90),
            cardioLog("Intervalle", km: 0.4),
        ])
        let q = plan(decide(intervals))
        XCTAssertEqual(q?.distanceKm ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(q?.averagePaceMinPerKm ?? 0, 3.75, accuracy: 0.0001)
    }

    /// Die Haupt-Aktivitaet gewinnt, auch wenn daneben ein winziger Log nur mit
    /// Distanz steht: 60 min Rad (nur Dauer) plus 0,3 km Spaziergang bleibt Rad.
    func testMainActivityByTimeWinsOverATinyDistanceOnlyLog() {
        let bikePlusWalk = candidate(minutes: 62, logs: [
            cardioLog("Radfahren (outdoor)", seconds: 3600),
            cardioLog("Gehen / Einlaufen", km: 0.3),
        ])
        let p = plan(decide(bikePlusWalk))
        XCTAssertEqual(p?.activity, .cycling)
        XCTAssertNil(p?.distanceKm)

        let bikePlusRun = candidate(minutes: 65, logs: [
            cardioLog("Radfahren (outdoor)", seconds: 3600),
            cardioLog("Freier Lauf", km: 5),
        ])
        XCTAssertEqual(plan(decide(bikePlusRun))?.activity, .cycling)
    }

    // MARK: - Mischtage

    func testMixedDayIsCardioFromHalfOfTheSessionOnward() {
        // 60 min Session, 1800 s = genau die Haelfte
        let cardio = candidate(minutes: 60, logs: [
            strengthLog(),
            cardioLog("Freier Lauf", km: 4, seconds: 1800),
        ])
        XCTAssertEqual(plan(decide(cardio))?.activity, .running)

        let strength = candidate(minutes: 60, logs: [
            strengthLog(),
            cardioLog("Freier Lauf", km: 4, seconds: 1799),
        ], totalSets: 8, totalVolumeKg: 900)
        let p = plan(decide(strength))
        XCTAssertEqual(p?.activity, .strength)
        XCTAssertEqual(p?.totalSets, 8)
    }

    func testMixedDayWithoutCardioDurationsStaysStrength() {
        let c = candidate(minutes: 60, logs: [strengthLog(), cardioLog("Freier Lauf", km: 2)])
        XCTAssertEqual(plan(decide(c))?.activity, .strength)
    }

    // MARK: - Kategorien

    func testDisabledCategoryIsSkipped() {
        let run = candidate(logs: [cardioLog("Freier Lauf", km: 5, seconds: 1800)])
        let lift = candidate(logs: [strengthLog()])

        XCTAssertEqual(decide(run, enabled: [.strength]), .skip(.categoryDisabled))
        XCTAssertNotNil(plan(decide(lift, enabled: [.strength])))
        XCTAssertEqual(decide(lift, enabled: [.cardio]), .skip(.categoryDisabled))
        XCTAssertNotNil(plan(decide(run, enabled: [.cardio])))
        XCTAssertEqual(decide(lift, enabled: []), .skip(.categoryDisabled))
    }

    // MARK: - Abgleich mit Health

    func testSessionCoveredByAnExistingWorkoutIsAlreadyInHealth() {
        let c = candidate(minutes: 45, logs: [strengthLog()])
        XCTAssertEqual(
            decide(c, windows: [(start: minutes(2), end: minutes(47))]),
            .skip(.alreadyInHealth)
        )
    }

    /// Ein kurzes Fremd-Workout (z.B. 10-min-Walk der Uhr) innerhalb einer
    /// langen Session darf sie NICHT blockieren (Normierung auf die
    /// Session-Dauer, nicht auf die kuerzere).
    func testShortForeignWorkoutInsideALongSessionDoesNotBlockIt() {
        let c = candidate(minutes: 70, logs: [strengthLog()])
        XCTAssertNotNil(plan(decide(c, windows: [(start: minutes(20), end: minutes(30))])))
    }

    func testSessionInsideALongerForeignWorkoutIsAlreadyInHealth() {
        let c = candidate(minutes: 30, logs: [strengthLog()])
        XCTAssertEqual(
            decide(c, windows: [(start: minutes(-60), end: minutes(120))]),
            .skip(.alreadyInHealth)
        )
    }

    func testAdjacentWorkoutsDoNotCountAsOverlap() {
        let c = candidate(minutes: 45, logs: [strengthLog()])
        XCTAssertNotNil(plan(decide(c, windows: [
            (start: minutes(-45), end: minutes(0)),
            (start: minutes(45), end: minutes(90)),
        ])))
    }

    /// Ein ausgeschalteter Cardio-Schalter hat Vorrang: die Session taucht
    /// dann nicht als "bereits in Health" auf.
    func testCategorySwitchIsCheckedBeforeTheHealthComparison() {
        let run = candidate(logs: [cardioLog("Freier Lauf", km: 5, seconds: 2700)])
        XCTAssertEqual(
            decide(run, enabled: [.strength], windows: [(start: start, end: minutes(45))]),
            .skip(.categoryDisabled)
        )
    }

    // MARK: - Abgleich: nach dem Beenden im Verlauf bearbeitete Sessions

    /// Live geschrieben (10 min), danach im Verlauf auf 60 min verlaengert:
    /// `endTime` bleibt das alte Ende; das alte Health-Fenster wird erkannt.
    func testSessionWithEditedDurationIsRecognisedByItsRecordedWindow() {
        let edited = HealthWorkoutCandidate(
            startTime: start, endTime: minutes(10), durationMinutes: 60, logs: [strengthLog()]
        )
        let live = [(start: start, end: minutes(10))]
        XCTAssertEqual(decide(edited, windows: live, own: live), .skip(.alreadyInHealth))
    }

    /// Live geschrieben, danach um einen Tag zurueckdatiert: das alte Ende ist
    /// noch da, der alte Beginn ergibt sich aus `endTime - durationMinutes`.
    func testSessionWithEditedStartIsRecognisedByItsRecordedWindow() {
        let backdated = HealthWorkoutCandidate(
            startTime: start.addingTimeInterval(-24 * 3600),
            endTime: minutes(60),
            durationMinutes: 60,
            logs: [strengthLog()]
        )
        let live = [(start: start, end: minutes(60))]
        XCTAssertEqual(decide(backdated, windows: live, own: live), .skip(.alreadyInHealth))
    }

    /// Die vermuteten urspruenglichen Fenster gelten NUR gegen Deltiqs eigene
    /// Workouts: Ein fremdes Workout dort (z.B. ein Lauf direkt vor der Session)
    /// darf eine unbeteiligte Session nicht dauerhaft als "schon in Health"
    /// markieren lassen.
    func testRecordedWindowsNeverMatchForeignWorkouts() {
        // Dauer von 30 auf 90 min geaendert, endTime veraltet (start + 30): Die
        // Vermutung [endTime - 90 min, endTime] reicht 60 min vor den Start und
        // laege zu 2/3 in einem fremden Workout davor.
        let edited = HealthWorkoutCandidate(
            startTime: minutes(60), endTime: minutes(90), durationMinutes: 90, logs: [strengthLog()]
        )
        let foreign = [(start: minutes(0), end: minutes(60))]
        XCTAssertNotNil(plan(decide(edited, windows: foreign, own: [])))

        // endTime == startTime bei Dauer > 0 (z.B. nachgetragen): die abgeleitete
        // Vermutung liegt komplett vor der Session.
        let logged = HealthWorkoutCandidate(
            startTime: minutes(60), endTime: minutes(60), durationMinutes: 30, logs: [strengthLog()]
        )
        let before = [(start: minutes(10), end: minutes(60))]
        XCTAssertNotNil(plan(decide(logged, windows: before, own: [])))
    }

    /// Ohne Workout im urspruenglichen Zeitraum bleibt auch eine bearbeitete
    /// Session exportierbar (kein Pauschal-Skip).
    func testEditedSessionWithoutAWorkoutInItsRecordedWindowIsWritten() {
        let edited = HealthWorkoutCandidate(
            startTime: start, endTime: minutes(10), durationMinutes: 60, logs: [strengthLog()]
        )
        let farAway = [(
            start: start.addingTimeInterval(-3 * 24 * 3600),
            end: start.addingTimeInterval(-3 * 24 * 3600 + 3600)
        )]
        XCTAssertNotNil(plan(decide(edited, windows: farAway, own: farAway)))
    }

    // MARK: - Bibliothek

    /// Ein neuer Cardio-Eintrag in `ExerciseLibraryData` ohne Zeile in der
    /// Zuordnung wuerde still als `mixedCardio` geschrieben.
    func testEveryLibraryCardioExerciseHasAnExplicitMapping() {
        let cardioSpecs = ExerciseLibraryData.all.filter { $0.isCardio }
        XCTAssertFalse(cardioSpecs.isEmpty)
        for spec in cardioSpecs {
            XCTAssertNotNil(spec.localizationKey, "\(spec.name): ohne localizationKey nicht zuordenbar")
            XCTAssertTrue(
                HealthWorkoutPlanner.hasExplicitModality(forExerciseName: spec.name),
                "\(spec.name): keine ausdrueckliche Health-Zuordnung"
            )
        }
    }

    func testUnknownNameHasNoExplicitMapping() {
        XCTAssertFalse(HealthWorkoutPlanner.hasExplicitModality(forExerciseName: "Mein eigenes Cardio"))
        XCTAssertFalse(HealthWorkoutPlanner.hasExplicitModality(forExerciseName: "Kniebeuge"))
    }

    /// Alle 14 Bibliotheks-Cardio-Eintraege mit ihrer erwarteten Art und
    /// ihrem Ort (nur Dauer geloggt, kein Geraet) — pinnt die Zuordnung, nicht
    /// nur ihre Existenz.
    func testLibraryCardioExercisesMapToTheExpectedActivityAndLocation() {
        let expected: [String: (activity: HealthWorkoutActivity, indoor: Bool?)] = [
            "exercise.name.run":             (.running, false),
            "exercise.name.easyRun":         (.running, false),
            "exercise.name.longRun":         (.running, false),
            "exercise.name.intervals":       (.running, nil),
            "exercise.name.runInterval":     (.running, nil),
            "exercise.name.treadmill":       (.running, true),
            "exercise.name.warmupWalk":      (.walking, nil),
            "exercise.name.cycling":         (.cycling, false),
            "exercise.name.cyclingInterval": (.cycling, nil),
            "exercise.name.stationaryBike":  (.cycling, true),
            "exercise.name.rowingMachine":   (.mixedCardio, true),
            "exercise.name.elliptical":      (.mixedCardio, true),
            "exercise.name.stairStepper":    (.mixedCardio, true),
            "exercise.name.swimming":        (.mixedCardio, nil),
        ]
        let cardioSpecs = ExerciseLibraryData.all.filter { $0.isCardio }
        XCTAssertEqual(
            Set(cardioSpecs.compactMap { $0.localizationKey }), Set(expected.keys),
            "Neue oder entfernte Cardio-Eintraege: Zuordnung in diesem Test und im Planer pruefen"
        )
        for spec in cardioSpecs {
            guard let key = spec.localizationKey, let want = expected[key] else { continue }
            let p = plan(decide(candidate(logs: [cardioLog(spec.name, seconds: 900)])))
            XCTAssertEqual(p?.activity, want.activity, "\(spec.name): Art")
            XCTAssertEqual(p?.isIndoor, want.indoor, "\(spec.name): Ort")
        }
    }

    // MARK: - Export-Auswahl

    private func c(
        _ name: String,
        start s: Double,
        minutes m: Int,
        logs: [HealthWorkoutLogInput]? = nil
    ) -> HealthWorkoutCandidate {
        HealthWorkoutCandidate(
            startTime: minutes(s),
            endTime: minutes(s + Double(m)),
            durationMinutes: m,
            logs: logs ?? [strengthLog(name)]
        )
    }

    private func select(
        _ candidates: [HealthWorkoutCandidate],
        enabled: Set<HealthWorkoutCategory>? = nil,
        health: [(start: Date, end: Date)] = [],
        own: [(start: Date, end: Date)] = []
    ) -> HealthExportSelection {
        HealthWorkoutPlanner.selectForExport(
            candidates, enabledCategories: enabled ?? both,
            healthWindows: health, ownWindows: own, now: now
        )
    }

    /// Die zweite von zwei sich ueberlappenden Sessions wird weder geschrieben
    /// noch als "schon in Health" gemeldet (sonst bekaeme sie einen Marker, obwohl
    /// die erste vielleicht nie geschrieben wird).
    func testSelectionDefersASessionThatOnlyOverlapsAPlannedOne() {
        let newer = c("A", start: 0, minutes: 60)
        let older = c("B", start: 10, minutes: 60)
        let result = select([newer, older])
        XCTAssertEqual(result.toWrite.map(\.index), [0])
        XCTAssertEqual(result.alreadyInHealth, [])
        XCTAssertEqual(result.deferred, 1)
    }

    func testSelectionTreatsIdenticalStartsAsOneWorkout() {
        let result = select([c("A", start: 0, minutes: 45), c("B", start: 0, minutes: 45)])
        XCTAssertEqual(result.toWrite.map(\.index), [0])
        XCTAssertEqual(result.deferred, 1)
    }

    func testSelectionReportsOnlyRealHealthOverlapsAsAlreadyInHealth() {
        let covered = c("A", start: 0, minutes: 45)
        let free = c("B", start: 200, minutes: 45)
        let result = select([covered, free], health: [(start: minutes(1), end: minutes(46))])
        XCTAssertEqual(result.alreadyInHealth, [0])
        XCTAssertEqual(result.toWrite.map(\.index), [1])
        XCTAssertEqual(result.deferred, 0)
    }

    func testSelectionCountsNotExportableAndKeepsAdjacentSessions() {
        let short = c("A", start: 0, minutes: 0)
        let first = c("B", start: 100, minutes: 45)
        let adjacent = c("C", start: 145, minutes: 45)
        let result = select([short, first, adjacent])
        XCTAssertEqual(result.notExportable, 1)
        XCTAssertEqual(result.toWrite.map(\.index), [1, 2])
    }

    func testSelectionPassesOwnWindowsToTheRecordedWindowCheck() {
        let edited = HealthWorkoutCandidate(
            startTime: start, endTime: minutes(10), durationMinutes: 60, logs: [strengthLog()]
        )
        let live = [(start: start, end: minutes(10))]
        XCTAssertEqual(select([edited], health: live, own: live).alreadyInHealth, [0])
        XCTAssertEqual(select([edited], health: live, own: []).toWrite.map(\.index), [0])
    }

    // MARK: - Abfragezeitraum

    func testQueryRangeIsNilWithoutCandidates() {
        XCTAssertNil(HealthWorkoutPlanner.queryRange(for: []))
    }

    func testQueryRangeCoversEffectiveAndRecordedWindows() {
        // Am 28.9. liegt der bearbeitete Beginn, das alte Ende am 1.10.: Das
        // vermutete Original-Fenster liegt Tage hinter dem effektiven.
        let day: TimeInterval = 24 * 3600
        let edited = HealthWorkoutCandidate(
            startTime: start.addingTimeInterval(-3 * day),
            endTime: start.addingTimeInterval(60 * 60),
            durationMinutes: 60,
            logs: [strengthLog()]
        )
        let range = HealthWorkoutPlanner.queryRange(for: [edited])
        let margin = HealthWorkoutPlanner.queryMarginSeconds
        XCTAssertEqual(range?.start, start.addingTimeInterval(-3 * day - margin))
        XCTAssertEqual(range?.end, start.addingTimeInterval(60 * 60 + margin))
    }

    func testQueryRangeSpansAllCandidatesWithMargin() {
        let early = c("A", start: 0, minutes: 30)
        let late = c("B", start: 5 * 24 * 60, minutes: 30)
        let range = HealthWorkoutPlanner.queryRange(for: [early, late])
        let margin = HealthWorkoutPlanner.queryMarginSeconds
        XCTAssertEqual(range?.start, start.addingTimeInterval(-margin))
        XCTAssertEqual(range?.end, minutes(5 * 24 * 60 + 30).addingTimeInterval(margin))
    }
}
