import XCTest

/// Modul-12-Audit (History), Fund 3. `chartKind` (lokale Chart-Picker-
/// Auswahl) wurde nur bei `.onAppear` auf `uniqueKinds.first` gesetzt.
/// Wechselte der Nutzer bei bereits aufgeklappter Karte den globalen
/// Filter-Chip, blieb `chartKind` auf seinem alten Wert stehen - `chartPoints`
/// filtert `group.entries` (jetzt auf den neuen `selectedKind` eingeschraenkt)
/// weiter nach dem veralteten `chartKind` und wurde leer, der Chart zeigte
/// dann buchstaeblich nichts. Quelltext-Pruefung, da `expansionContent`
/// `private` auf einer View ist.
final class PRHistoryViewChartKindResyncTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/History/PRHistoryView.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testExpansionContentResyncsChartKindWhenGlobalFilterChanges() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private var expansionContent: some View {") else {
            return XCTFail("expansionContent not found")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of expansionContent not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let onAppearRange = body.range(of: "chartKind = uniqueKinds.first ?? chartKind") else {
            return XCTFail("the existing .onAppear resync was not found")
        }

        guard let onChangeRange = body.range(of: ".onChange(of: selectedKind)", range: onAppearRange.upperBound..<body.endIndex) else {
            return XCTFail("must resync chartKind when the global filter chip (selectedKind) changes while the card is already expanded")
        }
        guard let onChangeEnd = body.range(of: "\n        }", range: onChangeRange.upperBound..<body.endIndex) else {
            return XCTFail("end of .onChange block not found")
        }
        let onChangeBody = body[onChangeRange.upperBound..<onChangeEnd.lowerBound]
        XCTAssertTrue(onChangeBody.contains("chartKind = uniqueKinds.first ?? chartKind"),
                      "must reset chartKind the same way .onAppear does")
    }
}
