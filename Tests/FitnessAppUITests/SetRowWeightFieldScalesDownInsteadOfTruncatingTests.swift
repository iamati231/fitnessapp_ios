import XCTest

/// Deltiq-Geraeteabnahme (E04): bei der groessten Dynamic-Type-Einstellung
/// (Accessibility-Textgroessen, per Geraete-Nachtest reproduziert) schnitt ein
/// Dezimalgewicht wie "72,5" im festbreiten KG-Eingabefeld des Satz-Loggings
/// zu "7..." ab. Fix: `.minimumScaleFactor(...)` auf `SetRow.weightInput`,
/// damit SwiftUI den Text bei Bedarf verkleinert statt abzuschneiden.
///
/// Liest die Produktionsquelle direkt von der Platte (kein SwiftUI-Import
/// noetig, laeuft auch auf Linux) und prueft genau den betroffenen
/// `weightInput`-Abschnitt, nicht die ganze Datei - andere Felder (z.B.
/// `repsInput`) wurden in dieser Runde nicht als abgeschnitten beobachtet und
/// absichtlich nicht mitgeaendert.
final class SetRowWeightFieldScalesDownInsteadOfTruncatingTests: XCTestCase {
    private var setRowSourceFile: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI/Workout/SetRow.swift")
    }

    func testWeightInputAllowsTheFontToShrinkInsteadOfTruncating() throws {
        let contents = try String(contentsOf: setRowSourceFile, encoding: .utf8)

        guard let propertyRange = contents.range(of: "private var weightInput: some View {"),
              let placeholderRange = contents.range(of: "private var weightPlaceholder: String {")
        else {
            XCTFail("weightInput/weightPlaceholder nicht gefunden - hat sich SetRow.swift strukturell geaendert?")
            return
        }
        let weightInputBody = contents[propertyRange.lowerBound..<placeholderRange.lowerBound]

        XCTAssertTrue(
            weightInputBody.contains(".minimumScaleFactor("),
            "SetRow.weightInput sollte .minimumScaleFactor(...) setzen, damit ein langes Dezimalgewicht "
                + "bei grosser Dynamic-Type-Einstellung schrumpft statt mit \"...\" abgeschnitten zu werden."
        )
    }
}
