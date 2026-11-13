#if canImport(AVFoundation)
import XCTest
import AVFoundation
@testable import DeltiqUI

/// Regressionstests für Issue #11 P4: Video-Längen-Validierung in
/// `CustomExerciseMediaStore.validateDuration(_:)`.
/// Echte CMTime-Boundary-Werte statt Quellcode-String-Suche.
final class CustomMediaStoreVideoValidationTests: XCTestCase {

    // MARK: - Scenario 8a: Grenzwert-Konstante

    func testMaxVideoSecondsIs15() {
        XCTAssertEqual(CustomExerciseMediaStore.maxVideoSeconds, 15,
                       "maxVideoSeconds muss exakt 15.0 Sekunden betragen")
    }

    // MARK: - Scenario 8b: gültige Dauern

    func testDuration14point9Passes() throws {
        // 14.9 s < 15 s → kein Fehler
        let t = CMTime(seconds: 14.9, preferredTimescale: 600)
        XCTAssertNoThrow(try CustomExerciseMediaStore.validateDuration(t))
    }

    func testDurationExactly15Passes() throws {
        // 15.0 s == 15 s → kein Fehler (Grenzwert inklusive)
        let t = CMTime(seconds: 15.0, preferredTimescale: 600)
        XCTAssertNoThrow(try CustomExerciseMediaStore.validateDuration(t))
    }

    // MARK: - Scenario 8c: .tooLong

    func testDuration15point1ThrowsTooLong() throws {
        let t = CMTime(seconds: 15.1, preferredTimescale: 600)
        XCTAssertThrowsError(try CustomExerciseMediaStore.validateDuration(t)) { error in
            XCTAssertEqual(error as? CustomMediaError, .tooLong,
                           "15.1 s muss .tooLong werfen")
        }
    }

    func testDuration100SecondsThrowsTooLong() throws {
        let t = CMTime(seconds: 100, preferredTimescale: 600)
        XCTAssertThrowsError(try CustomExerciseMediaStore.validateDuration(t)) { error in
            XCTAssertEqual(error as? CustomMediaError, .tooLong)
        }
    }

    // MARK: - Scenario 8d: .invalidDuration

    func testInvalidCMTimeThrowsInvalidDuration() throws {
        XCTAssertThrowsError(try CustomExerciseMediaStore.validateDuration(.invalid)) { error in
            XCTAssertEqual(error as? CustomMediaError, .invalidDuration,
                           "CMTime.invalid muss .invalidDuration werfen")
        }
    }

    func testIndefiniteCMTimeThrowsInvalidDuration() throws {
        XCTAssertThrowsError(try CustomExerciseMediaStore.validateDuration(.indefinite)) { error in
            XCTAssertEqual(error as? CustomMediaError, .invalidDuration,
                           "CMTime.indefinite muss .invalidDuration werfen")
        }
    }

    func testZeroDurationThrowsInvalidDuration() throws {
        // secs == 0 → guard secs > 0 schlägt fehl
        let t = CMTime(value: 0, timescale: 600)
        XCTAssertThrowsError(try CustomExerciseMediaStore.validateDuration(t)) { error in
            XCTAssertEqual(error as? CustomMediaError, .invalidDuration,
                           "Duration 0 s muss .invalidDuration werfen")
        }
    }

    func testNegativeDurationThrowsInvalidDuration() throws {
        let t = CMTime(seconds: -1, preferredTimescale: 600)
        XCTAssertThrowsError(try CustomExerciseMediaStore.validateDuration(t)) { error in
            XCTAssertEqual(error as? CustomMediaError, .invalidDuration)
        }
    }
}
#endif
