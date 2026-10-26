#if canImport(SwiftUI)
import XCTest

/// Phase B (Laufcoaching Dual-Path, Task 5): `PlansListView.duplicatePlan`'s
/// `dayCopy` must explicitly PRESERVE the source day's
/// `isAutoFilledPlaceholder` value, not default it to `false` (which would
/// make a freshly-duplicated plan's legitimately-eligible rest days
/// disappear) or force it to `true` (which would wrongly mark an already-
/// customized duplicated day as eligible). Source-introspection (kein
/// SwiftUI-Render-Harness in diesem Repo, `duplicatePlan` ist `private`),
/// gleiches Muster wie `PlansListCoachAdjustmentPriorityTests`.
final class PlansListViewDuplicatePlanTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func test_plansListView_duplicatePlan_preservesIsAutoFilledPlaceholder() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let dayCopyRange = source.range(of: "let dayCopy = TrainingDay(") else {
            XCTFail("dayCopy construction not found in duplicatePlan"); return
        }
        guard let closingParen = source.range(of: "\n            )", range: dayCopyRange.upperBound..<source.endIndex) else {
            XCTFail("end of dayCopy initializer call not found"); return
        }
        let initializerArguments = source[dayCopyRange.upperBound..<closingParen.lowerBound]
        XCTAssertTrue(
            initializerArguments.contains("isAutoFilledPlaceholder: day.isAutoFilledPlaceholder"),
            "dayCopy must explicitly pass through day.isAutoFilledPlaceholder, not default it to false or force it to true"
        )
    }
}
#endif
