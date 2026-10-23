import XCTest

/// SET-01 + AI-01 (Audit docs/AUDIT_2026-10-23_DELTIQ.md, beide P2): zwei
/// reine Quelltext-/Vertrags-Regressionstests nach dem Muster von
/// `SetDisplayModeSettingTests` — die eigentliche Wirkung ist nur mit
/// laufender UI pruefbar, das Muster dieses Repos fuer „Einstellung wirkt
/// ueberall" ist aber, dass alle lesenden Stellen denselben Key nutzen und
/// denselben Text steuern.
final class RirTooltipToggleScopeTests: XCTestCase {
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

    /// SET-01: Jede Stelle, die den RIR-Hilfetext zeigt, muss denselben
    /// `@AppStorage`-Key mit demselben Default deklarieren — sonst wirkt der
    /// Schalter genau dort nicht (im Training war das monatelang der Fall).
    func testEverySiteReadingTheRirTooltipSettingUsesTheSameKey() throws {
        let expectedDeclaration = "@AppStorage(\"showRirTooltips\") private var showRirTooltips: Bool = true"

        for relativePath in [
            "Workout/SetRow.swift",
            "Workout/ExerciseEditorView.swift",
            "Settings/SettingsAppExperienceView.swift"
        ] {
            let source = try contents(of: relativePath)
            XCTAssertTrue(
                source.contains(expectedDeclaration),
                "\(relativePath) muss den Key 'showRirTooltips' mit Default true deklarieren - "
                    + "sonst zeigt der Schalter in den Einstellungen dort keine Wirkung."
            )
        }
    }

    /// SET-01: Im aktiven Training muss der Hilfetext unter dem RIR-Regler
    /// tatsaechlich an der Einstellung haengen (nicht nur der Key existieren).
    func testSetRowRirHintIsGatedByTheSetting() throws {
        let source = try contents(of: "Workout/SetRow.swift")
        guard let rowRange = source.range(of: "private var rirSliderRow: some View {") else {
            XCTFail("rirSliderRow nicht gefunden - Struktur von SetRow.swift geaendert?")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: rowRange.upperBound))
        guard let gateRange = block.range(of: "if showRirTooltips {") else {
            XCTFail("Der RIR-Hilfetext in SetRow.rirSliderRow muss hinter `if showRirTooltips {` stehen.")
            return
        }
        let gated = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: gateRange.upperBound))
        XCTAssertTrue(
            gated.contains("RIRTooltipBloop.tooltipKey(for: rir)"),
            "Genau der Erklaertext (tooltipKey) muss an der Einstellung haengen."
        )
    }

    /// AI-01: Die Erfassung darf fuer „KI nicht verfuegbar" nicht mehr einen
    /// einzigen Sammeltext fuer alle Gruende zeigen.
    func testAddMealUsesOneReasonTextPerAIUnavailability() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        XCTAssertTrue(
            source.contains("unavailableReasonKey"),
            "AddMealView.aiSection muss den Grund aus NutritionAIAvailability aufloesen, statt alles "
                + "als 'Geraet nicht verfuegbar' zu beschreiben."
        )
        let oldUmbrellaKey = "nutrition.addMeal.aiDraft.unavailable\""
        XCTAssertFalse(
            source.contains(oldUmbrellaKey),
            "Der alte Sammeltext zeigt 'auf diesem Geraet nicht verfuegbar' auch bei Sprach-/Temp-Faellen."
        )
    }
}
