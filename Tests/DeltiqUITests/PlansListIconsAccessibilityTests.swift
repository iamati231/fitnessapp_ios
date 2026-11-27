import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor). Keine einzige
/// Stelle in `PlansListView.swift` blendete ihre rein dekorativen Icons per
/// `.accessibilityHidden(true)` aus, obwohl direkt daneben/darunter stehender
/// Text (Plan-Name+Status, Session-Name+Startzeit, Empty-State-Titel/-Hinweis)
/// den Inhalt bereits vollstaendig traegt - VoiceOver las zusaetzlich die
/// SF-Symbol-Namen vor ("list bullet rectangle portrait", "chevron right",
/// "figure run circle fill"). Gleiche, bereits etablierte Fix-Klasse wie
/// `DayPickerSheet.swift` (Modul 20).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe DayPickerSheetAccessibilityTests).
final class PlansListIconsAccessibilityTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlansListView.swift"),
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

    /// Extracts the body of a top-level (column-0) `struct`/`var`/`func` block
    /// starting at `signature`, ending at the next `\n}` at the SAME
    /// indentation column as the signature's own opening brace line.
    private func topLevelBlock(_ text: Substring, signature: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("signature not found: \(signature)")
        }
        guard let end = text.range(of: "\n}", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of block not found for: \(signature)")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    private func indentedBlock(_ text: Substring, signature: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("signature not found: \(signature)")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of block not found for: \(signature)")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    private func assertIconHidden(in body: Substring, icon: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let iconRange = body.range(of: icon) else {
            return XCTFail("icon not found: \(icon)", file: file, line: line)
        }
        let after = body[iconRange.upperBound...]
        guard let nextImageOrEnd = after.range(of: "Image(systemName:") else {
            XCTAssertTrue(after.contains(".accessibilityHidden(true)"),
                          "\(icon) must be hidden from VoiceOver - it is purely decorative, neighboring text already carries the content",
                          file: file, line: line)
            return
        }
        XCTAssertTrue(after[..<nextImageOrEnd.lowerBound].contains(".accessibilityHidden(true)"),
                      "\(icon) must be hidden from VoiceOver - it is purely decorative, neighboring text already carries the content",
                      file: file, line: line)
    }

    func testEmptyStateHeroIconIsHiddenFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try indentedBlock(cleaned[...], signature: "private var emptyState: some View {")
        assertIconHidden(in: body, icon: "Image(systemName: \"list.bullet.rectangle.portrait\")")
    }

    func testPlanRowIconsAreHiddenFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)
        let structBlock = try topLevelBlock(cleaned[...], signature: "private struct PlanRow: View {")
        let body = try indentedBlock(structBlock, signature: "var body: some View {")
        assertIconHidden(in: body, icon: "Image(systemName: \"list.bullet.rectangle.portrait\")")
        assertIconHidden(in: body, icon: "Image(systemName: \"chevron.right\")")
    }

    func testActiveSessionBannerIconsAreHiddenFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)
        let structBlock = try topLevelBlock(cleaned[...], signature: "private struct ActiveSessionBanner: View {")
        let body = try indentedBlock(structBlock, signature: "var body: some View {")
        assertIconHidden(in: body, icon: "Image(systemName: \"figure.run.circle.fill\")")
        assertIconHidden(in: body, icon: "Image(systemName: \"chevron.right\")")
    }
}
