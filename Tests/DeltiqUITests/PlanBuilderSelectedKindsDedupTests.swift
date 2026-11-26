#if canImport(SwiftUI) && canImport(UIKit)
import XCTest

/// Audit-Fund (Modul 21, PlanBuilderView). `init(initialInput:)` seeded
/// `selectedKinds` directly via `.map(\.kind)` without deduplication, while
/// `configByKind` right next to it goes through `Dictionary(uniquingKeysWith:)`
/// for exactly this reason (see its own comment: "defensiv gegen einen Input
/// mit zwei Selections derselben Kind"). A caller passing two selections of
/// the same kind produced a duplicate `ForEach(selectedKinds, id: \.self)`
/// identity.
///
/// No ViewInspector/XCUITest harness - follows the established
/// source-inspection pattern (see PlanBuilderResultDayRowTemplateAlignmentTests).
final class PlanBuilderSelectedKindsDedupTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
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

    private func functionBody(startingAt marker: String, in source: String) throws -> String {
        guard let markerRange = source.range(of: marker) else {
            XCTFail("\(marker) not found")
            return ""
        }
        guard let openBraceIndex = source[markerRange.upperBound...].firstIndex(of: "{") else {
            XCTFail("no opening brace found after \(marker)")
            return ""
        }
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: source.index(after: openBraceIndex)) else {
            XCTFail("could not brace-match the body following \(marker)")
            return ""
        }
        return body
    }

    /// Strips `//`-comment text before checking code patterns - this fix's
    /// own explanatory comment is adjacent to the code it describes, and a
    /// naive raw-text `.contains()` has caused false positives/negatives in
    /// earlier modules of this audit (see memory: Modul 11/19 pitfall).
    private func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentStart = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentStart.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testSelectedKindsIsDeduplicatedLikeConfigByKind() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let initBody = try functionBody(startingAt: "public init(", in: source)
        let code = codeOnly(initBody)

        XCTAssertFalse(
            code.contains("_selectedKinds = State(initialValue: initialInput.selections.map(\\.kind))"),
            "selectedKinds must no longer be seeded from the raw, non-deduplicated selections array"
        )
        XCTAssertTrue(
            code.contains("Set<TrainingTypeKind>"),
            "selectedKinds seeding must use a dedup mechanism (a Set of seen kinds), matching configByKind's own Dictionary(uniquingKeysWith:) safeguard"
        )
        XCTAssertTrue(
            code.contains("_configByKind = State(initialValue: Dictionary("),
            "sanity check: configByKind's existing dedup must still be in place"
        )
    }
}
#endif
