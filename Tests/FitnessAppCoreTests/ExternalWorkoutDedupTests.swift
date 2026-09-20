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
}
