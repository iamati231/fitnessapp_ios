import XCTest

/// Deltiq-Geraeteabnahme (Runde 10, docs/DELTIQ_DEVICE_ACCEPTANCE.md, Punkt 2+3):
/// reine Quelltext-Regressionstests (kein SwiftUI-Import noetig, laeuft auch
/// auf dem macOS-CI-Runner ohne UIKit) fuer drei leicht uebersehbare
/// Stolperfallen rund um die neue "bisherige Darstellung"/"Spaltenuebersicht"-
/// Einstellung:
///   1. Alle drei Call-Sites muessen DENSELBEN `@AppStorage`-Key nutzen -
///      ein Tippfehler in einer davon wuerde die Einstellung dort still
///      wirkungslos machen (eigener, nie synchronisierter zweiter Key),
///      statt eines sichtbaren Crashes.
///   2. `SetRow.SetRowColumns.rirWidth` darf durch den neuen Gewicht-Einzug
///      (Punkt 3) nicht verkleinert werden - die Vorgabe war explizit "RIR
///      mindestens erhalten, NICHT zusammenschieben".
///   3. Geraete-Nachtest (Runde 10, AX5): der "Set display"-Picker-Wert
///      "Previous layout" ist laenger als die uebrigen Picker-Werte dieses
///      Screens - `DeltiqControlRow`s eigenes `.minimumScaleFactor(0.85)`
///      reichte bei AX5 NICHT aus, der Text lief ueber mehrere Nachbar-
///      Reihen hinweg. Fix: engere `maxWidth` + niedrigerer eigener
///      `minimumScaleFactor`. Dieser Test prueft nur, dass die Begrenzung
///      im Quelltext bleibt - die tatsaechliche AX5-Lesbarkeit ist nur am
///      Geraet pruefbar (siehe Matrix).
final class SetDisplayModeSettingTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testAllThreeCallSitesUseTheSameDisplayModeStorageKey() throws {
        let expectedDeclaration = "@AppStorage(\"pref_set_display_mode\") private var setDisplayModeRaw: String = \"column\""

        for relativePath in [
            "Workout/SetRow.swift",
            "Workout/ExerciseCard.swift",
            "Settings/SettingsAppExperienceView.swift"
        ] {
            let source = try contents(of: relativePath)
            XCTAssertTrue(
                source.contains(expectedDeclaration),
                "\(relativePath) muss denselben AppStorage-Key/Default fuer die Satzanzeige-Einstellung "
                    + "deklarieren wie die anderen beiden Call-Sites, sonst wirkt ein Umschalten in den "
                    + "Einstellungen nicht ueberall."
            )
        }
    }

    func testRirColumnWidthWasNotShrunkByTheWeightGroupIndent() throws {
        let source = try contents(of: "Workout/SetRow.swift")
        XCTAssertTrue(
            source.contains("static let rirWidth: CGFloat = 44"),
            "rirWidth darf durch den neuen weightGroupLeadingInset nicht verkleinert werden - die RIR-"
                + "Spalte muss mindestens so breit/lesbar bleiben wie zuvor."
        )
    }

    func testSetDisplayPickerConstrainsItsWidthSoLongValuesCannotOverflowIntoNeighboringRows() throws {
        let source = try contents(of: "Settings/SettingsAppExperienceView.swift")
        guard let pickerRange = source.range(of: "settings.training.displayMode.classic") else {
            XCTFail("Set-display-Picker nicht gefunden - hat sich SettingsAppExperienceView.swift strukturell geaendert?")
            return
        }
        guard let rowEnd = source[pickerRange.upperBound...].range(of: "\n            }") else {
            XCTFail("Ende des Set-display-Pickers nicht gefunden")
            return
        }
        let pickerBody = source[pickerRange.upperBound..<rowEnd.lowerBound]
        XCTAssertTrue(
            pickerBody.contains(".frame(maxWidth:"),
            "Der Set-display-Picker muss eine eigene maxWidth setzen, sonst lief \"Previous layout\" bei "
                + "AX5 (Geraete-Nachtest Runde 10) ueber mehrere Nachbar-Reihen hinweg."
        )
    }
}
