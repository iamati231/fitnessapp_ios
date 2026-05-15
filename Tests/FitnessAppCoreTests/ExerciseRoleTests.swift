import XCTest
@testable import FitnessAppCore

/// DEL-087: Tests fuer das ExerciseRole-Enum und das `skipsProgression`-
/// Verhalten — diese Boolean steuert, ob der `ProgressionApplicator` die
/// Uebung ueberspringt.
final class ExerciseRoleTests: XCTestCase {

    func testWorkingSetIsNotSkipped() {
        XCTAssertFalse(ExerciseRole.workingSet.skipsProgression)
    }

    func testWarmupIsSkipped() {
        XCTAssertTrue(ExerciseRole.warmup.skipsProgression)
    }

    func testCooldownIsSkipped() {
        XCTAssertTrue(ExerciseRole.cooldown.skipsProgression)
    }

    func testAllRolesArePersistable() {
        // Roundtrip-Test fuer SwiftData-rawValue-Storage.
        for role in ExerciseRole.allCases {
            let raw = role.rawValue
            let decoded = ExerciseRole(rawValue: raw)
            XCTAssertEqual(decoded, role, "rawValue round-trip failed for \(role)")
        }
    }
}
