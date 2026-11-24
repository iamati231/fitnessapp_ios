import XCTest

/// Modul-12-Audit (History): `totalDistanceText`/`averagePaceText`
/// (WorkoutHistoryView) und `formattedTotalDistance`/`formattedAvgPace`
/// (WorkoutSummaryView) summierten bisher `session.logs` roh, inkl. Warmup-/
/// Cooldown-Cardio-Saetzen (DEL-087 `role` ist bei Cardio-Uebungen ebenso
/// moeglich wie bei Kraft) - dieselbe Luecke, die `workingSetLogs` fuer
/// Dashboard/PR-Detection bereits schliesst (SessionAggregation.swift,
/// Modul-9-Audit). Quelltext-Pruefung, weil beide Properties `private` auf
/// einer View sind.
final class WorkoutDistanceExcludesNonWorkingSetsTests: XCTestCase {
    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private static func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testWorkoutHistoryViewDistanceAndPaceUseWorkingSetLogs() throws {
        let text = try source("Sources/DeltiqUI/History/WorkoutHistoryView.swift")

        let distanceBody = try Self.body(of: "private var totalDistanceText: String {", in: text)
        XCTAssertTrue(distanceBody.contains("session.workingSetLogs"),
                      "totalDistanceText must exclude warmup/cooldown sets via workingSetLogs")
        XCTAssertFalse(distanceBody.contains("session.logs.compactMap"),
                       "must not sum raw session.logs")

        let paceBody = try Self.body(of: "private var averagePaceText: String {", in: text)
        XCTAssertTrue(paceBody.contains("session.workingSetLogs"),
                      "averagePaceText must exclude warmup/cooldown sets via workingSetLogs")
        XCTAssertFalse(paceBody.contains("session.logs.compactMap"),
                       "must not sum raw session.logs")
    }

    func testWorkoutSummaryViewDistanceAndPaceUseWorkingSetLogs() throws {
        let text = try source("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift")

        let distanceBody = try Self.body(of: "private var formattedTotalDistance: String {", in: text)
        XCTAssertTrue(distanceBody.contains("session.workingSetLogs"),
                      "formattedTotalDistance must exclude warmup/cooldown sets via workingSetLogs")
        XCTAssertFalse(distanceBody.contains("session.logs.compactMap"),
                       "must not sum raw session.logs")

        let paceBody = try Self.body(of: "private var formattedAvgPace: String {", in: text)
        XCTAssertTrue(paceBody.contains("session.workingSetLogs"),
                      "formattedAvgPace must exclude warmup/cooldown sets via workingSetLogs")
        XCTAssertFalse(paceBody.contains("session.logs.compactMap"),
                       "must not sum raw session.logs")
    }
}
