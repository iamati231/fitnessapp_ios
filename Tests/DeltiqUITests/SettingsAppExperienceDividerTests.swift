import XCTest

/// Modul-6-Audit: `SettingsAppExperienceView` hatte drei falsch gesetzte bzw.
/// vertauschte `showsDivider`-Werte — alle mit demselben Symptom, eine
/// Trennlinie erscheint oder fehlt unabhaengig davon, ob tatsaechlich noch
/// eine weitere Zeile folgt. Reiner Quelltext-Regressionstest nach dem
/// `matchingBraceBlock`-Muster aus `SettingsGroupOrderAndAttributionTests`/
/// `OnlineFoodLookupFlowTests` — SwiftUI-Zeilen-Rendering selbst ist in
/// diesem Projekt nicht per Unit-Test pruefbar (kein UI-Test-Target).
final class SettingsAppExperienceDividerTests: XCTestCase {
    private func contents() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI/Settings/SettingsAppExperienceView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Text between `afterOpenBrace` (position right after an already-consumed
    /// opening `{`) and its matching closing `}` — brace-depth counting, same
    /// helper shape as `SettingsGroupOrderAndAttributionTests.matchingBraceBlock`.
    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private func block(_ propertyName: String, in source: String) throws -> String {
        guard let range = source.range(of: "private var \(propertyName): some View {") else {
            XCTFail("\(propertyName) nicht gefunden")
            return ""
        }
        return try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
    }

    /// Die einzige Zeile der Section (Einheiten-Picker) muss `showsDivider:
    /// false` tragen — direkt danach folgt nur noch der Footer-Hinweistext.
    func testPreferencesSectionUnitsRowHasNoTrailingDivider() throws {
        let section = try block("preferencesSection", in: try contents())
        XCTAssertTrue(
            section.contains("settings.preferences.units.label") && section.contains("showsDivider: false"),
            "die einzige Zeile der preferencesSection muss showsDivider: false tragen, da direkt danach nur noch hintRow folgt"
        )
    }

    /// Der Deload-Toggle darf keine eigene showsDivider-Bedingung mehr tragen
    /// (die Plateau-Zeile folgt ihm IMMER unbedingt, also Default `true`);
    /// die zuvor dort fehlplatzierte Bedingung gehoert an die Plateau-Zeile,
    /// die tatsaechlich optional noch vom "Jetzt beenden"-Button/der
    /// Erfolgsmeldung gefolgt wird.
    func testDeloadToggleAlwaysShowsDividerAndPlateauRowCarriesTheConditional() throws {
        let section = try block("workoutBehaviorSection", in: try contents())

        guard let deloadLabelRange = section.range(of: "settings.deload.toggle") else {
            return XCTFail("Deload-Toggle-Zeile nicht gefunden")
        }
        guard let plateauLabelRange = section.range(of: "settings.plateau.toggle") else {
            return XCTFail("Plateau-Toggle-Zeile nicht gefunden")
        }
        // Der Deload-Toggle-Aufruf (zwischen seinem Label und dem der
        // Plateau-Zeile) darf kein showsDivider: mehr enthalten.
        let deloadRowSource = section[deloadLabelRange.upperBound..<plateauLabelRange.lowerBound]
        XCTAssertFalse(
            deloadRowSource.contains("showsDivider:"),
            "der Deload-Toggle darf kein eigenes showsDivider mehr haben - die Plateau-Zeile folgt ihm immer unbedingt (Default true)"
        )

        // Die verschobene Bedingung muss jetzt NACH dem Plateau-Label stehen
        // (nicht mehr vor ihm, am Deload-Toggle) - kombiniert mit der obigen
        // Pruefung, dass die Deload-Zeile kein showsDivider mehr traegt, und
        // der Tatsache, dass diese Bedingung in der Section nur einmal
        // vorkommt, belegt das die vollstaendige Verschiebung.
        guard let conditionRange = section.range(of: "showsDivider: pendingDeloadCount > 0 || deloadRestoreMessage != nil") else {
            return XCTFail("die verschobene showsDivider-Bedingung wurde nirgends in workoutBehaviorSection gefunden")
        }
        XCTAssertTrue(
            conditionRange.lowerBound > plateauLabelRange.lowerBound,
            "die Bedingung muss jetzt an der Plateau-Zeile haengen, nicht mehr am Deload-Toggle davor"
        )
    }

    /// Die Mess-Erinnerung-Zeile folgt dem Wasser-Erinnerung-Toggle IMMER
    /// unbedingt (direkt, oder nach der optionalen Frequenz-Picker-Zeile) -
    /// der Wasser-Toggle darf also kein eigenes showsDivider mehr an
    /// `waterReminderEnabled` haengen (Default `true`).
    func testWaterReminderToggleAlwaysShowsDividerToTheMeasurementRowBelow() throws {
        let section = try block("remindersSection", in: try contents())
        guard let waterLabelRange = section.range(of: "settings.reminders.water") else {
            return XCTFail("Wasser-Erinnerung-Zeile nicht gefunden")
        }
        guard let measurementLabelRange = section.range(of: "settings.reminders.measurement") else {
            return XCTFail("Mess-Erinnerung-Zeile nicht gefunden")
        }
        let waterRowSource = section[waterLabelRange.upperBound..<measurementLabelRange.lowerBound]
        XCTAssertFalse(
            waterRowSource.contains("showsDivider:"),
            "der Wasser-Erinnerung-Toggle darf kein showsDivider mehr an waterReminderEnabled haengen - "
                + "die Mess-Erinnerung-Zeile folgt ihm so oder so (Default true)"
        )
        // Gegenprobe: die Mess-Erinnerung-Zeile selbst war bereits korrekt und
        // bleibt unveraendert (ihr Nachfolger ist tatsaechlich optional).
        XCTAssertTrue(
            section.contains("showsDivider: measurementReminderEnabled"),
            "die bereits korrekte Mess-Erinnerung-Bedingung darf durch diesen Fix nicht angefasst werden"
        )
    }
}
