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

    /// Die kanonischen "Big Five" MUESSEN geflaggt bleiben — an ihnen haengt
    /// die Compound-Progression (`ProgramInstantiator` zieht daraus
    /// `Exercise.isCompound`, was die Steigerungs-Schrittweite bestimmt).
    ///
    /// DEL-230: Vorher verlangte dieser Test eine EXAKTE Liste von genau
    /// diesen fuenf. DEL-162 hat die Bibliothek um weitere Langhantel-
    /// Verbundlifts erweitert (Box Squat, Trap-Bar- und Deficit-Kreuzheben,
    /// Reissen, Umsetzen & Stossen) und sie korrekt mitgeflaggt — der Test
    /// schlug seitdem fehl, was nur niemand sah, weil `swift test` ab Mitte
    /// Mai nicht mehr lief (macOS-Build kaputt).
    ///
    /// Ein Exakt-Snapshot ist hier die falsche Zusicherung: er bricht bei
    /// jeder legitimen Bibliotheks-Erweiterung. Geprueft wird stattdessen die
    /// eigentliche Invariante — die Big Five sind dabei, und geflaggt wird nur,
    /// was auch wirklich ein Langhantel-Lift ist.
    func testCanonicalBigFiveAreFlaggedAsSystemCompound() {
        let compoundNames = Set(
            ExerciseLibraryData.all.filter(\.isSystemCompound).map(\.name)
        )
        let bigFive = [
            "Bankdrücken",
            "Kniebeuge",
            "Kreuzheben (konventionell)",
            "Rudern vorgebeugt",
            "Schulterdrücken (stehend)",
        ]
        for lift in bigFive {
            XCTAssertTrue(
                compoundNames.contains(lift),
                "\(lift) hat das isSystemCompound-Flag verloren — das aendert die Progressions-Schrittweite"
            )
        }
    }

    /// Gegenprobe: das Flag darf nicht auf Isolations- oder Maschinen-Uebungen
    /// wandern. Ein geflaggter Bizeps-Curl wuerde still eine Compound-
    /// Progression bekommen.
    func testSystemCompoundsAreBarbellLiftsOnly() {
        for spec in ExerciseLibraryData.all where spec.isSystemCompound {
            XCTAssertEqual(
                spec.equipment, .barbell,
                "\(spec.name) ist als System-Compound geflaggt, nutzt aber \(spec.equipment)"
            )
        }
    }

    // MARK: Time-based exercises

    func testTimeBasedFlagOnIsometrics() {
        // Plank, Wall Sit, Seitstütz are all isometric. These are also referenced
        // by the bodyweight programs — flag must be set for the auto-propagation
        // in `ProgramInstantiator` to work.
        let timeBased = Set(
            ExerciseLibraryData.all
                .filter { $0.isTimeBased }
                .map(\.name)
        )

        for required in ["Plank", "Seitstütz", "Wall Sit", "Mountain Climbers", "Burpees"] {
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
