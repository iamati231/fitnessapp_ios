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

    // MARK: - 4. P2-Regression: Dips brauchen Gerät (Issue #11)

    func testDipsBrustIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Dips (Brust)", environment: .noEquipment),
            "Dips (Brust) benötigt Stange/Parallelbarren — darf nicht noEquipment-kompatibel sein"
        )
    }

    func testDipsTrizepsIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Dips (Trizeps)", environment: .noEquipment),
            "Dips (Trizeps) benötigt Stange/Parallelbarren — darf nicht noEquipment-kompatibel sein"
        )
    }

    func testDipsBrustStangeIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Dips Brust (Stange)", environment: .noEquipment),
            "Dips Brust (Stange) benötigt Stange — darf nicht noEquipment-kompatibel sein"
        )
    }

    func testKlimmzugSupinationsgrifIsIncompatibleWithNoEquipment() {
        XCTAssertFalse(
            ExerciseLibraryData.isCompatibleWith(exerciseName: "Klimmzug Supinationsgriff", environment: .noEquipment),
            "Klimmzug Supinationsgriff benötigt Klimmzugstange — darf nicht noEquipment-kompatibel sein"
        )
    }

    // MARK: - 5. P2-Regression: Alternative-Mappings zeigen gerätefreie Übungen (Issue #11)

    func testSchraegbankAbwaertsNoEquipAlternativeIsLiegestuetzAbwaerts() {
        let result = ExerciseLibraryData.resolveAlternative(
            forExerciseName: "Schrägbankdrücken (abwärts)", targetEnvironment: .noEquipment)
        if case .swap(let spec) = result {
            XCTAssertEqual(spec.name, "Liegestütz abwärts",
                           "Schrägbankdrücken (abwärts) → noEquipment muss 'Liegestütz abwärts' sein, nicht Dips")
        } else {
            XCTFail("Erwartet .swap, got \(result)")
        }
    }

    func testTrizepsDrueckenUeberKopfKabelAlternativeIsDiamantLiegestuetze() {
        let result = ExerciseLibraryData.resolveAlternative(
            forExerciseName: "Trizeps-Drücken über Kopf (Kabel)", targetEnvironment: .noEquipment)
        if case .swap(let spec) = result {
            XCTAssertEqual(spec.name, "Diamant-Liegestütze",
                           "Trizeps-Drücken über Kopf (Kabel) → noEquipment muss 'Diamant-Liegestütze' sein")
        } else {
            XCTFail("Erwartet .swap, got \(result)")
        }
    }

    func testTrizepsstreckkerUeberKopfKHAlternativeIsDiamantLiegestuetze() {
        let result = ExerciseLibraryData.resolveAlternative(
            forExerciseName: "Trizepsstrecker über Kopf (KH)", targetEnvironment: .noEquipment)
        if case .swap(let spec) = result {
            XCTAssertEqual(spec.name, "Diamant-Liegestütze",
                           "Trizepsstrecker über Kopf (KH) → noEquipment muss 'Diamant-Liegestütze' sein")
        } else {
            XCTFail("Erwartet .swap, got \(result)")
        }
    }
}
