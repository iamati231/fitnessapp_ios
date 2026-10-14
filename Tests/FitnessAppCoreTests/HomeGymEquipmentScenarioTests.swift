import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
/// Pflicht-Tests 3/4/5): End-to-End-Szenarien fuer den restrukturierten
/// Home-Gym-Editor — simuliert exakt das `UserEquipmentProfile`, das
/// `EquipmentProfileEditor`s Bank-/Klimmzugstangen-Einzelauswahl fuer die
/// jeweilige Wahl erzeugen wuerde (die View selbst ist UI-privat und nicht
/// direkt testbar, siehe Abschlussbericht), und prueft die tatsaechliche
/// Equipment-Pruefung dagegen — die bereits bestehende, in Phase 4
/// umfassend getestete `PlanEquipmentChecker`-Logik.
final class HomeGymEquipmentScenarioTests: XCTestCase {

    private func day(_ exerciseNames: [String]) -> DaySpec {
        DaySpec(
            name: "Tag", type: .fullBody, sequenceIndex: 1,
            exercises: exerciseNames.map { ExerciseSpec(name: $0, sets: 3, repsMin: 8, repsMax: 12) }
        )
    }

    /// Pflicht-Test 3: Home-Gym, nur Kettlebell bestaetigt, keine Bank, keine
    /// Klimmzugstange. Kettlebell-Uebungen bleiben passend; Kurzhantel-,
    /// Bank- und Klimmzug-Uebungen duerfen NICHT unveraendert als passend
    /// gelten.
    func testKettlebellOnlyHomeGymNeverShowsDumbbellBenchOrPullUpExercisesAsAvailable() {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()

        let days = [day([
            "Kettlebell Goblet Squat",  // .any([kettlebell, dumbbell]) -> erfuellt ueber Kettlebell
            "Rumänisches Kreuzheben (KH)", // .item(dumbbell, count 2) -> fehlt
            "Bankdrücken (KH)",          // dumbbell + (flat ODER adjustable bench) -> fehlt (beides)
            "Klimmzüge"                  // pullUpBar -> fehlt
        ])]

        let report = PlanEquipmentChecker.fullReport(days: days, against: profile)
        let missingNames = Set(report.missing.map(\.exerciseName))
        XCTAssertEqual(missingNames, ["Rumänisches Kreuzheben (KH)", "Bankdrücken (KH)", "Klimmzüge"],
                       "Nur die drei tatsaechlich nicht erfuellbaren Uebungen duerfen als fehlend gelten")
        XCTAssertFalse(missingNames.contains("Kettlebell Goblet Squat"),
                       "Die Kettlebell-Uebung bleibt korrekt passend")
        XCTAssertTrue(PlanEquipmentChecker.check(days: days, against: profile).isUnavailable)
    }

    /// Pflicht-Test 4: Home-Gym mit KH+KB+verstellbarer Bank+Klimmzugstange
    /// VOLLSTAENDIG bestaetigt — die Kombination bleibt in ihrer Gesamtheit
    /// als passend erhalten (kein einzelnes Teil "verschluckt" ein anderes).
    func testFullHomeGymCombinationStaysFullyAvailableTogether() {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.availability[.kettlebell] = .available
        profile.availability[.adjustableBench] = .available
        profile.availability[.pullUpBar] = .available
        profile.confirmRemainingAsUnavailable()

        let days = [day([
            "Kettlebell Goblet Squat",
            "Rumänisches Kreuzheben (KH)",
            "Bankdrücken (KH)",
            "Schrägbankdrücken aufwärts (KH)",
            "Klimmzüge"
        ])]

        let status = PlanEquipmentChecker.check(days: days, against: profile)
        XCTAssertTrue(status.isAvailable, "Die volle Kombination muss ALLE fuenf Uebungen gemeinsam abdecken, Status: \(status)")
    }

    /// Pflicht-Test 5: eine bestaetigte FLACHBANK darf keine automatische
    /// Freigabe fuer eine Schraegbank-Uebung geben — die bestehende
    /// `.item(.adjustableBench)`-Anforderung (ohne `.any` mit `.flatBench`)
    /// fuer "Schrägbankdrücken aufwärts (KH)" muss das verhindern.
    func testFlatBenchOnlyDoesNotUnlockInclineExercise() {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.availability[.flatBench] = .available
        profile.availability[.adjustableBench] = .unavailable
        profile.confirmRemainingAsUnavailable()

        let flatPressDay = day(["Bankdrücken (KH)"])
        XCTAssertTrue(PlanEquipmentChecker.check(days: [flatPressDay], against: profile).isAvailable,
                      "Flache Bankdrueck-Uebung bleibt mit einer reinen Flachbank passend")

        let inclineDay = day(["Schrägbankdrücken aufwärts (KH)"])
        let inclineStatus = PlanEquipmentChecker.check(days: [inclineDay], against: profile)
        XCTAssertTrue(inclineStatus.isUnavailable,
                      "Eine reine Flachbank darf die Schraegbank-Anforderung NICHT erfuellen, Status: \(inclineStatus)")
    }
}
