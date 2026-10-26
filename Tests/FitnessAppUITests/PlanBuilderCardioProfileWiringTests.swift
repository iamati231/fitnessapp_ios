#if canImport(SwiftUI)
import XCTest
#if canImport(SwiftData)
@testable import FitnessAppUI
import FitnessAppCore
#endif

/// Task 6 (Laufcoaching-Plan-Integration, Requirement A): `currentInput`s
/// `GoalDrivenPlanSelectionBuilder.makeSelections`-Aufruf (goal-driven Branch)
/// ist die EINZIGE Produktionsstelle, die `cardioRunProfile` befuellt - ohne
/// diese Verdrahtung hat der in frueheren Tasks gebaute Lauf-Coach keine
/// Wirkung. Source-introspection (kein SwiftUI-Render-Harness in diesem
/// Repo), gleiches Muster wie `MehrInformationArchitectureTests`.
final class PlanBuilderCardioProfileWiringTests: XCTestCase {

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

    /// Finding 1 (Laufcoaching-Audit-Fixes): `currentInput` muss die Lauf-Coach-Eingabe aus der
    /// AKTUELLEN Builder-Auswahl (`runCoachWanted`) herleiten, NICHT mehr aus dem bereits
    /// gespeicherten Profil (`cardioCoachingEnabled`) - sonst weicht ein frisch im Builder
    /// aktivierter/deaktivierter Coach vom generierten Ergebnis ab. Reine Wiring-Pruefung, dass
    /// `currentInput` tatsaechlich `effectiveCardioRunProfile(runCoachWanted:...)` aufruft -
    /// die eigentliche Logik pruefen die Tests unten direkt an der Funktion.
    func testCurrentInputPassesCardioRunProfileWhenCoachIsEnabled() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "private var currentInput: PlanGeneratorInput {") else {
            XCTFail("currentInput not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("cardioRunProfile"), "GoalDrivenPlanSelectionBuilder.makeSelections must receive a cardio profile")
        XCTAssertTrue(
            block.contains("effectiveCardioRunProfile(") && block.contains("runCoachWanted: runCoachWanted"),
            "the profile must be derived from the CURRENT in-builder toggle (runCoachWanted), not the saved profile's cardioCoachingEnabled"
        )
        XCTAssertFalse(
            block.contains("cardioCoachingEnabled"),
            "Finding 1: currentInput must no longer gate on the saved profile's cardioCoachingEnabled"
        )
    }

    #if canImport(SwiftData)

    // MARK: - Finding 1 (Laufcoaching-Audit-Fixes): effectiveCardioRunProfile, real behavior tests

    /// Requirement 1: Onboarding, Coach aktiv, Laufziel ausgewaehlt (noch kein Profil) -> der
    /// erzeugte Input enthaelt das passende Laufprofil mit genau diesem Ziel.
    func testEffectiveCardioRunProfile_onboardingCoachActiveWithGoal_returnsMatchingProfile() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true,
            savedCardioGoal: nil,
            savedCurrent5kReferenceSeconds: nil,
            savedWeeklyBaseVolumeKm: nil,
            preseededCardioGoal: .tenK
        )
        XCTAssertEqual(result, CardioRunProfile(goal: .tenK, current5kReferenceSeconds: nil, weeklyBaseVolumeKm: nil))
    }

    /// Requirement 2: Onboarding, Coach NICHT aktiv -> kein coach-spezifisches Profil, obwohl ein
    /// Laufziel vorbefuellt waere.
    func testEffectiveCardioRunProfile_onboardingCoachInactive_returnsNil() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: false,
            savedCardioGoal: nil,
            savedCurrent5kReferenceSeconds: nil,
            savedWeeklyBaseVolumeKm: nil,
            preseededCardioGoal: .tenK
        )
        XCTAssertNil(result)
    }

    /// Requirement 3: spaeterer Builder, Coach im gespeicherten Profil AUS, aber im Builder
    /// eingeschaltet -> die Generierung verwendet den AKTUELLEN (eingeschalteten) Coach-Status,
    /// nicht das gespeicherte "aus". Das gespeicherte `cardioGoal` wird trotzdem verwendet (der
    /// Nutzer hat bereits eines gepflegt, auch wenn der Coach bisher aus war).
    func testEffectiveCardioRunProfile_coachOffInProfileButOnInBuilder_usesCurrentBuilderState() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true, // im Builder eingeschaltet - das gespeicherte Profil hatte es aus
            savedCardioGoal: .marathon,
            savedCurrent5kReferenceSeconds: 1500,
            savedWeeklyBaseVolumeKm: 20,
            preseededCardioGoal: .generalFitness
        )
        XCTAssertEqual(
            result,
            CardioRunProfile(goal: .marathon, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20),
            "ein im Builder eingeschalteter Coach muss wirksam werden, unabhaengig vom gespeicherten cardioCoachingEnabled"
        )
    }

    /// Requirement 4 (Teil 1): ein Wechsel von `runCoachWanted` aendert das Ergebnis - keine
    /// versteckte Staleness/Cache. (Der zweite Teil - gespeicherter Plan == bestaetigter Entwurf -
    /// folgt strukturell daraus, dass `currentInput` die einzige Aufrufstelle ist, siehe Wiring-Test
    /// oben, und `adoptPlan()` denselben `currentInput` fuer Vorschau UND Speichern verwendet.)
    func testEffectiveCardioRunProfile_togglingRunCoachWanted_changesResult() {
        let whenOn = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true, savedCardioGoal: .fiveK, savedCurrent5kReferenceSeconds: nil,
            savedWeeklyBaseVolumeKm: nil, preseededCardioGoal: .generalFitness
        )
        let whenOff = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: false, savedCardioGoal: .fiveK, savedCurrent5kReferenceSeconds: nil,
            savedWeeklyBaseVolumeKm: nil, preseededCardioGoal: .generalFitness
        )
        XCTAssertNotEqual(whenOn, whenOff)
        XCTAssertNotNil(whenOn)
        XCTAssertNil(whenOff)
    }

    /// Requirement 5: ein bereits aktivierter Coach mit vorhandener Referenzzeit/Wochenvolumen
    /// behaelt diese Daten unveraendert - die Funktion nimmt `totalDaysPerWeek`/
    /// `sessionDurationMinutes`/`experience`/Zeitformat gar nicht erst als Parameter entgegen, kann
    /// sie also strukturell nicht versehentlich mit-veraendern; dieser Test beweist das am
    /// Ergebnis, nicht nur an der Signatur.
    func testEffectiveCardioRunProfile_existingReferenceData_isPreservedRegardlessOfOtherFields() {
        let referenceSeconds = 1234
        let weeklyVolume = 42.5
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true, savedCardioGoal: .halfMarathon,
            savedCurrent5kReferenceSeconds: referenceSeconds, savedWeeklyBaseVolumeKm: weeklyVolume,
            preseededCardioGoal: .generalFitness
        )
        XCTAssertEqual(result?.current5kReferenceSeconds, referenceSeconds)
        XCTAssertEqual(result?.weeklyBaseVolumeKm, weeklyVolume)
    }

    /// Referenzzeit/Wochenvolumen duerfen NIE erfunden werden (Auftrag, Fix 1, Anforderungen):
    /// ohne gespeichertes Profil (Onboarding) bleiben sie `nil`, auch wenn der Coach aktiv ist.
    func testEffectiveCardioRunProfile_noSavedProfile_neverInventsReferenceData() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true, savedCardioGoal: nil, savedCurrent5kReferenceSeconds: nil,
            savedWeeklyBaseVolumeKm: nil, preseededCardioGoal: .tenK
        )
        XCTAssertNil(result?.current5kReferenceSeconds)
        XCTAssertNil(result?.weeklyBaseVolumeKm)
    }

    // MARK: - Gemeinsamer Laufcoaching-Setup-Schritt (Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt)

    /// Scenario 7 (Auftrag, Abschnitt 8): `effectiveCardioRunProfile`s erweiterte Fallback-Logik -
    /// fehlt ein gespeichertes Profil (Onboarding), liefern jetzt auch Referenzzeit/Wochenvolumen
    /// den `preseeded*`-Wert aus dem Setup-Entwurf, statt wie vorher (Fix 1) immer `nil` zu bleiben.
    func testEffectiveCardioRunProfile_noSavedProfile_fallsBackToPreseededReferenceDataFromDraft() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true,
            savedCardioGoal: nil, savedCurrent5kReferenceSeconds: nil, savedWeeklyBaseVolumeKm: nil,
            preseededCardioGoal: .tenK,
            preseededCurrent5kReferenceSeconds: 1500,
            preseededWeeklyBaseVolumeKm: 25
        )
        XCTAssertEqual(result, CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 25))
    }

    /// Ein vorhandenes gespeichertes Profil gewinnt weiterhin gegen den vorbefuellten Entwurf, auch
    /// fuer die neuen Referenzzeit-/Wochenvolumen-Parameter (identisches Prinzip wie das bereits
    /// bestehende Ziel-Fallback oben).
    func testEffectiveCardioRunProfile_savedProfileWinsOverPreseededReferenceData() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true,
            savedCardioGoal: .marathon, savedCurrent5kReferenceSeconds: 999, savedWeeklyBaseVolumeKm: 50,
            preseededCardioGoal: .tenK,
            preseededCurrent5kReferenceSeconds: 1500,
            preseededWeeklyBaseVolumeKm: 25
        )
        XCTAssertEqual(result, CardioRunProfile(goal: .marathon, current5kReferenceSeconds: 999, weeklyBaseVolumeKm: 50))
    }

    /// Ohne Setup-Entwurf (Default-Parameter nicht angegeben) bleibt das bisherige Verhalten
    /// unveraendert - keine Regression fuer bereits bestehende Aufrufstellen.
    func testEffectiveCardioRunProfile_omittingPreseededReferenceData_staysNilLikeBefore() {
        let result = PlanBuilderView.effectiveCardioRunProfile(
            runCoachWanted: true, savedCardioGoal: nil, savedCurrent5kReferenceSeconds: nil,
            savedWeeklyBaseVolumeKm: nil, preseededCardioGoal: .fiveK
        )
        XCTAssertNil(result?.current5kReferenceSeconds)
        XCTAssertNil(result?.weeklyBaseVolumeKm)
    }

    /// Scenario 4/5 (Auftrag, Abschnitt 8): die testbare Bedingung fuer das neue Setup-Sheet im
    /// eigenstaendigen Modus - noch nicht eingerichtet + Coach gewuenscht -> Sheet noetig; bereits
    /// eingerichtet -> nicht noetig (bestehende Daten werden wiederverwendet, kein erneutes
    /// Abfragen).
    func testNeedsCardioCoachSetup_notYetSetUpAndWanted_returnsTrue() {
        XCTAssertTrue(PlanBuilderView.needsCardioCoachSetup(runCoachWanted: true, hasExistingCoachSetup: false))
    }

    func testNeedsCardioCoachSetup_alreadySetUp_returnsFalseEvenWhenWanted() {
        XCTAssertFalse(PlanBuilderView.needsCardioCoachSetup(runCoachWanted: true, hasExistingCoachSetup: true))
    }

    func testNeedsCardioCoachSetup_coachNotWanted_returnsFalseRegardlessOfSetupState() {
        XCTAssertFalse(PlanBuilderView.needsCardioCoachSetup(runCoachWanted: false, hasExistingCoachSetup: false))
        XCTAssertFalse(PlanBuilderView.needsCardioCoachSetup(runCoachWanted: false, hasExistingCoachSetup: true))
    }

    #endif

    /// `currentInput` muss die erweiterten `preseeded*`-Parameter (Referenzzeit/Wochenvolumen aus
    /// dem Setup-Entwurf) tatsaechlich an `effectiveCardioRunProfile` durchreichen - sonst bliebe
    /// Scenario 7 oben nur an der isolierten Funktion bewiesen, nicht an ihrer echten Aufrufstelle.
    func testCurrentInputPassesPreseededReferenceDataFromCardioCoachSetupDraft() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "private var currentInput: PlanGeneratorInput {") else {
            XCTFail("currentInput not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("preseededCardioGoal: cardioCoachSetupDraft.goal"))
        XCTAssertTrue(block.contains("preseededCurrent5kReferenceSeconds: cardioCoachSetupDraft.current5kReferenceSeconds"))
        XCTAssertTrue(block.contains("preseededWeeklyBaseVolumeKm: cardioCoachSetupDraft.weeklyBaseVolumeKm"))
    }

    /// Scenario 10 (Auftrag, Abschnitt 8: "gespeicherter Plan entspricht exakt der Vorschau") im
    /// eigenstaendigen Modus: `applyEnduranceModalityChoiceIfNeeded` muss denselben
    /// `cardioCoachSetupDraft` persistieren, den `currentInput`/die Vorschau bereits verwendet
    /// haben - UND nur, wenn der Coach tatsaechlich eingeschaltet wurde (kein Ueberschreiben mit
    /// leeren Werten, wenn `setEnduranceModality` den Coach z.B. per Modalitaets-Veto aus laesst).
    func testApplyEnduranceModalityChoiceIfNeededPersistsTheSameDraftGuardedByCardioCoachingEnabled() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "private func applyEnduranceModalityChoiceIfNeeded(to profile: UserBodyProfile) {") else {
            XCTFail("applyEnduranceModalityChoiceIfNeeded not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("if profile.cardioCoachingEnabled {"), "must guard the persistence on the ACTUAL resulting cardioCoachingEnabled, read AFTER setEnduranceModality")
        for property in ["cardioGoal", "cardioRaceDate", "weeklyBaseVolumeKm", "maxHeartRateBpm", "current5kReferenceSeconds"] {
            XCTAssertTrue(
                block.contains("profile.\(property) = cardioCoachSetupDraft.\(property == "cardioGoal" ? "goal" : property == "cardioRaceDate" ? "raceDate" : property)"),
                "must persist \(property) from the same draft the preview used"
            )
        }
    }

    /// Regression (selbst gefunden beim Implementieren, nicht im Auftrag explizit benannt, aber von
    /// Abschnitt 3/8 "bestehende Daten gehen nicht verloren" verlangt): wenn das Setup-Sheet NICHT
    /// gezeigt wird (bereits eingerichtetes Profil), darf `applyEnduranceModalityChoiceIfNeeded`
    /// trotzdem nicht blind den `.empty`-Init-Default persistieren - der "mit Coach"-Tap muss den
    /// Entwurf zuerst aus dem vorhandenen Profil seeden, bevor ueber das Sheet entschieden wird.
    func testWithCoachTapSeedsDraftFromExistingProfileBeforeDecidingOnTheSheet() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "isSelected: runCoachWanted") else {
            XCTFail("the withCoach runCoachOptionRow was not found"); return
        }
        guard let actionStart = source.range(of: "{", range: range.upperBound..<source.endIndex) else {
            XCTFail("the withCoach action closure was not found"); return
        }
        let actionBody = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: actionStart.upperBound))
        XCTAssertTrue(
            actionBody.contains("if let profile = profiles.first") && actionBody.contains("cardioCoachSetupDraft = CardioCoachSetupDraft("),
            "the withCoach action must re-seed cardioCoachSetupDraft from the existing profile before deciding whether to show the setup sheet"
        )
    }

    /// Scenario 4 (Auftrag, Abschnitt 8) im eigenstaendigen Modus: das neue Setup-Sheet darf NICHT
    /// im eingebetteten Onboarding-Modus erscheinen (dort wurde der Entwurf bereits inline erfasst,
    /// bevor dieser Builder ueberhaupt geoeffnet wird - ein zweites Sheet waere eine doppelte
    /// Abfrage).
    func testCardioCoachSetupSheetIsGatedToStandaloneModeOnly() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "showingCardioCoachSetup = true") else {
            XCTFail("the sheet-trigger assignment was not found"); return
        }
        let window = source[source.index(range.lowerBound, offsetBy: -400, limitedBy: source.startIndex) ?? source.startIndex..<range.upperBound]
        XCTAssertTrue(
            window.contains("onGenerated == nil"),
            "showing the new setup sheet must be gated to the standalone mode (onGenerated == nil)"
        )
    }

    /// Scenario 8 (Auftrag, Abschnitt 8): Abbruch des Setups darf die gerade getroffene
    /// "mit Coach"-Auswahl nicht als erfolgreich stehen lassen.
    func testCardioCoachSetupSheetCancelRevertsRunCoachWanted() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "private var cardioCoachSetupSheet: some View {") else {
            XCTFail("cardioCoachSetupSheet not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        guard let cancelRange = block.range(of: ".cancellationAction") else {
            XCTFail("the cancel toolbar item was not found"); return
        }
        let cancelWindow = block[cancelRange.upperBound...].prefix(300)
        XCTAssertTrue(cancelWindow.contains("runCoachWanted = false"), "cancelling the setup sheet must revert runCoachWanted")
    }

    /// Final-review Fix 4: `updateConfig`/`updateTimeFormat` rebuild a
    /// `PlanGeneratorTypeSelection` field-by-field from `current` and already
    /// preserve `current.timeFormat` explicitly (README 2.35) - they missed
    /// doing the same for `current.cardioRunProfile` (added later, Task
    /// 3/4), so editing days/duration/experience/time-format on an existing
    /// selection silently wiped the pace baseline back to "nach Gefuehl".
    func testUpdateHelpersPreserveCardioRunProfile() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")

        guard let updateConfigRange = source.range(of: "private func updateConfig(") else {
            XCTFail("updateConfig not found"); return
        }
        guard let updateConfigBraceRange = source.range(of: "{", range: updateConfigRange.upperBound..<source.endIndex) else {
            XCTFail("updateConfig body not found"); return
        }
        let updateConfigBody = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: updateConfigBraceRange.upperBound))
        XCTAssertTrue(updateConfigBody.contains("cardioRunProfile: current.cardioRunProfile"), "updateConfig must preserve the existing cardioRunProfile")

        guard let updateTimeFormatRange = source.range(of: "private func updateTimeFormat(") else {
            XCTFail("updateTimeFormat not found"); return
        }
        guard let updateTimeFormatBraceRange = source.range(of: "{", range: updateTimeFormatRange.upperBound..<source.endIndex) else {
            XCTFail("updateTimeFormat body not found"); return
        }
        let updateTimeFormatBody = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: updateTimeFormatBraceRange.upperBound))
        XCTAssertTrue(updateTimeFormatBody.contains("cardioRunProfile: current.cardioRunProfile"), "updateTimeFormat must preserve the existing cardioRunProfile")
    }
}
#endif
