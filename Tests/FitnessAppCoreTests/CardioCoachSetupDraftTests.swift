import XCTest
@testable import FitnessAppCore

/// Deltiq_Laufcoaching_Gemeinsamer_Setup-Schritt: `CardioCoachSetupDraft` ist der gemeinsame
/// Entwurf, den Onboarding, PlanBuilder und `CardioGoalEditorView` ueber `CardioCoachSetupFields`
/// teilen (FitnessAppUI). Diese Tests decken nur die Core-Logik ab (Default, Referenzzeit-Parsing,
/// Wertgleichheit) - die UI-Verdrahtung pruefen `PlanBuilderCardioProfileWiringTests`/
/// `OnboardingRunCoachGoalTests`/`CardioGoalEditorPersistenceTests`.
final class CardioCoachSetupDraftTests: XCTestCase {

    /// Scenario 6 (Auftrag, Abschnitt 8): `.empty` ist der einzige echte "Pflichtfeld"-Zustand -
    /// nur `goal` hat ueberhaupt einen Wert, alles andere bleibt `nil`/leer. Kein erfundener
    /// Default fuer Renndatum/Wochenumfang/Referenzzeit/max. Herzfrequenz.
    func testEmptyDraftHasOnlyAGoalNoInventedOptionalData() {
        let draft = CardioCoachSetupDraft.empty
        XCTAssertEqual(draft.goal, .generalFitness, "matches UserBodyProfile.cardioGoal's own default for a fresh profile")
        XCTAssertNil(draft.raceDate)
        XCTAssertNil(draft.weeklyBaseVolumeKm)
        XCTAssertNil(draft.maxHeartRateBpm)
        XCTAssertEqual(draft.fiveKReferenceText, "")
        XCTAssertNil(draft.current5kReferenceSeconds)
    }

    func testCurrent5kReferenceSecondsParsesValidMMSSText() {
        let draft = CardioCoachSetupDraft(
            goal: .tenK, raceDate: nil, weeklyBaseVolumeKm: nil, maxHeartRateBpm: nil, fiveKReferenceText: "25:00"
        )
        XCTAssertEqual(draft.current5kReferenceSeconds, 1500)
    }

    /// Dieselbe Validierungsregel wie `CardioGoalEditorView.canSave` vorher direkt implementierte:
    /// ungueltiger Text (kein MM:SS) parst zu `nil`, genau wie leerer Text - der Unterschied
    /// zwischen beiden zeigt `CardioCoachSetupFields.fiveKReferenceErrorMessage` separat an.
    func testCurrent5kReferenceSecondsIsNilForInvalidOrEmptyText() {
        XCTAssertNil(CardioCoachSetupDraft(
            goal: .tenK, raceDate: nil, weeklyBaseVolumeKm: nil, maxHeartRateBpm: nil, fiveKReferenceText: "not a time"
        ).current5kReferenceSeconds)
        XCTAssertNil(CardioCoachSetupDraft(
            goal: .tenK, raceDate: nil, weeklyBaseVolumeKm: nil, maxHeartRateBpm: nil, fiveKReferenceText: ""
        ).current5kReferenceSeconds)
    }

    /// Scenario 11 (Auftrag, Abschnitt 8): ein bereits vollstaendig eingerichtetes Profil muss
    /// verlustfrei in einen Entwurf uebernommen werden koennen - jede Aufrufstelle baut den
    /// Entwurf aus den eigenen, bereits vorhandenen Werten (Core kennt `UserBodyProfile` nicht),
    /// dieser Test beweist nur, dass die Struct selbst jede Kombination verlustfrei haelt.
    func testPreservesAllFieldsOfAnAlreadyCompleteProfile() {
        let raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let draft = CardioCoachSetupDraft(
            goal: .marathon, raceDate: raceDate, weeklyBaseVolumeKm: 42.5, maxHeartRateBpm: 180,
            fiveKReferenceText: "22:30"
        )
        XCTAssertEqual(draft.goal, .marathon)
        XCTAssertEqual(draft.raceDate, raceDate)
        XCTAssertEqual(draft.weeklyBaseVolumeKm, 42.5)
        XCTAssertEqual(draft.maxHeartRateBpm, 180)
        XCTAssertEqual(draft.current5kReferenceSeconds, 1350)
    }

    func testEqualityIsFieldWise() {
        let a = CardioCoachSetupDraft(goal: .fiveK, raceDate: nil, weeklyBaseVolumeKm: 10, maxHeartRateBpm: nil, fiveKReferenceText: "")
        let b = CardioCoachSetupDraft(goal: .fiveK, raceDate: nil, weeklyBaseVolumeKm: 10, maxHeartRateBpm: nil, fiveKReferenceText: "")
        let c = CardioCoachSetupDraft(goal: .tenK, raceDate: nil, weeklyBaseVolumeKm: 10, maxHeartRateBpm: nil, fiveKReferenceText: "")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCardioCoachSetupDraftRoundTripsThroughJSON() throws {
        let draft = CardioCoachSetupDraft(
            goal: .halfMarathon, raceDate: Date(timeIntervalSince1970: 1_700_000_000),
            weeklyBaseVolumeKm: 35, maxHeartRateBpm: 175, fiveKReferenceText: "24:10"
        )
        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(CardioCoachSetupDraft.self, from: data)
        XCTAssertEqual(decoded, draft)
    }
}
