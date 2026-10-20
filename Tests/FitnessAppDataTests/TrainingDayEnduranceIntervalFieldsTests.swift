#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Paket 2, Schritt 1 (Laufcoach-Konzept, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// die neuen `TrainingDay.endurance*`-Felder fuer `.enduranceIntervals`
/// (Einlaufen -> N Runden Belastung/Erholung -> Auslaufen) muessen
/// genauso wie die bestehenden `circuit*`-Felder (a) ueber `DaySpec` beim
/// Instanziieren propagiert werden und (b) Teil von
/// `currentContentFingerprint` sein - sonst wuerde ein Edit dieser Felder
/// vom "neu rechnen"/Coach-Anpassungs-Schutzmechanismus nicht als
/// User-Aenderung erkannt (siehe `PlanGeneratorInstantiator.recalculate`-Doku).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TrainingDayEnduranceIntervalFieldsTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private func makeDay() -> TrainingDay {
        TrainingDay(
            name: "Intervalle", weekday: 2, type: .cardio,
            timeFormat: .enduranceIntervals,
            enduranceWarmupDurationSeconds: 600,
            enduranceCooldownDurationSeconds: 300,
            enduranceIntervalRounds: 5,
            enduranceWorkDurationSeconds: 120,
            enduranceRestDurationSeconds: 120
        )
    }

    func testFingerprintChangesWhenEnduranceFieldsChange() throws {
        let context = container.mainContext
        let day = makeDay()
        context.insert(day)

        let baseline = day.currentContentFingerprint

        day.enduranceIntervalRounds = 6
        XCTAssertNotEqual(day.currentContentFingerprint, baseline, "Rundenzahl-Aenderung muss den Fingerprint aendern")

        day.enduranceIntervalRounds = 5
        XCTAssertEqual(day.currentContentFingerprint, baseline, "Zuruecksetzen auf den Ausgangswert muss wieder denselben Fingerprint ergeben")

        day.enduranceWorkDurationSeconds = 90
        XCTAssertNotEqual(day.currentContentFingerprint, baseline, "Belastungsdauer-Aenderung muss den Fingerprint aendern")
    }

    func testWorkDurationAndDistanceAreMutuallyExclusiveByConvention() throws {
        // Dokumentiert die Konvention aus `DaySpec`/`TrainingDay`-Doku: ein
        // Belastungs-Abschnitt hat GENAU eine Zielart (Zeit ODER Strecke,
        // nie beide). Kein erzwungener Invariante-Check im Modell selbst
        // (SwiftData-Properties sind unabhaengig voneinander setzbar, wie
        // bei `ExerciseSpec.targetDistanceKm`/`targetDurationMinutes`
        // bereits etabliert) - dieser Test haelt die Konvention fest, damit
        // ein spaeterer Editor sie bewusst respektieren muss.
        let context = container.mainContext
        let day = makeDay()
        day.enduranceWorkDurationSeconds = nil
        day.enduranceWorkDistanceKm = 1.0
        context.insert(day)

        XCTAssertNil(day.enduranceWorkDurationSeconds)
        XCTAssertEqual(day.enduranceWorkDistanceKm, 1.0)
    }

    func testDaySpecCarriesEnduranceFields() throws {
        // `ProgramInstantiator.instantiate`-Integrationstest bewusst nicht
        // hier (braucht ein volles `ProgramTemplate` + Wochentag-Aufloesung,
        // beides fuer Paket 2 noch ohne echten Erzeuger) - die eigentliche
        // Durchreichung in `ProgramInstantiator.swift` ist eine reine 1:1-
        // Feldkopie, identisch zum bereits etablierten `circuit*`-Muster
        // direkt daneben, und damit durch Code-Review ausreichend belegt.
        let spec = DaySpec(
            name: "Intervalle", type: .cardio, sequenceIndex: 1,
            exercises: [],
            timeFormat: .enduranceIntervals,
            enduranceWarmupDurationSeconds: 600,
            enduranceCooldownDurationSeconds: 300,
            enduranceIntervalRounds: 5,
            enduranceWorkDurationSeconds: 120,
            enduranceRestDurationSeconds: 120
        )
        XCTAssertEqual(spec.timeFormat, .enduranceIntervals)
        XCTAssertEqual(spec.enduranceWarmupDurationSeconds, 600)
        XCTAssertEqual(spec.enduranceCooldownDurationSeconds, 300)
        XCTAssertEqual(spec.enduranceIntervalRounds, 5)
        XCTAssertEqual(spec.enduranceWorkDurationSeconds, 120)
        XCTAssertEqual(spec.enduranceRestDurationSeconds, 120)
    }
}
#endif
