import XCTest
@testable import FitnessAppCore

final class ExerciseLibraryDataTests: XCTestCase {

    // MARK: Volume + uniqueness

    func testLibraryHasReasonableSize() {
        // Sanity guard against accidental truncation. Library should have at least
        // 70 entries to cover all major movement patterns + accessories.
        XCTAssertGreaterThanOrEqual(ExerciseLibraryData.all.count, 70,
                                    "Library shrunk below 70 entries — likely an accidental delete during refactor")
    }

    func testNamesAreUnique() {
        let names = ExerciseLibraryData.all.map(\.name)
        let unique = Set(names)
        if names.count != unique.count {
            // Surface the actual duplicates for debug ergonomics.
            let counts = Dictionary(grouping: names, by: { $0 }).mapValues { $0.count }
            let dupes = counts.filter { $0.value > 1 }.keys.sorted()
            XCTFail("duplicate exercise names in library: \(dupes)")
        }
    }

    func testNamesAreNonEmpty() {
        for spec in ExerciseLibraryData.all {
            XCTAssertFalse(spec.name.isEmpty, "empty exercise name in library")
            XCTAssertFalse(spec.name.trimmingCharacters(in: .whitespaces).isEmpty,
                           "whitespace-only exercise name in library")
        }
    }

    // MARK: System compounds

    func testSystemCompoundFlagsTheFiveCanonicalLifts() {
        // Squat, Bench, Deadlift, OHP, Row — the standard "big five". Charts and
        // PR-tracking depend on these being explicitly flagged.
        let compoundNames = ExerciseLibraryData.all
            .filter { $0.isSystemCompound }
            .map(\.name)
            .sorted()

        let expected = [
            "Bankdruecken",
            "Kniebeuge",
            "Kreuzheben (konventionell)",
            "Rudern vorgebeugt",
            "Schulterdruecken (stehend)"
        ].sorted()

        XCTAssertEqual(compoundNames, expected,
                       "isSystemCompound flag set on the wrong exercises — expected \(expected), got \(compoundNames)")
    }

    // MARK: Time-based exercises

    func testTimeBasedFlagOnIsometrics() {
        // Plank, Wall Sit, Seitstuetz are all isometric. These are also referenced
        // by the bodyweight programs — flag must be set for the auto-propagation
        // in `ProgramInstantiator` to work.
        let timeBased = Set(
            ExerciseLibraryData.all
                .filter { $0.isTimeBased }
                .map(\.name)
        )

        for required in ["Plank", "Seitstuetz", "Wall Sit", "Mountain Climbers", "Burpees"] {
            XCTAssertTrue(timeBased.contains(required),
                          "Library spec '\(required)' should have isTimeBased = true")
        }
    }

    // MARK: Equipment coverage

    func testEveryEquipmentTypeHasAtLeastOneEntry() {
        // Drop in a new EnvironmentType later? This catches "we forgot to add a
        // single exercise for the new equipment slot" errors.
        for equipment in Equipment.allCases {
            let entries = ExerciseLibraryData.all.filter { $0.equipment == equipment }
            XCTAssertFalse(entries.isEmpty,
                           "Library has zero entries for equipment '\(equipment)'")
        }
    }

    func testEveryMuscleGroupHasAtLeastOneEntry() {
        for muscle in MuscleGroup.allCases {
            let entries = ExerciseLibraryData.all.filter { $0.primaryMuscle == muscle }
            XCTAssertFalse(entries.isEmpty,
                           "Library has zero entries for muscle '\(muscle)'")
        }
    }
}
