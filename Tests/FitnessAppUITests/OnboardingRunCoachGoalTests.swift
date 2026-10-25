#if canImport(SwiftUI)
import XCTest

/// Task 5 (laufcoaching-plan-integration, 2026-10-25): das Onboarding fragt
/// die `CardioGoal`-Kategorie NUR, wenn der Laufcoach oben tatsaechlich
/// gewuenscht wird (`runCoachWanted == true`) - Renndatum/Wochenumfang/5k-
/// Referenzzeit bleiben dem spaeteren `CardioGoalEditorView` vorbehalten.
/// Source-introspection (kein SwiftUI-Render-Harness in diesem Repo),
/// gleiches Muster wie `MehrInformationArchitectureTests`.
final class OnboardingRunCoachGoalTests: XCTestCase {

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

    func testEnduranceModalityStepAsksForCardioGoalOnlyWhenCoachIsWanted() throws {
        let source = try contents(of: "OnboardingView.swift")
        guard let stepRange = source.range(of: "private var enduranceModalityStep: some View {") else {
            XCTFail("enduranceModalityStep not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: stepRange.upperBound))
        XCTAssertTrue(block.contains("runCoachCardioGoal"), "the goal question must live inside this step")

        // The goal question must be nested inside the existing
        // "if let enduranceModality, enduranceModality.supportsRunCoach"
        // guard, and specifically inside a further "if runCoachWanted" gate
        // - not always visible once the coach question itself is shown.
        guard let supportsRunCoachRange = block.range(of: "if let enduranceModality, enduranceModality.supportsRunCoach") else {
            XCTFail("supportsRunCoach guard not found inside enduranceModalityStep"); return
        }
        let afterSupportsRunCoach = block[supportsRunCoachRange.upperBound...]
        XCTAssertTrue(
            afterSupportsRunCoach.contains("if runCoachWanted"),
            "the goal question must be gated behind its own \"if runCoachWanted\" check, nested inside the supportsRunCoach guard"
        )
        guard let runCoachWantedGateRange = afterSupportsRunCoach.range(of: "if runCoachWanted") else {
            XCTFail("if runCoachWanted gate not found"); return
        }
        XCTAssertTrue(
            afterSupportsRunCoach[runCoachWantedGateRange.upperBound...].contains("runCoachCardioGoal"),
            "runCoachCardioGoal must appear textually after both gates, i.e. nested inside them"
        )

        // Reuses the existing CardioGoal.localizedName - no invented
        // per-goal localization keys.
        XCTAssertTrue(block.contains("CardioGoal.allCases"))
        XCTAssertTrue(block.contains("goal.localizedName"))
        XCTAssertTrue(block.contains("onboarding.runCoachGoal.title"))
        XCTAssertTrue(block.contains("onboarding.runCoachGoal.subtitle"))
    }

    func testFinishOnboardingPersistsCardioGoalOnlyWhenCoachEndsUpEnabled() throws {
        let source = try contents(of: "OnboardingView.swift")
        guard let range = source.range(of: "if needsEnduranceModalityStep {") else {
            XCTFail("finishOnboarding endurance block not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("profile.cardioGoal = runCoachCardioGoal"))
        XCTAssertTrue(
            block.contains("if profile.cardioCoachingEnabled"),
            "persistence must be gated on the resolved cardioCoachingEnabled, not the raw pre-modality runCoachWanted flag"
        )
    }

    /// `onboarding.runCoachGoal.title`/`.subtitle` sind die einzigen neuen
    /// Resources fuer diese Frage - DE/EN/TR muessen vollstaendig sein.
    func testRunCoachGoalQuestionLabelsAreFullyLocalized() throws {
        let strings = try contents(of: "Resources/Localizable.xcstrings")
        for key in ["onboarding.runCoachGoal.title", "onboarding.runCoachGoal.subtitle"] {
            guard let keyRange = strings.range(of: "\"\(key)\": {") else {
                XCTFail("\(key) nicht gefunden"); continue
            }
            // Brace-counting statt eines auf ein nachfolgendes Komma
            // angewiesenen Textmusters - dieser Key kann der letzte Eintrag
            // der Datei sein, dessen schliessende Klammer KEIN Komma traegt.
            guard let block = Self.matchingBraceBlock(in: strings, afterOpenBrace: keyRange.upperBound) else {
                XCTFail("kein passender Block fuer \(key)"); continue
            }
            for language in ["\"de\": {", "\"en\": {", "\"tr\": {"] {
                XCTAssertTrue(block.contains(language), "fehlende Lokalisierung fuer \(key): \(language)")
            }
        }
    }
}
#endif
