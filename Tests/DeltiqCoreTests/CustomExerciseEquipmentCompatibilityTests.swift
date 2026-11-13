import XCTest
@testable import DeltiqCore

/// Issue #12: Equipment-Kompatibilitätsprüfung für Custom-Exercises.
/// Testet die Reine Funktion ExerciseLibraryData.isEquipment(_:compatibleWith:),
/// die PlanEnvironmentMigrator für Custom-Exercises (nicht im Systemkatalog) nutzt.
final class CustomExerciseEquipmentCompatibilityTests: XCTestCase {

    // MARK: - noEquipment-Modus

    func testBodyweightCompatibleWithNoEquipment() {
        XCTAssertTrue(ExerciseLibraryData.isEquipment(.bodyweight, compatibleWith: .noEquipment))
    }

    func testBarbellIncompatibleWithNoEquipment() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.barbell, compatibleWith: .noEquipment))
    }

    func testDumbbellIncompatibleWithNoEquipment() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.dumbbell, compatibleWith: .noEquipment))
    }

    func testKettlebellIncompatibleWithNoEquipment() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.kettlebell, compatibleWith: .noEquipment))
    }

    func testBandIncompatibleWithNoEquipment() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.band, compatibleWith: .noEquipment))
    }

    func testMachineIncompatibleWithNoEquipment() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.machine, compatibleWith: .noEquipment))
    }

    func testCableIncompatibleWithNoEquipment() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.cable, compatibleWith: .noEquipment))
    }

    // MARK: - homeGym-Modus

    func testBodyweightCompatibleWithHomeGym() {
        XCTAssertTrue(ExerciseLibraryData.isEquipment(.bodyweight, compatibleWith: .homeGym))
    }

    func testDumbbellCompatibleWithHomeGym() {
        XCTAssertTrue(ExerciseLibraryData.isEquipment(.dumbbell, compatibleWith: .homeGym))
    }

    func testKettlebellCompatibleWithHomeGym() {
        XCTAssertTrue(ExerciseLibraryData.isEquipment(.kettlebell, compatibleWith: .homeGym))
    }

    func testBandCompatibleWithHomeGym() {
        XCTAssertTrue(ExerciseLibraryData.isEquipment(.band, compatibleWith: .homeGym))
    }

    func testBarbellIncompatibleWithHomeGym() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.barbell, compatibleWith: .homeGym))
    }

    func testMachineIncompatibleWithHomeGym() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.machine, compatibleWith: .homeGym))
    }

    func testCableIncompatibleWithHomeGym() {
        XCTAssertFalse(ExerciseLibraryData.isEquipment(.cable, compatibleWith: .homeGym))
    }

    // MARK: - gym-Modus: alles kompatibel

    func testAllEquipmentCompatibleWithGym() {
        for equipment in Equipment.allCases {
            XCTAssertTrue(
                ExerciseLibraryData.isEquipment(equipment, compatibleWith: .gym),
                "\(equipment) muss im Gym-Modus kompatibel sein"
            )
        }
    }
}
