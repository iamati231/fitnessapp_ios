import XCTest

/// Modul-8-Audit (Workout-Ausfuehrung): `WorkoutSummaryView`s eigene
/// `sessionLifts`/`historicalLifts` (PR-Vorschau-Badge direkt nach dem
/// Training) fuetterten `PRDetector` bisher ohne Rollen-Filter - ein
/// Warmup-/Cooldown-Satz konnte das Badge zeigen, obwohl `PersonalRecordSync`
/// (derselbe Audit-Fund, siehe `PersonalRecordSyncTests.
/// testWarmupSetNeverProducesAPersonalRecord`) denselben PR nie persistiert
/// haette - ein Widerspruch zwischen Vorschau und Trophy-Room. Quelltext-
/// Pruefung, weil diese beiden Properties keinen Test-Seam ausserhalb eines
/// echten `WorkoutSummaryView`-Renders haben.
final class WorkoutSummaryViewPRPreviewRoleFilterTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // this file
                    .deletingLastPathComponent() // DeltiqUITests
                    .deletingLastPathComponent() // Tests
                    .appendingPathComponent("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    func testSessionLiftsExcludesNonWorkingSetLogs() throws {
        let text = try source
        guard let propStart = text.range(of: "private var sessionLifts: [LiftAttempt] {") else {
            return XCTFail("sessionLifts not found at the expected signature")
        }
        guard let propEnd = text.range(of: "\n    }", range: propStart.upperBound..<text.endIndex) else {
            return XCTFail("sessionLifts's end not found")
        }
        let body = text[propStart.upperBound..<propEnd.lowerBound]
        XCTAssertTrue(body.contains("log.resolvedIsWorkingSet"),
                     "sessionLifts must exclude warmup/cooldown logs via resolvedIsWorkingSet")
    }

    func testHistoricalLiftsExcludesNonWorkingSetLogs() throws {
        let text = try source
        guard let propStart = text.range(of: "private var historicalLifts: [LiftAttempt] {") else {
            return XCTFail("historicalLifts not found at the expected signature")
        }
        guard let propEnd = text.range(of: "\n    }", range: propStart.upperBound..<text.endIndex) else {
            return XCTFail("historicalLifts's end not found")
        }
        let body = text[propStart.upperBound..<propEnd.lowerBound]
        XCTAssertTrue(body.contains("log.resolvedIsWorkingSet"),
                     "historicalLifts must exclude warmup/cooldown logs via resolvedIsWorkingSet, so a heavy warmup never blocks a later genuine PR")
    }
}
