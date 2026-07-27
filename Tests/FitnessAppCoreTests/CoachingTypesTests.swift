import XCTest
@testable import FitnessAppCore

/// DEL-100: Tests fuer die Coaching-Enums + Localization-Key-Generation.
/// Die eigentliche `CoachingMessageProvider`-Resolver-Logik lebt im UI-
/// Modul (braucht `Bundle.module`), deshalb hier nur die Pure-Core-Bestand-
/// teile abgesichert.
final class CoachingTypesTests: XCTestCase {

    // MARK: Enum-Konsistenz

    func testCoachingToneCoversAllExpectedCases() {
        let cases = Set(CoachingTone.allCases.map(\.rawValue))
        XCTAssertEqual(cases, ["analytical", "motivating", "strict"])
    }

    func testTrainingGoalCoversAllExpectedCases() {
        let cases = Set(TrainingGoal.allCases.map(\.rawValue))
        // DEL-206 hat `weightLoss` als vierte Coaching-Achse ergaenzt; der
        // Test wurde damals nicht mitgezogen und blieb unentdeckt, weil der
        // macOS-Build des Pakets ab Mitte Mai scheiterte und `swift test`
        // deshalb nie lief (siehe DEL-230).
        //
        // RawValues sind Persistenz-Vertrag: sie stehen in
        // UserBodyProfile.trainingGoalRaw und in den Catalog-Keys
        // `coaching.{context}.{tone}.{goal}`. Eine Umbenennung hier ist ein
        // Migrations-Ereignis, deshalb bleibt der Snapshot exakt.
        XCTAssertEqual(cases, ["hypertrophy", "strength", "hybrid", "weightLoss"])
    }

    /// Tonfall-Cases muessen alle ein Label, ein SF-Symbol und einen
    /// Beschreibungstext liefern — sonst zerschiesst es die OnboardingCard
    /// (leere Subtitle-Zeile).
    func testCoachingToneMetadataIsComplete() {
        for tone in CoachingTone.allCases {
            XCTAssertFalse(tone.label.isEmpty, "\(tone): label leer")
            XCTAssertFalse(tone.symbol.isEmpty, "\(tone): symbol leer")
            XCTAssertFalse(tone.blurb.isEmpty, "\(tone): blurb leer")
        }
    }

    func testTrainingGoalMetadataIsComplete() {
        for goal in TrainingGoal.allCases {
            XCTAssertFalse(goal.label.isEmpty, "\(goal): label leer")
            XCTAssertFalse(goal.symbol.isEmpty, "\(goal): symbol leer")
            XCTAssertFalse(goal.blurb.isEmpty, "\(goal): blurb leer")
        }
    }

    // MARK: Localization-Key-Schema

    /// Smoke-Test, dass die rawValue-Kombinationen das erwartete Key-Schema
    /// fuer die xcstrings-Lookups produzieren. Wenn jemand spaeter ein Enum
    /// umbenennt, brechen die Translations stillschweigend — dieser Test
    /// faengt das.
    func testCoachingKeyFormatStaysStable() {
        let key = "coaching.\(CoachingContext.restDay.rawValue).\(CoachingTone.strict.rawValue).\(TrainingGoal.strength.rawValue)"
        XCTAssertEqual(key, "coaching.restDay.strict.strength")
    }

    func testPlateauContextKeyFormat() {
        let key = "coaching.\(CoachingContext.plateauDetected.rawValue).\(CoachingTone.analytical.rawValue).\(TrainingGoal.hypertrophy.rawValue)"
        XCTAssertEqual(key, "coaching.plateauDetected.analytical.hypertrophy")
    }

    /// `CoachingContext` ist String-RawValue + Sendable — verifiziere, dass
    /// das Encode-Roundtrip stabil ist (Plan-Speicher fuer Telemetrie etc.).
    func testCoachingContextRawValuesAreStable() {
        let allRawValues: [String] = [
            CoachingContext.restDay.rawValue,
            CoachingContext.cnsOverloaded.rawValue,
            CoachingContext.newPR.rawValue,
            CoachingContext.plateauDetected.rawValue
        ]
        // Snapshot fuer Migrations-Sicherheit: wenn jemand `cnsOverloaded`
        // zu `cnsOverload` umbenennt, kippt der Test.
        XCTAssertEqual(allRawValues,
                       ["restDay", "cnsOverloaded", "newPR", "plateauDetected"])
    }
}
