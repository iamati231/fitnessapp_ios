#if canImport(SwiftUI) && canImport(UIKit)
import XCTest

/// Audit-Fund: `PlansListView.duplicatePlan`'s `dayCopy` carried over
/// `timeFormat` and the three `circuit*` fields, but none of the seven
/// `endurance*` fields (`TrainingDay.swift` lines 45-58) - a duplicated
/// `.enduranceIntervals` day kept its time format but silently lost
/// rounds/warmup/cooldown/rest/distance/sport-kind, falling back to the
/// generic defaults in `EnduranceIntervalPlayerView`. Source-introspection
/// (kein SwiftUI-Render-Harness in diesem Repo, `duplicatePlan` ist
/// `private`), gleiches Muster wie `PlansListViewDuplicatePlanTests`.
final class PlansListViewDuplicatePlanEnduranceFieldsTests: XCTestCase {

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

    func test_plansListView_duplicatePlan_dayCopy_passesThroughAllEnduranceFields() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let dayCopyRange = source.range(of: "let dayCopy = TrainingDay(") else {
            XCTFail("dayCopy construction not found in duplicatePlan"); return
        }
        guard let closingParen = source.range(of: "\n            )", range: dayCopyRange.upperBound..<source.endIndex) else {
            XCTFail("end of dayCopy initializer call not found"); return
        }
        let initializerArguments = source[dayCopyRange.upperBound..<closingParen.lowerBound]

        let expectedArguments = [
            "enduranceWarmupDurationSeconds: day.enduranceWarmupDurationSeconds",
            "enduranceCooldownDurationSeconds: day.enduranceCooldownDurationSeconds",
            "enduranceIntervalRounds: day.enduranceIntervalRounds",
            "enduranceWorkDurationSeconds: day.enduranceWorkDurationSeconds",
            "enduranceWorkDistanceKm: day.enduranceWorkDistanceKm",
            "enduranceRestDurationSeconds: day.enduranceRestDurationSeconds",
            "enduranceSportKind: day.enduranceSportKind",
        ]
        for argument in expectedArguments {
            XCTAssertTrue(
                initializerArguments.contains(argument),
                "dayCopy must explicitly pass through \(argument), not silently default it to nil"
            )
        }
    }
}
#endif
