import XCTest

/// writing-block.md Punkt 4.1 ("Mahlzeittyp-Auswahl bricht in mehrere
/// Zeilen um"): `DeltiqSegmentedPicker`'s label `Text` had no `.lineLimit`,
/// so on a narrow iPhone with 4 equal-width segments, a longer DE/TR
/// translation ("Abendessen", "Öğle Yemeği") wrapped onto a second line
/// instead of staying compact. Same fix category, same source-introspection
/// test style, as the already-fixed `deltiqLabel()` wrapping bug (see
/// `DeltiqLabelScalesDownInsteadOfWrappingTests`) — reads the production
/// source directly from disk, no SwiftUI import needed, runs on any
/// platform `swift test` runs on.
final class DeltiqSegmentedPickerScalesDownInsteadOfWrappingTests: XCTestCase {
    private var themeSourceFile: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI/Theme.swift")
    }

    func testDeltiqSegmentedPickerAllowsTheLabelToShrinkInsteadOfWrapping() throws {
        let contents = try String(contentsOf: themeSourceFile, encoding: .utf8)

        guard let structRange = contents.range(of: "public struct DeltiqSegmentedPicker<Value: Hashable>: View {") else {
            XCTFail("DeltiqSegmentedPicker nicht gefunden - hat sich Theme.swift strukturell geaendert?")
            return
        }
        guard let bodyRange = contents[structRange.upperBound...].range(of: "public var body: some View {") else {
            XCTFail("DeltiqSegmentedPicker.body nicht gefunden")
            return
        }
        guard let closingBraceOffset = contents[bodyRange.upperBound...].range(of: "\n    }\n}") else {
            XCTFail("Ende von DeltiqSegmentedPicker.body nicht gefunden")
            return
        }
        let bodyText = contents[bodyRange.upperBound..<closingBraceOffset.lowerBound]

        XCTAssertTrue(
            bodyText.contains(".lineLimit(1)"),
            "DeltiqSegmentedPicker sollte sein Label mit .lineLimit(1) begrenzen, damit laengere DE/TR-"
                + "Uebersetzungen nicht in mehrere Zeilen umbrechen."
        )
        XCTAssertTrue(
            bodyText.contains(".minimumScaleFactor("),
            "DeltiqSegmentedPicker sollte .minimumScaleFactor(...) setzen, damit die Schrift bei Bedarf "
                + "schrumpft statt umzubrechen."
        )
    }
}
