#if canImport(SwiftUI)
import XCTest

/// Task 9 (laufcoaching-plan-integration, 2026-10-25): `ExerciseSpec.
/// targetPaceMinutesPerKm` (Task 3) wird gesetzt, aber bisher nirgends
/// angezeigt - diese Tests sichern, dass `CardioFeasibilityDayRow.subtitle`
/// (geteilt von Profil/Dashboard/Plan-Tab) und `PlanBuilderView.scopeLine`
/// (die "fuellere" Geschwister-Darstellung, siehe deren Datei-Kommentar) die
/// Pace fuer den Easy/Tempo-Dauer-Zweig anzeigen, OHNE den Intervall-/
/// Distanz-Zweig anzutasten (Task 3 setzt dort nie eine Pace).
/// Source-introspection (kein SwiftUI-Render-Harness in diesem Repo),
/// gleiches Muster wie `OnboardingRunCoachGoalTests`.
final class CardioFeasibilityDayRowPaceTests: XCTestCase {

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

    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    func testCardioFeasibilityDayRowShowsPaceOnlyInDurationBranch() throws {
        let source = try contents(of: "Cardio/CardioFeasibilityDayRow.swift")
        guard let subtitleRange = source.range(of: "private var subtitle: String {") else {
            XCTFail("subtitle not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: subtitleRange.upperBound))

        guard let durationGateRange = block.range(of: "if let minutes = exercise.targetDurationMinutes {") else {
            XCTFail("duration branch not found"); return
        }
        let durationBranch = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: durationGateRange.upperBound))
        XCTAssertTrue(durationBranch.contains("exercise.targetPaceMinutesPerKm"), "duration branch must read the pace")
        XCTAssertTrue(durationBranch.contains("PaceCalculator.formatPace(pace)"), "known pace must use PaceCalculator.formatPace, not a hand-rolled format")
        XCTAssertTrue(durationBranch.contains("cardioFeasibility.day.paceUnknown"), "unknown pace must fall back to a qualitative label, not formatPace(nil)")
        XCTAssertFalse(durationBranch.contains("formatPace(nil)"), "must never render the raw empty-field placeholder")

        // The interval/distance branch (Task 3: never carries a pace) must
        // stay untouched - no pace reference anywhere after it starts.
        guard let distanceGateRange = block.range(of: "if let distanceKm = exercise.targetDistanceKm {") else {
            XCTFail("distance branch not found"); return
        }
        let distanceBranch = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: distanceGateRange.upperBound))
        XCTAssertFalse(distanceBranch.contains("targetPaceMinutesPerKm"), "the distance/interval branch must stay pace-free per Task 3's constraint")
        XCTAssertFalse(distanceBranch.contains("PaceCalculator"), "the distance/interval branch must stay pace-free per Task 3's constraint")
    }

    func testPlanBuilderScopeLineShowsPaceOnlyInDurationBranch() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let scopeLineRange = source.range(of: "private func scopeLine(for spec: DaySpec) -> String {") else {
            XCTFail("scopeLine not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: scopeLineRange.upperBound))

        guard let durationGateRange = block.range(of: "if let duration = exercise.targetDurationMinutes {") else {
            XCTFail("duration branch not found"); return
        }
        let durationBranch = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: durationGateRange.upperBound))
        XCTAssertTrue(durationBranch.contains("exercise.targetPaceMinutesPerKm"), "duration branch must read the pace")
        XCTAssertTrue(durationBranch.contains("PaceCalculator.formatPace(pace)"))
        XCTAssertTrue(durationBranch.contains("cardioFeasibility.day.paceUnknown"))
        XCTAssertFalse(durationBranch.contains("formatPace(nil)"))

        guard let distanceGateRange = block.range(of: "if let distance = exercise.targetDistanceKm {") else {
            XCTFail("distance branch not found"); return
        }
        let distanceBranch = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: distanceGateRange.upperBound))
        XCTAssertFalse(distanceBranch.contains("targetPaceMinutesPerKm"), "the distance/interval branch must stay pace-free per Task 3's constraint")
        XCTAssertFalse(distanceBranch.contains("PaceCalculator"), "the distance/interval branch must stay pace-free per Task 3's constraint")
    }

    /// `cardioFeasibility.day.paceUnknown` ist der einzige neue Key fuer
    /// diese Aufgabe - DE/EN/TR muessen vollstaendig sein.
    func testPaceUnknownKeyIsFullyLocalized() throws {
        let strings = try contents(of: "Resources/Localizable.xcstrings")
        let key = "cardioFeasibility.day.paceUnknown"
        guard let keyRange = strings.range(of: "\"\(key)\": {") else {
            XCTFail("\(key) nicht gefunden"); return
        }
        // Brace-counting statt eines auf ein nachfolgendes Komma
        // angewiesenen Textmusters - dieser Key kann der letzte Eintrag der
        // Datei sein, dessen schliessende Klammer KEIN Komma traegt.
        guard let block = Self.matchingBraceBlock(in: strings, afterOpenBrace: keyRange.upperBound) else {
            XCTFail("kein passender Block fuer \(key)"); return
        }
        for language in ["\"de\": {", "\"en\": {", "\"tr\": {"] {
            XCTAssertTrue(block.contains(language), "fehlende Lokalisierung fuer \(key): \(language)")
        }
    }
}
#endif
