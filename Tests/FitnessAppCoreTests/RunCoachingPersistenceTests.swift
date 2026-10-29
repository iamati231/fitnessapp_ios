import XCTest
@testable import FitnessAppCore

/// DEL-run-coaching: Lauf-Coaching dauerhaft in Trainingspläne integrieren.
/// Prüft, dass Pace und Coaching-Rationale vom Generator korrekt in
/// ExerciseSpec gesetzt werden — die Hälfte des Persistenz-Pfades (Core-Seite).
final class RunCoachingPersistenceTests: XCTestCase {

    // MARK: - Helpers

    private let ref5KSeconds = 1500 // 25 min → gemäßigte Freizeitläuferin

    private func runningResult(goal: CardioGoal = .fiveK, fiveKSeconds: Int?) -> PlanGenerator.Result {
        let profile = fiveKSeconds.map {
            CardioRunProfile(goal: goal, current5kReferenceSeconds: $0, weeklyBaseVolumeKm: nil)
        }
        let sel = PlanGeneratorTypeSelection(
            kind: .running, daysPerWeek: 3, sessionDurationMinutes: 45,
            experience: .intermediate, cardioRunProfile: profile
        )
        return PlanGenerator.generate(from: PlanGeneratorInput(
            selections: [sel], equipmentPreferences: [], usesFixedWeekdays: false
        ))
    }

    private func exercise(named name: String, in result: PlanGenerator.Result) -> ExerciseSpec? {
        result.days.flatMap(\.spec.exercises).first { $0.name == name }
    }

    // MARK: - 1. Pace wird gesetzt wenn 5K-Referenz bekannt ist (Easy Run)

    func test_easyRun_paceSet_when5KReferenceKnown() {
        let result = runningResult(fiveKSeconds: ref5KSeconds)
        let ex = exercise(named: "Easy Run", in: result)
        XCTAssertNotNil(ex?.targetPaceMinutesPerKm, "Easy Run muss Pace enthalten wenn 5K-Referenz bekannt")
    }

    // MARK: - 2. Pace ist nil ohne 5K-Referenz (Easy Run)

    func test_easyRun_paceNil_withoutReference() {
        let result = runningResult(fiveKSeconds: nil)
        let ex = exercise(named: "Easy Run", in: result)
        XCTAssertNil(ex?.targetPaceMinutesPerKm, "Easy Run darf keine Pace haben wenn keine Referenz bekannt")
    }

    // MARK: - 3. Pace wird gesetzt für Tempo-Lauf mit Referenz

    func test_tempoRun_paceSet_when5KReferenceKnown() {
        let result = runningResult(fiveKSeconds: ref5KSeconds)
        let ex = exercise(named: "Long Run", in: result)
        XCTAssertNotNil(ex?.targetPaceMinutesPerKm, "Tempo-Lauf muss Pace enthalten wenn 5K-Referenz bekannt")
    }

    // MARK: - 4. Intervall bleibt distanzbasiert, keine Pace

    func test_interval_noPace_distanceBased() {
        let result = runningResult(fiveKSeconds: ref5KSeconds)
        let ex = exercise(named: "Intervalle", in: result)
        XCTAssertNil(ex?.targetPaceMinutesPerKm, "Intervalle sind distanzbasiert — keine Pace")
        XCTAssertNotNil(ex?.targetDistanceKm, "Intervalle müssen Ziel-Distanz haben")
    }

    // MARK: - 5. Rationale gesetzt für Easy Run mit Ziel

    func test_easyRun_rationaleSet_withGoal() {
        let result = runningResult(goal: .marathon, fiveKSeconds: ref5KSeconds)
        let ex = exercise(named: "Easy Run", in: result)
        XCTAssertNotNil(ex?.coachingRationale, "Easy Run muss Rationale haben wenn Ziel bekannt")
        XCTAssertTrue(ex?.coachingRationale?.contains("Marathon") == true,
                      "Rationale soll das Ziel 'Marathon' erwähnen")
    }

    // MARK: - 6. Rationale gesetzt für Tempo-Lauf mit Ziel

    func test_tempoRun_rationaleSet_withGoal() {
        let result = runningResult(goal: .halfMarathon, fiveKSeconds: ref5KSeconds)
        let ex = exercise(named: "Long Run", in: result)
        XCTAssertNotNil(ex?.coachingRationale, "Tempo-Lauf muss Rationale haben wenn Ziel bekannt")
        XCTAssertTrue(ex?.coachingRationale?.contains("Halbmarathon") == true,
                      "Rationale soll 'Halbmarathon' erwähnen")
    }

    // MARK: - 7. Rationale gesetzt für Intervalle mit Ziel

    func test_interval_rationaleSet_withGoal() {
        let result = runningResult(goal: .tenK, fiveKSeconds: ref5KSeconds)
        let ex = exercise(named: "Intervalle", in: result)
        XCTAssertNotNil(ex?.coachingRationale, "Intervalle müssen Rationale haben wenn Ziel bekannt")
        XCTAssertTrue(ex?.coachingRationale?.contains("10 km") == true,
                      "Rationale soll '10 km' erwähnen")
    }

    // MARK: - 8. Rationale generisch ohne Ziel (Fallback)

    func test_easyRun_rationaleSet_withoutGoal() {
        let result = runningResult(fiveKSeconds: nil)
        let ex = exercise(named: "Easy Run", in: result)
        XCTAssertNotNil(ex?.coachingRationale, "Auch ohne Ziel muss eine generische Rationale gesetzt sein")
    }

    // MARK: - 9. withTargetRir überträgt coachingRationale

    func test_withTargetRir_preservesCoachingRationale() {
        let spec = ExerciseSpec(
            name: "Easy Run", sets: 1, repsMin: 0, repsMax: 0,
            isCardio: true, enduranceSportKind: .running,
            coachingRationale: "Testbegründung"
        )
        let copy = spec.withTargetRir(1.5)
        XCTAssertEqual(copy.coachingRationale, "Testbegründung")
    }

    // MARK: - 10. ExerciseSpec coachingRationale korrekt gesetzt via init

    func test_exerciseSpec_coachingRationale_roundtrip() {
        let rationale = "Grundlagentraining für 5 km"
        let spec = ExerciseSpec(
            name: "Easy Run", sets: 1, repsMin: 0, repsMax: 0,
            isCardio: true, coachingRationale: rationale
        )
        XCTAssertEqual(spec.coachingRationale, rationale)
    }
}
