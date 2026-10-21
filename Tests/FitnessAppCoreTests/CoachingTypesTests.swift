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
        //
        // Smart-Onboarding-Epic: `functional` kam aus dem entfernten
        // `GoalType` dazu (Konsolidierung auf eine Achse). Ein zwischen-
        // zeitliches `fatloss` ist wieder entfernt — es erzeugte eine zweite,
        // konkurrierende "Abnehmen"-Bedeutung neben `.weightLoss` (siehe
        // TrainingGoal-Doc-Kommentar). Die vier bestehenden RawValues sind
        // unveraendert, es wurde nur `functional` angehaengt.
        //
        // Planung-&-Trainingsbegleitung-Epic P2.2: `endurance` additiv ganz
        // ans Ende angehaengt ("Laufen & Ausdauer", Audit Konflikt 1,
        // ENTSCHIEDEN) - alle fuenf vorherigen RawValues bleiben unveraendert.
        XCTAssertEqual(cases, ["hypertrophy", "strength", "hybrid", "weightLoss", "functional", "endurance"])
    }

    /// Smart-Onboarding-Epic Leitplanke: die vier ORIGINAL-RawValues duerfen
    /// durch das Anhaengen von `fatloss`/`functional` nicht angefasst worden
    /// sein — sonst brechen bereits gespeicherte `trainingGoalRaw`-Werte in
    /// bestehenden `UserBodyProfile`-Zeilen still.
    func testTrainingGoalOriginalRawValuesStayStable() {
        XCTAssertEqual(TrainingGoal.hypertrophy.rawValue, "hypertrophy")
        XCTAssertEqual(TrainingGoal.strength.rawValue, "strength")
        XCTAssertEqual(TrainingGoal.hybrid.rawValue, "hybrid")
        XCTAssertEqual(TrainingGoal.weightLoss.rawValue, "weightLoss")
    }

    /// P2.1/P2.2-Nachbesserung Punkt 3: `.endurance` bleibt im Core gueltig,
    /// ist aber bis zu einem echten Ziel→Plan-Pfad (P3) aus neuen UI-Picker-
    /// Auswahlen ausgeblendet. Alle anderen fuenf Faelle muessen weiterhin
    /// waehlbar sein — ein zu breiter Filter wuerde das hier sofort zeigen.
    func testCurrentlySelectableInUIExcludesOnlyEndurance() {
        XCTAssertFalse(TrainingGoal.currentlySelectableInUI.contains(.endurance))
        let expectedSelectable = TrainingGoal.allCases.filter { $0 != .endurance }
        XCTAssertEqual(TrainingGoal.currentlySelectableInUI, expectedSelectable)
    }

    /// P2.3-Nachbesserung: ein bereits gespeichertes `.endurance`-Profil ist
    /// kein hypothetischer Fall (kurz waehlbar im P2.2-Zwischenstand, bleibt
    /// gueltiger Core-/Importwert) und muss in einem Picker weiterhin
    /// auftauchen, auch wenn es fuer eine NEUE Auswahl gesperrt bleibt.
    func testSelectableInUIKeepsAlreadyStoredEndurance() {
        let options = TrainingGoal.selectableInUI(current: .endurance)
        XCTAssertTrue(options.contains(.endurance), "ein bestehendes .endurance-Profil muss im Picker sichtbar bleiben")
        XCTAssertEqual(options.count, TrainingGoal.currentlySelectableInUI.count + 1, "darf kein Duplikat erzeugen")
    }

    /// Gegenprobe: fuer einen bereits regulaer waehlbaren Wert darf
    /// `selectableInUI` die Liste NICHT veraendern (kein verstecktes
    /// Duplikat, keine Nebenwirkung fuer den Normalfall).
    func testSelectableInUIIsUnchangedForRegularGoal() {
        XCTAssertEqual(TrainingGoal.selectableInUI(current: .hybrid), TrainingGoal.currentlySelectableInUI)
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
