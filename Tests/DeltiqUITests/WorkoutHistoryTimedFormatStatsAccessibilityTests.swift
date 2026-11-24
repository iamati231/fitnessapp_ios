import XCTest

/// Modul-12-Audit (History), Fund 2/2. `HistorySessionRow.statsLine` hat vier
/// Zweige (Zeitformat, pureCardio, mixed, pureStrength) - drei davon blenden
/// jedes dekorative Icon + "•" per `.accessibilityHidden(true)` aus, der
/// Zeitformat-Zweig (AMRAP/EMOM/Auf Zeit/Zirkel/Ausdauer-Intervalle) tat das
/// nicht: VoiceOver las "clock", das Format-Icon und "bullet" zwischen den
/// echten Werten mit vor. Quelltext-Pruefung, da `statsLine` `private` auf
/// einer View ist.
final class WorkoutHistoryTimedFormatStatsAccessibilityTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/History/WorkoutHistoryView.swift"),
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

    func testTimedFormatBranchHidesDecorativeIconsAndBulletFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)

        guard let branchStart = cleaned.range(of: "if let format = session.timeFormatSnapshot {") else {
            return XCTFail("timed-format branch of statsLine not found")
        }
        guard let branchEnd = cleaned.range(of: "} else {", range: branchStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of timed-format branch not found")
        }
        let branch = cleaned[branchStart.upperBound..<branchEnd.lowerBound]

        guard let clockRange = branch.range(of: "Image(systemName: \"clock\")") else {
            return XCTFail("clock icon not found")
        }
        XCTAssertTrue(branch[clockRange.upperBound...].hasPrefix(".accessibilityHidden(true)"),
                      "the clock icon must be hidden from VoiceOver, matching the other three statsLine branches")

        guard let bulletRange = branch.range(of: "Text(\"\u{2022}\")") else {
            return XCTFail("bullet separator not found")
        }
        XCTAssertTrue(branch[bulletRange.upperBound...].hasPrefix(".accessibilityHidden(true)"),
                      "the bullet separator must be hidden from VoiceOver, matching the other three statsLine branches")

        guard let formatIconRange = branch.range(of: "Image(systemName: timedFormatIcon(format))") else {
            return XCTFail("format icon not found")
        }
        XCTAssertTrue(branch[formatIconRange.upperBound...].hasPrefix(".accessibilityHidden(true)"),
                      "the format icon must be hidden from VoiceOver, matching the other three statsLine branches")
    }
}
