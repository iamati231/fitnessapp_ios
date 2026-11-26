#if canImport(SwiftUI) && canImport(UIKit)
import XCTest

/// Audit-Fund Modul 21 (PlanBuilderView). `resultDayRow` trug
/// `.accessibilityElement(children: .combine)` auf dem GESAMTEN Block
/// (Kopfzeile inkl. "..."-Menu + komplette Uebungsliste mit je einem
/// eigenen "Alternative waehlen"-Button) - das buendelte laut SwiftUI-Doku
/// ALLE Kind-Elemente zu einem einzigen Accessibility-Element und machte
/// Menu und Uebungs-Buttons fuer VoiceOver nicht mehr einzeln erreichbar.
///
/// Source-inspection test (kein SwiftUI-Render-Harness in diesem Repo),
/// nutzt denselben Brace-Matching-Helper wie
/// `PlanBuilderResultDayRowTemplateAlignmentTests`. Assertions matchen die
/// VOLLE API-Call-Syntax statt blosser Schluesselwoerter, um nicht mit den
/// erklaerenden Audit-Fund-Kommentaren direkt daneben zu kollidieren
/// (Modul-11/19/20-Pitfall).
final class PlanBuilderResultDayRowAccessibilityTests: XCTestCase {

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
        let openBraceIndex: String.Index
        if marker.trimmingCharacters(in: .whitespaces).hasSuffix("{") {
            openBraceIndex = source.index(before: markerRange.upperBound)
        } else {
            guard let found = source[markerRange.upperBound...].firstIndex(of: "{") else {
                XCTFail("no opening brace found after \(marker)")
                return ""
            }
            openBraceIndex = found
        }
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: source.index(after: openBraceIndex)) else {
            XCTFail("could not brace-match the body following \(marker)")
            return ""
        }
        return body
    }

    func testResultDayRowDoesNotCombineTheWholeBlockIntoOneElement() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let resultDayRowBody = try functionBody(
            startingAt: "private func resultDayRow(_ day: DraftDay, loadLevel: PlanLoadLevel?) -> some View {",
            in: source
        )
        XCTAssertFalse(
            resultDayRowBody.contains("accessibilityElement(children: .combine)"),
            "resultDayRow's own body must not merge the whole block (header menu + every exercise button) into one VoiceOver element"
        )
        XCTAssertTrue(
            resultDayRowBody.contains("accessibilityElement(children: .contain)"),
            "resultDayRow must still group for navigation via .contain, without swallowing its interactive children"
        )
        XCTAssertFalse(
            resultDayRowBody.contains("accessibilityLabel(resultDayRowAccessibilityLabel("),
            "the summarizing label must move to the static header sub-view, not stay on the whole row"
        )
    }

    func testResultDayHeaderRowCombinesOnlyItsStaticNameAndScopeIntoOneSummaryLabel() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let headerBody = try functionBody(
            startingAt: "private func resultDayHeaderRow(spec: DaySpec, day: DraftDay, loadLevel: PlanLoadLevel?, currentIndex: Int, totalDays: Int) -> some View {",
            in: source
        )
        XCTAssertTrue(
            headerBody.contains("accessibilityElement(children: .combine)"),
            "the static name/badges/scope sub-view must combine into one summarizing VoiceOver element"
        )
        XCTAssertTrue(
            headerBody.contains("accessibilityLabel(resultDayRowAccessibilityLabel("),
            "the summary label content is unchanged, only its placement moved"
        )
        XCTAssertTrue(
            headerBody.contains("accessibilityLabel(Text(\"planBuilder.result.dayActions\""),
            "the \"...\" actions menu must keep its own, separately reachable accessibility label"
        )
    }
}
#endif
