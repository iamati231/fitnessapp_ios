import XCTest

/// Issue #47: `DeltiqPeriodPicker`-Labels duerfen auf schmalen iPhones nicht
/// umbrechen (z.B. DE-"Gesamt", TR-"Tümü"). Analog zu
/// `DeltiqSegmentedPickerScalesDownInsteadOfWrappingTests` — liest den
/// Produktionscode direkt vom Disk, kein SwiftUI-Import noetig.
final class DeltiqPeriodPickerScalesDownInsteadOfWrappingTests: XCTestCase {
    private var themeSourceFile: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI/Theme.swift")
    }

    func testDeltiqPeriodPickerAllowsTheLabelToShrinkInsteadOfWrapping() throws {
        let contents = try String(contentsOf: themeSourceFile, encoding: .utf8)

        guard let structRange = contents.range(of: "public struct DeltiqPeriodPicker<T: Hashable>: View {") else {
            XCTFail("DeltiqPeriodPicker nicht gefunden - hat sich Theme.swift strukturell geaendert?")
            return
        }
        guard let bodyRange = contents[structRange.upperBound...].range(of: "public var body: some View {") else {
            XCTFail("DeltiqPeriodPicker.body nicht gefunden")
            return
        }
        guard let closingBrace = contents[bodyRange.upperBound...].range(of: "\n    }\n}") else {
            XCTFail("Ende von DeltiqPeriodPicker.body nicht gefunden")
            return
        }
        let bodyText = contents[bodyRange.upperBound..<closingBrace.lowerBound]

        XCTAssertTrue(
            bodyText.contains(".lineLimit(1)"),
            "DeltiqPeriodPicker sollte sein Label mit .lineLimit(1) begrenzen, damit laengere DE/TR-"
                + "Uebersetzungen nicht in mehrere Zeilen umbrechen."
        )
        XCTAssertTrue(
            bodyText.contains(".minimumScaleFactor("),
            "DeltiqPeriodPicker sollte .minimumScaleFactor(...) setzen, damit die Schrift bei Bedarf "
                + "schrumpft statt umzubrechen."
        )
    }
}
