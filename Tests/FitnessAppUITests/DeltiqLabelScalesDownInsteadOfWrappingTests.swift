import XCTest

/// Deltiq-Geraeteabnahme (Runde 8, docs/DELTIQ_DEVICE_ACCEPTANCE.md, E04): bei
/// maximaler Bedienungshilfen-Textgroesse (AX5, per Geraete-Nachtest in
/// Deutsch reproduziert) brach der Spalten-Header "SATZ" in `SetRow`s
/// festbreitem `setNumberWidth`-Rahmen buchstabenweise um (S/a/t/z
/// untereinander statt einer Zeile), weil `deltiqLabel()`s `.caption2`-
/// Textstil ungebremst mit der Systemschrift mitskaliert. Fix:
/// `.lineLimit(1)` + `.minimumScaleFactor(...)` auf dem gemeinsamen
/// `deltiqLabel()`-Helfer selbst (genutzt von "KG"/"WDH"/"PACE"/"RIR"/"SATZ"
/// und weiteren kurzen Captions app-weit), identisches Muster wie der
/// bereits gefixte `SetRow.weightInput` (Runde 3).
///
/// Liest die Produktionsquelle direkt von der Platte (kein SwiftUI-Import
/// noetig, laeuft auch auf Linux) und prueft genau den `deltiqLabel()`-
/// Funktionskoerper.
final class DeltiqLabelScalesDownInsteadOfWrappingTests: XCTestCase {
    private var compatibilitySourceFile: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI/Compatibility.swift")
    }

    func testDeltiqLabelAllowsTheFontToShrinkInsteadOfWrapping() throws {
        let contents = try String(contentsOf: compatibilitySourceFile, encoding: .utf8)

        guard let functionRange = contents.range(of: "func deltiqLabel() -> some View {") else {
            XCTFail("deltiqLabel() nicht gefunden - hat sich Compatibility.swift strukturell geaendert?")
            return
        }
        guard let closingBraceOffset = contents[functionRange.upperBound...].range(of: "\n    }") else {
            XCTFail("Ende von deltiqLabel() nicht gefunden")
            return
        }
        let functionBody = contents[functionRange.upperBound..<closingBraceOffset.lowerBound]

        XCTAssertTrue(
            functionBody.contains(".lineLimit(1)"),
            "deltiqLabel() sollte .lineLimit(1) setzen, damit kurze Captions bei grosser Dynamic-Type-"
                + "Einstellung nicht buchstabenweise umbrechen."
        )
        XCTAssertTrue(
            functionBody.contains(".minimumScaleFactor("),
            "deltiqLabel() sollte .minimumScaleFactor(...) setzen, damit die Schrift bei Bedarf schrumpft "
                + "statt in einem festbreiten Rahmen umzubrechen."
        )
    }
}
