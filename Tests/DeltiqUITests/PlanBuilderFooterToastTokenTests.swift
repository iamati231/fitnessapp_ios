import XCTest

/// Audit-Fund (Modul 21, PlanBuilderView). `showFooterToast(_:systemImage:)`
/// startete pro Aufruf einen eigenen Dismiss-Task, der nach fest 2,5s
/// `footerToastMessage = nil` setzte, ohne zu pruefen, ob die sichtbare
/// Nachricht noch dieselbe ist, die dieser Task urspruenglich eingeblendet
/// hat - ein zweiter, schneller aufeinanderfolgender Toast wurde dadurch vom
/// aelteren Dismiss-Task vorzeitig geloescht.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class PlanBuilderFooterToastTokenTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlanBuilderView.swift"),
                encoding: .utf8
            )
        }
    }

    func testShowFooterToastGuardsDismissWithAToken() throws {
        let text = try source
        guard let start = text.range(of: "private func showFooterToast(_ message: String, systemImage: String) {") else {
            return XCTFail("showFooterToast(_:systemImage:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of showFooterToast(_:systemImage:) not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        // Strip "//"-comments: this function's own explanatory comment could
        // otherwise make the .contains() checks below false positives against
        // prose instead of code (recurring pitfall in this codebase).
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertTrue(code.contains("let token = UUID()"),
                       "each call must mint its own identity before scheduling the dismiss")
        XCTAssertTrue(code.contains("footerToastToken = token"),
                      "the new token must be recorded as the currently-displayed toast's identity")
        XCTAssertTrue(code.contains("guard footerToastToken == token else { return }"),
                      "the delayed dismiss must only clear the message if no newer toast has replaced it")
    }

    func testFooterToastTokenStateExists() throws {
        let text = try source
        XCTAssertTrue(text.contains("@State private var footerToastToken: UUID?"),
                      "footerToastToken must be declared as view state alongside footerToastMessage")
    }
}
