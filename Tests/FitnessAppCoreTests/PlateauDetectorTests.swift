import XCTest
@testable import FitnessAppCore

final class PlateauDetectorTests: XCTestCase {

    // MARK: - Helpers

    private let cal = Calendar.current

    /// Erstellt n Expositionen für eine Übung, gleichmäßig über intervalDays verteilt.
    /// e1RMs werden aus dem Array `values` genommen (circular falls kürzer).
    private func exps(
        name: String = "Bankdrücken",
        id: UUID? = UUID(),
        count: Int,
        intervalDays: Int,     // Abstand zwischen aufeinanderfolgenden Sessions
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
        // 4 Sessions × 7 Tage = 21 Tage Zeitraum → zu kurz
        let e = exps(count: 4, intervalDays: 7, e1RMs: [100, 100, 100, 100])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    func test_fourExpositions_exactly28Days_returnsFinding() {
        // Tage 0, 9, 18, 28 → Zeitraum = 28 Tage ✓
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let days = [0, 9, 18, 28].map {
            cal.date(byAdding: .day, value: $0, to: base)!
        }
        let e = days.map {
            PlateauDetector.Exposition(exerciseName: "KB", exerciseTemplateID: nil, calendarDay: $0, bestE1RM: 100)
        }
        XCTAssertNotNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Plateau erkannt

    func test_flatE1RM_returnsFinding() {
        // Kein Zuwachs → Plateau
        let e = exps(count: 6, intervalDays: 10, e1RMs: [100, 100, 100, 100, 100, 100])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.exerciseName, "Bankdrücken")
        XCTAssertEqual(f?.expositionCount, 6)
        XCTAssertEqual(f?.periodDays, 50)
        XCTAssertEqual(f?.relativeChangeFraction ?? 99, 0, accuracy: 1e-9)
    }

    func test_under2PercentImprovement_returnsFinding() {
        // 1 % Zuwachs: spät=101, früh=100 → < 2 % → Plateau
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 101, 101])
        let f = PlateauDetector.detect(expositions: e)
        XCTAssertNotNil(f)
        XCTAssertLessThan(f?.relativeChangeFraction ?? 99, PlateauDetector.minImprovementFraction)
    }

    func test_exactlyAtThreshold_returnsNil() {
        // Genau 2 % → NOT < 2 % → kein Plateau
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 102, 102])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    func test_over2PercentImprovement_returnsNil() {
        // 5 % Zuwachs → kein Plateau
        let e = exps(count: 4, intervalDays: 10, e1RMs: [100, 100, 105, 105])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Robuster Vergleich (Median)

    func test_singleOutlierAtEnd_doesNotTriggerFalsePositive() {
        // Solide Progression, aber letzter Wert fällt: Median der letzten 2 = (105+100)/2 = 102.5
        // Median der ersten 2 = 100 → Zuwachs = 2.5 % → kein Plateau
        let e = exps(count: 5, intervalDays: 10, e1RMs: [100, 100, 105, 105, 100])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    func test_singleHighOutlierAtStart_doesNotMaskPlateau() {
        // Erster Wert ungewöhnlich hoch, danach Stagnation
        // Median der ersten 2 = (150+100)/2 = 125, der letzten 2 = 100
        // Zuwachs = (100-125)/125 = −20 % → < 2 % → Plateau (Regression)
        let e = exps(count: 5, intervalDays: 10, e1RMs: [150, 100, 100, 100, 100])
        XCTAssertNotNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Deduplizierung

    func test_twoSessionsSameDay_usesMaxE1RM() {
        // Zwei Expositionen am gleichen Tag: nur die mit höherem e1RM zählt
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let dayA = base
        let dayB = cal.date(byAdding: .day, value: 15, to: base)!
        let dayC = cal.date(byAdding: .day, value: 30, to: base)!

        let id = UUID()
        let e: [PlateauDetector.Exposition] = [
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayA, bestE1RM: 80),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayA, bestE1RM: 100), // duplicate tag
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayB, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayB, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayC, bestE1RM: 100),
            .init(exerciseName: "X", exerciseTemplateID: id, calendarDay: dayC, bestE1RM: 100),
        ]
        // Nach Deduplizierung: 3 echte Tage → < minExpositions → nil
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }

    // MARK: - Identität

    func test_templateIDTakesPrecedenceOverName() {
        // Gleiche UUID, verschiedene Namen (Umbenennung) → eine Gruppe
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
        // Übung A: Plateau; Übung B: klare Progression → A liefert Finding
        let idA = UUID(), idB = UUID()
        let eA = exps(name: "Kniebeuge", id: idA, count: 4, intervalDays: 10, e1RMs: [100, 100, 100, 100])
        let eB = exps(name: "Kreuzheben", id: idB, count: 4, intervalDays: 10, e1RMs: [100, 105, 110, 115])
        let f = PlateauDetector.detect(expositions: eA + eB)
        XCTAssertNotNil(f)
        XCTAssertEqual(f?.exerciseName, "Kniebeuge")
    }

    // MARK: - Grenzwerte e1RM

    func test_zeroE1RM_notGroupedAsValidExposition() {
        // Wenn alle e1RMs 0 wären, earlyMedian == 0 → guard schlägt an → nil
        let e = exps(count: 4, intervalDays: 10, e1RMs: [0, 0, 0, 0])
        XCTAssertNil(PlateauDetector.detect(expositions: e))
    }
}
