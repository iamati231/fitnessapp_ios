#if canImport(SwiftUI) && canImport(UIKit)
import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor): `PlansListView.
/// duplicatePlan`'s `exCopy` construction copied every other `Exercise`
/// override field (muscle/equipment/fatigue factors, superset, role, ...)
/// but NOT `exerciseTemplateID` - the stable, rename-safe reference
/// `PRDetector`/`PlateauDetector` use for best-set/plateau grouping. A
/// duplicated exercise silently lost it and fell back to name-based
/// matching for future logs. Source-introspection (kein SwiftUI-Render-
/// Harness in diesem Repo, `duplicatePlan` ist `private`), gleiches Muster
/// wie `PlansListViewDuplicatePlanTests`.
final class PlansListViewDuplicateExerciseTemplateIDTests: XCTestCase {

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

    func test_plansListView_duplicatePlan_copiesExerciseTemplateID() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let exCopyRange = source.range(of: "let exCopy = Exercise(") else {
            XCTFail("exCopy construction not found in duplicatePlan"); return
        }
        guard let closingParen = source.range(of: "\n                )", range: exCopyRange.upperBound..<source.endIndex) else {
            XCTFail("end of exCopy initializer call not found"); return
        }
        let initializerArguments = source[exCopyRange.upperBound..<closingParen.lowerBound]
        XCTAssertTrue(
            initializerArguments.contains("exerciseTemplateID: ex.exerciseTemplateID"),
            "exCopy must pass through ex.exerciseTemplateID, not default it to nil - it is the stable reference PR/plateau detection groups by"
        )
    }
}
#endif
