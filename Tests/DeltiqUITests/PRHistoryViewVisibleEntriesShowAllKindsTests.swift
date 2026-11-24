import XCTest

/// Modul-12-Audit (History), Fund 2. `visibleEntries` feeds the list headed
/// "prHistory.allRecords" ("All records"/"Alle Rekorde"/"Tüm rekorlar").
/// It used to additionally filter by `chartKind` (the local chart-picker
/// selection) whenever no global filter chip was active, so the list
/// labeled "all" actually only ever showed ONE kind - the one the trend
/// chart happened to be pointed at. `PRHistoryRow` renders a per-row kind
/// icon/label specifically because the list is meant to contain mixed
/// kinds. Quelltext-Pruefung, da `visibleEntries` `private` auf einer View
/// ist.
final class PRHistoryViewVisibleEntriesShowAllKindsTests: XCTestCase {
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

    func testVisibleEntriesReturnsAllGroupEntriesWithoutFilteringByChartKind() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private var visibleEntries: [PersonalRecordEntry] {") else {
            return XCTFail("visibleEntries not found")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of visibleEntries not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("chartKind"),
                       "visibleEntries must not narrow the \"all records\" list down to the chart's single selected kind")
        XCTAssertTrue(body.trimmingCharacters(in: .whitespacesAndNewlines) == "group.entries",
                      "visibleEntries must show every entry already scoped by the global filter upstream in `grouped`")
    }
}
