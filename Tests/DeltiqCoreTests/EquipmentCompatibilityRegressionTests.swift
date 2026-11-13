import XCTest
@testable import DeltiqCore

/// Regressionstests für Issue #11: noEquipment-Kompatibilitäts-Validierung
/// (equipmentRequirement-Prüfung) und Alternative-Auflösung.
///
/// Akzeptanzkriterien:
/// 1. Übungen mit .item(.pullUpBar) als equipmentRequirement dürfen im
///    noEquipment-Modus NICHT als kompatibel gemeldet werden.
/// 2. resolveAlternative liefert .keep (kein gültiger Ersatz), wenn die
///    eingetragene noEquipment-Alternative selbst inkompatibel ist.
/// 3. isCompatibleWith ist public und somit aus DeltiqData aufrufbar.
final class EquipmentCompatibilityRegressionTests: XCTestCase {

    // MARK: - 1. noEquipment-Kompatibilität (isCompatibleWith)

    func testHandtuchRudernIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Handtuch-Rudern (Türrahmen)", environment: .noEquipment),
            "Handtuch-Rudern braucht Fixpunkt — darf nicht als noEquipment-kompatibel gelten"
        )
    }

    func testAustralianPullupsIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Australian Pull-ups", environment: .noEquipment),
            "Australian Pull-ups braucht Klimmzugstange — darf nicht als noEquipment-kompatibel gelten"
        )
    }

    func testNordicCurlsIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Nordic Curls", environment: .noEquipment),
            "Nordic Curls braucht Fußfixierung — .pullUpBar als Proxy signalisiert Gerätbedarf"
        )
    }

    func testLiegestuetzeIsCompatibleWithNoEquipment() {
        XCTAssertTrue(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Liegestütze", environment: .noEquipment),
            "Liegestütze ist echte Körpergewichtsübung — muss noEquipment-kompatibel sein"
        )
    }

    func testUnknownExerciseIsIncompatibleConservatively() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Fiktive Testuebung XYZ", environment: .noEquipment),
            "Unbekannte Übung → konservativ inkompatibel (kein Spec gefunden)"
        )
    }

    // MARK: - 2. Alternative-Auflösung (resolveAlternative)

    func testFacePullsHasNoValidAlternativeForNoEquipment() {
        // Face Pulls → Handtuch-Rudern (Türrahmen) als noEquipment-Alternative,
        // aber Handtuch-Rudern ist jetzt inkompatibel → .keep erwartet.
        let result = ExerciseLibraryData.resolveAlternative(forExerciseName: "Face Pulls", targetEnvironment: .noEquipment)
        XCTAssertEqual(result, .keep, "Face Pulls darf keine inkompatible noEquipment-Alternative liefern")
    }

    func testFacePullHasNoValidAlternativeForNoEquipment() {
        let result = ExerciseLibraryData.resolveAlternative(forExerciseName: "Face Pull", targetEnvironment: .noEquipment)
        XCTAssertEqual(result, .keep)
    }

    func testLiegestuetzeAlreadyCompatibleWithNoEquipment() {
        let result = ExerciseLibraryData.resolveAlternative(forExerciseName: "Liegestütze", targetEnvironment: .noEquipment)
        XCTAssertEqual(result, .stayCompatible, "Liegestütze braucht keine Alternative — ist schon kompatibel")
    }

    // MARK: - 3. Gym-kompatibel bei allen Environments

    func testLiegestuetzeIsCompatibleWithGym() {
        XCTAssertTrue(ExerciseLibraryData.isCompatibleWith(exerciseName: "Liegestütze", environment: .gym))
    }

    func testLiegestuetzeIsCompatibleWithHomeGym() {
        XCTAssertTrue(ExerciseLibraryData.isCompatibleWith(exerciseName: "Liegestütze", environment: .homeGym))
    }
}
