import XCTest

/// Modul-12-Audit (History), Fund 5. `grouped` sortiert Exercise-Trophy-
/// Gruppen nach `latestDate` absteigend, aber `byExercise` (die Quelle) ist
/// ein `Dictionary` mit nicht garantiert stabiler Iterationsreihenfolge -
/// bei einem echten `latestDate`-Gleichstand (z.B. mehrere PRs aus einem
/// Rebuild-Lauf) konnte die Reihenfolge zwischen App-Starts wechseln.
/// Gleiche Luecke wie bei `StrengthProgressCalculator`/
/// `MuscleGroupProgressCalculator` (PR #58/#59) - dort durch einen
/// deterministischen Tie-Breaker behoben. Quelltext-Pruefung, da `grouped`
/// `private` auf einer View ist.
final class PRHistoryViewGroupedSortDeterminismTests: XCTestCase {
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

    func testGroupedSortHasADeterministicTiebreakerForEqualLatestDates() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private var grouped: [ExerciseTrophyGroup] {") else {
            return XCTFail("grouped not found")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of grouped not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        // NOTE: `grouped` also contains an inner `rows.sorted { $0.date > $1.date }` -
        // search specifically for the final, latestDate-based sort to avoid matching that one.
        guard let sortRange = body.range(of: ".sorted { $0.latestDate") else {
            return XCTFail("final .sorted call (by latestDate) not found")
        }
        let sortCall = body[sortRange.lowerBound...]

        XCTAssertTrue(sortCall.contains("latestDate != $1.latestDate"),
                      "the sort must branch on whether latestDate actually differs before falling back to a tiebreaker")
        XCTAssertTrue(sortCall.contains("$0.id < $1.id"),
                      "a tied latestDate must fall back to the group's stable id, not Dictionary iteration order")
    }
}
