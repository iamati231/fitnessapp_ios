#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import DeltiqCore

/// Regression guard: every noEquipment alternative in ExerciseLibraryData.alternatives
/// must pass isCompatibleWith(.noEquipment). This catches future regressions where a
/// new alternative pointing to an equipment-requiring exercise (pull-up bar, bench, etc.)
/// is accidentally added for the noEquipment environment.
final class NoEquipmentAlternativesCompatibilityTests: XCTestCase {

    func testAllNoEquipmentAlternativesAreCompatible() {
        var failures: [String] = []
        for (source, envMap) in ExerciseLibraryData.alternatives {
            guard let altName = envMap[.noEquipment] else { continue }
            let ok = ExerciseLibraryData.isCompatibleWith(exerciseName: altName, environment: .noEquipment)
            if !ok {
                failures.append("\(source) → \(altName)")
            }
        }
        XCTAssertTrue(failures.isEmpty,
            "noEquipment alternatives require equipment: \(failures.joined(separator: ", "))")
    }

    func testNoEquipmentAlternativesNeverPointToPullUpBarExercises() {
        let requiresFixation = ["Australian Pull-ups", "Klimmzüge", "Klimmzüge (weit)",
                                "Klimmzüge (eng/Chin-up)", "Nordic Curls",
                                "Handtuch-Rudern (Türrahmen)"]
        for (source, envMap) in ExerciseLibraryData.alternatives {
            if let altName = envMap[.noEquipment] {
                XCTAssertFalse(requiresFixation.contains(altName),
                    "\(source): noEquipment maps to '\(altName)' which needs equipment")
            }
        }
    }

    func testGanzkörperHamstringExercisesHaveValidAlternatives() {
        let hamstringMachineExercises = ["Beinbeuger (sitzend)", "Beinbeuger (liegend)",
                                          "Rumänisches Kreuzheben", "Rumänisches Kreuzheben (KH)",
                                          "Good Morning"]
        for name in hamstringMachineExercises {
            let resolution = ExerciseLibraryData.resolveAlternative(
                forExerciseName: name, targetEnvironment: .noEquipment)
            if case .swap(let spec) = resolution {
                XCTAssertTrue(ExerciseLibraryData.isCompatibleWith(
                    exerciseName: spec.name, environment: .noEquipment),
                    "\(name) resolved to '\(spec.name)' which is incompatible with noEquipment")
            } else if case .keep = resolution {
                XCTFail("\(name) has no valid noEquipment alternative (resolves to .keep)")
            }
        }
    }
}
#endif
