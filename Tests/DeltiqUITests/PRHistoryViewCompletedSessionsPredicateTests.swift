import XCTest

/// Modul-12-Audit (History), Fund 1. `completedSessions` (gated den
/// Rebuild-Button + Empty-State-CTA) zaehlte bisher Rest-Tag-Marker
/// (isCompleted=true, isRestDay=true) mit, obwohl `PersonalRecordSync.
/// rebuild(in:)` selbst diese nie beruecksichtigt - ein Nutzer, der nur
/// Rest-Tage uebersprungen hat, sah dadurch eine aktivierte CTA, die
/// garantiert nichts findet. Quelltext-Pruefung, da `completedSessions`
/// `private` auf einer View ist.
final class PRHistoryViewCompletedSessionsPredicateTests: XCTestCase {
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

    func testCompletedSessionsExcludesRestDayMarkersLikePersonalRecordSyncRebuild() throws {
        let text = try source
        guard let predicateStart = text.range(of: "#Predicate<WorkoutSession> {") else {
            return XCTFail("completedSessions predicate not found - this file should declare it exactly once")
        }
        guard let predicateEnd = text.range(of: "})", range: predicateStart.upperBound..<text.endIndex) else {
            return XCTFail("end of completedSessions predicate not found")
        }
        let predicate = text[predicateStart.upperBound..<predicateEnd.lowerBound]

        XCTAssertTrue(predicate.contains("isCompleted == true"))
        XCTAssertTrue(predicate.contains("isRestDay == false"),
                      "must exclude rest-day markers, matching PersonalRecordSync.rebuild(in:)'s own predicate")

        guard let queryRange = text.range(of: "@Query(filter:", range: text.startIndex..<predicateStart.lowerBound) else {
            return XCTFail("predicate must belong to a @Query(filter:) declaration")
        }
        guard let varRange = text.range(of: "private var completedSessions: [WorkoutSession]", range: predicateEnd.upperBound..<text.endIndex) else {
            return XCTFail("predicate must be immediately followed by the completedSessions property")
        }
        XCTAssertTrue(queryRange.lowerBound < predicateStart.lowerBound && varRange.lowerBound > predicateEnd.upperBound)
    }
}
