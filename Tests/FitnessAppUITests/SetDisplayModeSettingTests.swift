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
///   3. Geraete-Nachtest (Runde 10, AX5, ZWEI Anlaeufe): der "Set display"-
///      Picker-Wert "Previous layout"/"Column overview" ist laenger als die
///      uebrigen Picker-Werte dieses Screens. `.pickerStyle(.menu)` rendert
///      seinen eingeklappten Wert bei AX5 ueber ein natives UIKit-Button-
///      Label, das SwiftUIs `.lineLimit`/`.minimumScaleFactor` ignoriert -
///      weder `DeltiqControlRow`s eigenes `.minimumScaleFactor(0.85)` NOCH
///      eine blosse `maxWidth` (erster Fix-Versuch) reichten, der Text lief
///      beide Male ueber mehrere Nachbar-Reihen hinweg. Erst `maxHeight` +
///      `.clipped()` deckelt das hart. Dieser Test prueft nur, dass die
///      Begrenzung im Quelltext bleibt - die tatsaechliche AX5-Lesbarkeit
///      ist nur am Geraet pruefbar (siehe Matrix).
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

    /// Regressionswächter: Satzanzeige-Einstellung (pref_set_display_mode)
    /// wurde bewusst entfernt (classic-Layout ist jetzt fest codiert).
    /// Stellt sicher, dass der Key nicht versehentlich wieder eingebaut wird.
    func testSetDisplayModeKeyIsRemovedFromAllCallSites() throws {
        for relativePath in [
            "Workout/SetRow.swift",
            "Workout/ExerciseCard.swift",
            "Settings/SettingsAppExperienceView.swift"
        ] {
            let source = try contents(of: relativePath)
            XCTAssertFalse(
                source.contains("pref_set_display_mode"),
                "\(relativePath) darf keinen pref_set_display_mode-Key mehr enthalten — "
                    + "Satzanzeige wurde auf classic-Layout festgelegt."
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

    /// Regressionswächter: Satzanzeige-Picker ist entfernt worden; der
    /// entsprechende Lokalisierungsstring darf nicht mehr in SettingsAppExperienceView
    /// auftauchen (wäre ein Hinweis auf versehentliches Wiedereinbauen).
    func testSetDisplayPickerStringIsRemovedFromSettings() throws {
        let source = try contents(of: "Settings/SettingsAppExperienceView.swift")
        XCTAssertFalse(
            source.contains("settings.training.displayMode.classic"),
            "Der Set-display-Picker wurde entfernt — dieser Lokalisierungsstring sollte nicht mehr in "
                + "SettingsAppExperienceView.swift vorkommen."
        )
    }
}
