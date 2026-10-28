import XCTest
@testable import FitnessAppCore

final class PlateauDetectorTests: XCTestCase {

    // MARK: - Helpers

    private let cal = Calendar.current

    private func exps(
        name: String = "Bankdrücken",
        id: UUID? = UUID(),
        count: Int,
        intervalDays: Int,
        startOffsetDays: Int = 0,
        e1RMs: [Double]
    ) -> [PlateauDetector.Exposition] {
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return (0..<count).map { i in
            let day = cal.date(byAdding: .day, value: startOffsetDays + i * intervalDays, to: base)!
            return PlateauDetector.Exposition(
                exerciseName: name,
                exerciseTemplateID: id,
                calendarDay: day,
                bestE1RM: e1RMs[i % e1RMs.count]
            )
        }
    }

    // MARK: - Mindestanzahl Expositionen

    func test_noExpositions_returnsNil() {
        XCTAssertNil(PlateauDetector.detect(expositions: []))
    }

    func test_threeExpositions_returnsNil() {
        let e = exps(count: 3, intervalDays: 14, e1RMs: [100, 100, 100])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Mindestzeitraum

    func test_fourExpositions_periodUnder28Days_returnsNil() {
        let e = exps(count: 4, intervalDays: 7, e1RMs: [100, 100, 100, 100])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    func test_fourExpositions_exactly28Days_returnsFinding() {
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let days = [0, 9, 18, 28].map { cal.date(byAdding: .day, value: $0, to: base)! }
        let e = days.map {
            PlateauDetector.Exposition(exerciseName: "KB", exerciseTemplateID: nil, calendarDay: $0, bestE1RM: 100)
        }
        XCTAssertNotNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Stagnation erkannt

    func test_flatE1RM_returnsStagnation() {
        let e = exps(count: 6, intervalDays: 10, e1RMs: [100, 100, 100, 100, 100, 100])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .stagnation)
        XCTAssertEqual(f?.exerciseName, "Bankdrücken")
        XCTAssertEqual(f?.expositionCount, 6)
        XCTAssertEqual(f?.periodDays, 50)
        XCTAssertEqual(f?.relativeChangeFraction ?? 99, 0, accuracy: 1e-9)
    }

    func test_under2PercentImprovement_returnsStagnation() {
        // 1 % Zuwachs: spät=101, früh=100 → < 2 % → Stagnation
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 101, 101])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .stagnation)
        XCTAssertLessThan(f?.relativeChangeFraction ?? 99, PlateauDetector.minImprovementFraction)
    }

    func test_exactlyAtThreshold_returnsNil() {
        // Genau 2 % → NOT < 2 % → kein Befund
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 102, 102])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    func test_over2PercentImprovement_returnsNil() {
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 105, 105])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Regression (kein Plateau-Coaching)

    func test_slightDrop_under10Percent_returnsStagnation() {
        // 5 % Rückgang → innerhalb Stagnationsband → .stagnation
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 95, 95])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .stagnation)
    }

    func test_clearRegression_over10Percent_returnsRegressionStatus() {
        // 20 % Rückgang → Regression, nicht Stagnation
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 80, 80])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .regression)
    }

    func test_exactRegressionThreshold_isStagnation() {
        // Genau −10 % → NOT < −regressionThreshold → .stagnation (Grenzfall liegt im Stagnationsband)
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 90, 90])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .stagnation)
    }

    func test_slightlyPastRegressionThreshold_isRegression() {
        // −11 % → .regression
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 89, 89])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .regression)
    }

    // MARK: - Robuster Vergleich (Median)

    func test_singleOutlierAtEnd_doesNotTriggerFalsePositive() {
        // Solide Progression, letzter Wert fällt: Median der letzten 2 = (105+100)/2 = 102.5
        // Median der ersten 2 = 100 → Zuwachs = 2.5 % → kein Befund
        let e = exps(count: 5, intervalDays: 10, e1RMs: [100, 100, 105, 105, 100])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    func test_singleHighOutlierAtStart_isRegression() {
        // Erster Wert ungewöhnlich hoch, danach anhaltender Rückgang
        // Median der ersten 2 = (150+100)/2 = 125, der letzten 2 = 100
        // relChange = (100−125)/125 = −20 % → .regression (nicht Stagnation)
        let e = exps(count: 5, intervalDays: 10, e1RMs: [150, 100, 100, 100, 100])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.status, .regression)
    }

    // MARK: - Deduplizierung

    func test_twoSessionsSameDay_usesMaxE1RM() {
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let dayA = base
        let dayB = cal.date(byAdding: .day, value: 15, to: base)!
        let dayC = cal.date(byAdding: .day, value: 30, to: base)!
        let id = UUID()
        // Je 2 Einträge pro Tag → nach Deduplizierung 3 echte Tage → < minExpositions → nil
        let e: [PlateauDetector.Exposition] = [
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayA, bestE1RM: 80),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayA, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayB, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayB, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayC, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayC, bestE1RM: 100),
        ]
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Identität

    func test_templateIDTakesPrecedenceOverName() {
        let id = UUID()
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let e: [PlateauDetector.Exposition] = (0..<4).map { i in
            .init(
                exerciseName: i < 2 ? "Bankdrücken" : "Bench Press",
                exerciseTemplateID: id,
                calendarDay: cal.date(byAdding: .day, value: i * 10, to: base)!,
                bestE1RM: 100
            )
        }
        XCTAssertNotNil(PlateauDetector.detect(expositions: e))
    }

    func test_differentExercises_evaluatedSeparately() {
        let idA = UUID(), idB = UUID()
        let eA = exps(name: "Kniebeuge", id: idA, count: 4, intervalDays: 10, e1RMs: [100, 100, 100, 100])
        let eB = exps(name: "Kreuzheben", id: idB, count: 4, intervalDays: 10, e1RMs: [100, 105, 110, 115])
        let f = PlateauDetector.detect(expositions: eA + eB)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.exerciseName, "Kniebeuge")
    }

    // MARK: - Deterministisch

    func test_twoPlateau_longerPeriodWins() {
        let idA = UUID(), idB = UUID()
        // Übung A: 6 Sessions × 10 Tage = 50 Tage Zeitraum
        let eA = exps(name: "Kniebeuge", id: idA, count: 6, intervalDays: 10, e1RMs: [100, 100, 100, 100, 100, 100])
        // Übung B: 4 Sessions × 10 Tage = 30 Tage Zeitraum
        let eB = exps(name: "Schulterdrücken", id: idB, count: 4, intervalDays: 10, e1RMs: [80, 80, 80, 80])
        let f = PlateauDetector.detect(expositions: eA + eB)
        XCTAssertEqual(f?.exerciseName, "Kniebeuge", "Die Übung mit längerem Zeitraum soll gewinnen")
    }

    func test_twoPlateau_equalPeriod_alphabeticTiebreaker() {
        let idA = UUID(), idB = UUID()
        // Gleicher Zeitraum (30 Tage) → alphabetischer Tiebreaker
        let eA = exps(name: "Schulterdrücken", id: idA, count: 4, intervalDays: 10, e1RMs: [100, 100, 100, 100])
        let eB = exps(name: "Kniebeuge",       id: idB, count: 4, intervalDays: 10, e1RMs: [80, 80, 80, 80])
        let f = PlateauDetector.detect(expositions: eA + eB)
        XCTAssertEqual(f?.exerciseName, "Kniebeuge", "Alphabetisch früherer Name soll Tiebreaker gewinnen")
    }

    func test_inputOrderIndependent() {
        // Dasselbe Ergebnis unabhängig von der Reihenfolge der Eingabedaten
        let idA = UUID(), idB = UUID()
        let eA = exps(name: "Bankdrücken", id: idA, count: 6, intervalDays: 10, e1RMs: [100, 100, 100, 100, 100, 100])
        let eB = exps(name: "Kniebeuge",   id: idB, count: 4, intervalDays: 10, e1RMs: [80, 80, 80, 80])
        let f1 = PlateauDetector.detect(expositions: eA + eB)
        let f2 = PlateauDetector.detect(expositions: eB + eA)
        XCTAssertEqual(f1?.exerciseName, f2?.exerciseName)
        XCTAssertEqual(f1?.periodDays,   f2?.periodDays)
    }

    // MARK: - Grenzwerte e1RM

    func test_zeroE1RM_notValidExposition() {
        // earlyMedian == 0 → guard schlägt an → nil
        let e = exps(count: 4, intervalDays: 10, e1RMs: [0, 0, 0, 0])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }
}
