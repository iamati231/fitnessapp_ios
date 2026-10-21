import XCTest
@testable import FitnessAppCore

final class ExternalWorkoutDedupTests: XCTestCase {

    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func minutes(_ n: Double) -> Date {
        base.addingTimeInterval(n * 60)
    }

    func testNoExistingWindowsNeverOverlaps() {
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(30), existingWindows: []
        ))
    }

    func testIdenticalWindowOverlaps() {
        XCTAssertTrue(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(30),
            existingWindows: [(start: base, end: minutes(30))]
        ))
    }

    /// Ein Fremd-App-Sample und eine manuell nacherfasste Session haben nie
    /// exakt denselben Zeitstempel — die Ueberlappungs-Pruefung muss trotzdem
    /// greifen, solange sich die Fenster ueberwiegend decken.
    func testShiftedWindowWithMajorityOverlapCountsAsDuplicate() {
        // Sample: 0..30min. Bestehend: 2..32min -> 28 von 30min ueberlappen (93%).
        XCTAssertTrue(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(30),
            existingWindows: [(start: minutes(2), end: minutes(32))]
        ))
    }

    func testMinorOverlapDoesNotCountAsDuplicate() {
        // Sample: 0..30min. Bestehend: 25..55min -> nur 5 von 30min ueberlappen (17%).
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(30),
            existingWindows: [(start: minutes(25), end: minutes(55))]
        ))
    }

    func testNonOverlappingWindowIsNotADuplicate() {
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(30),
            existingWindows: [(start: minutes(60), end: minutes(90))]
        ))
    }

    func testZeroDurationSampleNeverOverlaps() {
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: base,
            existingWindows: [(start: base, end: minutes(30))]
        ))
    }

    func testMatchAgainstOneOfSeveralWindows() {
        XCTAssertTrue(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: minutes(100), sampleEnd: minutes(130),
            existingWindows: [
                (start: base, end: minutes(30)),
                (start: minutes(100), end: minutes(130)),
                (start: minutes(200), end: minutes(230))
            ]
        ))
    }

    // MARK: - Export-Richtung (Deltiq-Session als Sample, Health-Workouts als Fenster)
    //
    // Beim Export frueherer Trainings nach Apple Health sind die Rollen
    // vertauscht: das Sample ist die Deltiq-Session, die Fenster sind die in
    // Health sichtbaren Workouts. Normiert wird auf die Dauer der SESSION.

    /// Ein kurzes Fremd-Workout (z.B. 10-min-Walk einer Uhr) innerhalb einer
    /// langen Session blockiert sie nicht.
    func testShortExistingWorkoutInsideALongSampleIsNoDuplicate() {
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(70),
            existingWindows: [(start: minutes(20), end: minutes(30))]
        ))
    }

    /// Eine Session innerhalb eines laengeren Fremd-Workouts ist abgedeckt.
    func testSampleInsideALongerExistingWorkoutIsADuplicate() {
        XCTAssertTrue(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: minutes(30), sampleEnd: minutes(60),
            existingWindows: [(start: base, end: minutes(180))]
        ))
    }

    /// Direkt aneinandergrenzende Workouts (Ende == Start) ueberlappen nicht.
    func testAdjacentWindowsAreNoDuplicate() {
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: minutes(30), sampleEnd: minutes(60),
            existingWindows: [(start: base, end: minutes(30)), (start: minutes(60), end: minutes(90))]
        ))
    }

    /// Genau die Haelfte reicht NICHT (strikt "mehr als die Haelfte").
    func testExactlyHalfOverlapIsNoDuplicate() {
        XCTAssertFalse(ExternalWorkoutDedup.overlapsExisting(
            sampleStart: base, sampleEnd: minutes(40),
            existingWindows: [(start: minutes(20), end: minutes(80))]
        ))
    }
}
