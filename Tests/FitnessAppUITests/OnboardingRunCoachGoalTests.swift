#if canImport(SwiftUI)
import XCTest

/// Task 5 (laufcoaching-plan-integration, 2026-10-25), erweitert um den gemeinsamen
/// Laufcoaching-Setup-Schritt (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt): das Onboarding
/// zeigt den VOLLEN Setup-Entwurf (Ziel + optional Renndatum/Wochenumfang/5k-Referenzzeit/max.
/// Herzfrequenz) NUR, wenn der Laufcoach oben tatsaechlich gewuenscht wird
/// (`runCoachWanted == true`) - vorher (Task 5) seedete dieser Schritt absichtlich nur die
/// Ziel-KATEGORIE und verschob den Rest auf `CardioGoalEditorView`; diese Entscheidung ist mit
/// dem neuen Auftrag aufgehoben. Source-introspection (kein SwiftUI-Render-Harness in diesem
/// Repo), gleiches Muster wie `MehrInformationArchitectureTests`.
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

    func testEnduranceModalityStepShowsTheSharedSetupFieldsOnlyWhenCoachIsWanted() throws {
        let source = try contents(of: "OnboardingView.swift")
        guard let stepRange = source.range(of: "private var enduranceModalityStep: some View {") else {
            XCTFail("enduranceModalityStep not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: stepRange.upperBound))
        XCTAssertTrue(
            block.contains("CardioCoachSetupFields(draft: $cardioCoachSetupDraft)"),
            "the shared setup fields (goal, race date, weekly volume, max HR, 5K reference) must live inside this step"
        )

        // The setup fields must be nested inside the existing
        // "if let enduranceModality, enduranceModality.supportsRunCoach"
        // guard, and specifically inside a further "if runCoachWanted" gate
        // - not always visible once the coach question itself is shown.
        guard let supportsRunCoachRange = block.range(of: "if let enduranceModality, enduranceModality.supportsRunCoach") else {
            XCTFail("supportsRunCoach guard not found inside enduranceModalityStep"); return
        }
        let afterSupportsRunCoach = block[supportsRunCoachRange.upperBound...]
        XCTAssertTrue(
            afterSupportsRunCoach.contains("if runCoachWanted"),
            "the setup fields must be gated behind their own \"if runCoachWanted\" check, nested inside the supportsRunCoach guard"
        )
        guard let runCoachWantedGateRange = afterSupportsRunCoach.range(of: "if runCoachWanted") else {
            XCTFail("if runCoachWanted gate not found"); return
        }
        XCTAssertTrue(
            afterSupportsRunCoach[runCoachWantedGateRange.upperBound...].contains("CardioCoachSetupFields(draft: $cardioCoachSetupDraft)"),
            "the shared setup fields must appear textually after both gates, i.e. nested inside them"
        )
        XCTAssertTrue(block.contains("onboarding.runCoachGoal.title"))
        XCTAssertTrue(block.contains("onboarding.runCoachGoal.subtitle"))
    }

    func testFinishOnboardingPersistsTheFullCardioSetupDraftOnlyWhenCoachEndsUpEnabled() throws {
        let source = try contents(of: "OnboardingView.swift")
        guard let range = source.range(of: "if needsEnduranceModalityStep {") else {
            XCTFail("finishOnboarding endurance block not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(
            block.contains("if profile.cardioCoachingEnabled {"),
            "persistence must be gated on the resolved cardioCoachingEnabled, not the raw pre-modality runCoachWanted flag"
        )
        for assignment in [
            "profile.cardioGoal = cardioCoachSetupDraft.goal",
            "profile.cardioRaceDate = cardioCoachSetupDraft.raceDate",
            "profile.weeklyBaseVolumeKm = cardioCoachSetupDraft.weeklyBaseVolumeKm",
            "profile.maxHeartRateBpm = cardioCoachSetupDraft.maxHeartRateBpm",
            "profile.current5kReferenceSeconds = cardioCoachSetupDraft.current5kReferenceSeconds",
        ] {
            XCTAssertTrue(block.contains(assignment), "missing: \(assignment)")
        }
    }

    /// Gemeinsamer Setup-Schritt (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt), ersetzt Finding
    /// 1s `runCoachCardioGoal`-Weitergabe: `cardioCoachSetupDraft` existiert im Onboarding als
    /// reiner `@State`, BEVOR ein `UserBodyProfile` angelegt wird - ohne diese Weitergabe an den
    /// eingebetteten Builder haette dessen `currentInput` fuer die Laufcoach-Komponente keine
    /// Quelle (siehe `PlanBuilderCardioProfileWiringTests.effectiveCardioRunProfile`-Tests fuer
    /// die eigentliche Herleitungslogik - dieser Test prueft nur die Weitergabe selbst).
    func testEmbeddedPlanBuilderReceivesTheOnboardingCardioSetupDraft() throws {
        let source = try contents(of: "OnboardingView.swift")
        guard let callRange = source.range(of: "PlanBuilderView(initialInput: PlanGeneratorInput(") else {
            XCTFail("embedded PlanBuilderView call not found"); return
        }
        // Bounded window after the call's start (the named-argument list fits well within this
        // many characters, see lines ~413-421) - avoids depending on full call-boundary parsing.
        let windowEnd = source.index(callRange.lowerBound, offsetBy: 600, limitedBy: source.endIndex) ?? source.endIndex
        let window = source[callRange.lowerBound..<windowEnd]
        XCTAssertTrue(
            window.contains("preseededCardioCoachSetupDraft: cardioCoachSetupDraft"),
            "the embedded builder must receive the onboarding's current cardio coach setup draft"
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
