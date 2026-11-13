import XCTest
@testable import DeltiqCore

final class ExerciseSecondaryMusclesTests: XCTestCase {

    func testPrimaryRemovedFromSecondary() {
        // "ausfallschritt ruckwarts lh" → [.quads, .hamstrings, .calves]; primary = .quads
        let result = ExerciseSecondaryMuscles.filtered(for: "ausfallschritt ruckwarts lh", excluding: .quads)
        XCTAssertEqual(result, [.hamstrings, .calves])
        XCTAssertFalse(result.contains(.quads))
    }

    func testOrderPreserved() {
        // Raw: [.quads, .hamstrings, .calves, .shoulders, .chest]
        // Excluding .core (not in list) → same order
        let raw = ExerciseSecondaryMuscles.byNormalizedName["burpees"]!
        let result = ExerciseSecondaryMuscles.filtered(for: "burpees", excluding: .core)
        XCTAssertEqual(result, raw.filter { $0 != .core })
    }

    func testNoDuplicatesInResult() {
        // All entries in the result must be unique.
        let allKeys = ExerciseSecondaryMuscles.byNormalizedName.keys
        for key in allKeys {
            let raw = ExerciseSecondaryMuscles.byNormalizedName[key]!
            if let primary = raw.first {
                let result = ExerciseSecondaryMuscles.filtered(for: key, excluding: primary)
                XCTAssertEqual(result.count, Set(result).count,
                               "duplicates in filtered result for '\(key)'")
            }
        }
    }

    func testMissingKeyReturnsEmpty() {
        let result = ExerciseSecondaryMuscles.filtered(for: "nonexistent exercise xyz", excluding: .chest)
        XCTAssertTrue(result.isEmpty)
    }

    func testPrimaryOnlyListReturnsEmpty() {
        // "beinstrecker liegend" → [.hamstrings]; excluding .hamstrings → []
        let result = ExerciseSecondaryMuscles.filtered(for: "beinstrecker liegend", excluding: .hamstrings)
        XCTAssertTrue(result.isEmpty)
    }
}
