import XCTest

/// Audit-Fund (Modul e, WorkoutSummaryView+Health-Export). `WorkoutSummaryView`
/// hatte in der gesamten Datei (2697 Zeilen) keine einzige `.accessibilityHidden`-
/// Annotation: weder das grosse Status-Icon im `heroSection` noch die ueber
/// `.deltiqIconBadge()` gerenderten Icons in PRBadge/AchievementBadge/
/// ProgressionBadge, obwohl in allen Faellen direkt daneben/darunter stehender
/// Text (Titel bzw. Uebungsname/Art/Detail) den Inhalt bereits vollstaendig
/// traegt - Nachbar-Dateien im selben Modul (PlansListView.swift) wenden das
/// Muster konsequent an.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ExerciseDetailPRIconAccessibilityTests).
final class WorkoutSummaryBadgeIconsAccessibilityTests: XCTestCase {
    private var workoutSummarySource: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    private var themeSource: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Theme.swift"),
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

    func testHeroSectionHidesStatusIconFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try workoutSummarySource)

        guard let start = cleaned.range(of: "private var heroSection: some View {") else {
            return XCTFail("heroSection not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of heroSection not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: isEarlySaveTimedFormat") else {
            return XCTFail("hero status icon not found")
        }
        guard let titleRange = body.range(of: "Text(isEarlySaveTimedFormat", range: iconRange.upperBound..<body.endIndex) else {
            return XCTFail("hero title text not found after the icon")
        }
        let betweenIconAndTitle = body[iconRange.upperBound..<titleRange.lowerBound]
        XCTAssertTrue(betweenIconAndTitle.contains(".accessibilityHidden(true)"),
                      "the hero status icon must be hidden from VoiceOver - the title text right after it already announces the completion state")
    }

    func testDeltiqIconBadgeModifierHidesIconFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try themeSource)

        guard let start = cleaned.range(of: "public struct DeltiqIconBadgeModifier: ViewModifier {") else {
            return XCTFail("DeltiqIconBadgeModifier not found")
        }
        guard let bodyStart = cleaned.range(of: "public func body(content: Content) -> some View {", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("DeltiqIconBadgeModifier.body not found")
        }
        guard let end = cleaned.range(of: "\n    }", range: bodyStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of DeltiqIconBadgeModifier.body not found")
        }
        let body = cleaned[bodyStart.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains(".accessibilityHidden(true)"),
                      "DeltiqIconBadgeModifier must hide its icon from VoiceOver - all three call sites (PRBadge/AchievementBadge/ProgressionBadge) place it next to text that already describes the content")
    }
}
