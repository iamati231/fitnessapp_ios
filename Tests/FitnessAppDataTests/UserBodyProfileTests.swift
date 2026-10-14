#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Direkte Unit-Tests fuer berechnete `UserBodyProfile`-Properties (kein
/// Export/Import-Roundtrip — dafuer `DataPortabilityRoundtripTests`).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class UserBodyProfileTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @discardableResult
    private func makeProfile(in context: ModelContext) -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        context.insert(profile)
        return profile
    }

    /// Fix "Doppelte Abnehmen-Semantik": `.fatloss` existierte kurzzeitig als
    /// eigener `TrainingGoal`-Fall auf diesem Branch, bevor er wieder mit
    /// `.weightLoss` zusammengelegt wurde. Ein zwischenzeitlich geschriebener
    /// oder importierter Rohwert "fatloss" darf nicht crashen oder auf
    /// `.hybrid` zurueckfallen, sondern muss weiter als `.weightLoss` lesbar
    /// bleiben.
    func testOldFatlossRawValueDecodesToWeightLoss() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.trainingGoalRaw = "fatloss"

        XCTAssertEqual(profile.trainingGoal, .weightLoss)
    }

    /// Ein voellig unbekannter Rohwert (weder aktueller noch alter Case)
    /// faellt weiterhin auf `.hybrid` zurueck statt zu crashen.
    func testUnknownRawValueFallsBackToHybrid() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.trainingGoalRaw = "does-not-exist"

        XCTAssertEqual(profile.trainingGoal, .hybrid)
    }

    /// Setzen via die typisierte Property schreibt weiterhin den echten
    /// `TrainingGoal.weightLoss`-Rohwert, keinen alten "fatloss"-Reststand.
    func testSettingWeightLossWritesCurrentRawValue() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.trainingGoal = .weightLoss

        XCTAssertEqual(profile.trainingGoalRaw, "weightLoss")
    }

    // MARK: - Start-Check: baselineAssessment get/set

    func testBaselineAssessmentDefaultsToNil() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        XCTAssertNil(profile.baselineAssessment)
    }

    func testSettingBaselineAssessmentRoundTripsThroughFlatFields() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        let assessment = BaselineAssessment(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: .guidedTest,
            safetyStatus: .clear,
            pushUp: PushUpAssessment(variant: .incline, cleanReps: 6),
            chairSquat: ChairSquatAssessment(cleanReps: 9, durationSeconds: 30),
            pull: PullAssessment(variant: .assistedPullUp, cleanReps: 3),
            plank: PlankAssessment(seconds: 25),
            cardio: CardioBaseline(answer: .runsRegularly),
            pushSelfAssessment: nil,
            legsSelfAssessment: nil,
            pullSelfAssessment: nil,
            desiredFirstWeekIntensity: .comfortablyChallenging
        )

        profile.baselineAssessment = assessment

        XCTAssertEqual(profile.baselineAssessment, assessment)
        // Stichprobe auf den flachen Feldern selbst — das ist der eigentliche
        // Persistenz-Vertrag (CSV-Export liest genau diese, nicht den Struct).
        XCTAssertEqual(profile.baselinePushUpVariantRaw, "incline")
        XCTAssertEqual(profile.baselinePushUpCleanReps, 6)
        XCTAssertEqual(profile.baselineChairSquatCleanReps, 9)
        XCTAssertEqual(profile.baselinePullVariantRaw, "assistedPullUp")
        XCTAssertEqual(profile.baselineCardioAnswerRaw, "runsRegularly")
    }

    /// Fehlt eines der vier Pflichtfelder (hier: kein Datum, also "nie
    /// gesetzt"), ist das Gesamtergebnis `nil` — keine Teil-Rekonstruktion
    /// aus verwaisten Einzelfeldern.
    func testBaselineAssessmentIsNilIfRequiredFieldsAreMissingEvenWithPartialData() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.baselinePushUpVariantRaw = "standard"
        profile.baselinePushUpCleanReps = 10

        XCTAssertNil(profile.baselineAssessment)
    }

    /// Setzen von `nil` loescht alle Einzelfelder wieder — kein Karteileichen-
    /// Risiko, falls ein Nutzer seinen Check zurueckzieht.
    func testSettingNilClearsAllUnderlyingFields() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)
        profile.baselineAssessment = BaselineAssessment(
            date: Date(), source: .guidedTest, safetyStatus: .clear,
            pushUp: PushUpAssessment(variant: .standard, cleanReps: 10)
        )

        profile.baselineAssessment = nil

        XCTAssertNil(profile.baselineDate)
        XCTAssertNil(profile.baselineSourceRaw)
        XCTAssertNil(profile.baselinePushUpVariantRaw)
        XCTAssertNil(profile.baselinePushUpCleanReps)
    }

    /// Ein unbekannter Rohwert in EINEM Unterfeld (z.B. nach einem
    /// zukuenftigen Enum-Rename) darf nicht die anderen, gueltigen Felder
    /// mitreissen — nur das betroffene Unterergebnis wird `nil`.
    func testUnknownSubFieldRawValueDropsOnlyThatSubResult() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)
        profile.baselineAssessment = BaselineAssessment(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: .guidedTest,
            safetyStatus: .clear,
            plank: PlankAssessment(seconds: 30)
        )
        profile.baselinePushUpVariantRaw = "does-not-exist-anymore"
        profile.baselinePushUpCleanReps = 10

        XCTAssertNil(profile.baselineAssessment?.pushUp)
        XCTAssertEqual(profile.baselineAssessment?.plank, PlankAssessment(seconds: 30))
    }

    // MARK: - Smart-Onboarding-Epic Phase 2: equipmentProfile get/set

    /// "Eine leere alte Auswahl bleibt unbekannt" — ein frisches Profil (wie
    /// ein echtes Bestandsprofil vor dieser Phase) liest fuer JEDES Item
    /// `.unknown`, nie `.unavailable`.
    func testEquipmentProfileDefaultsToAllUnknown() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        for item in EquipmentItem.allCases {
            XCTAssertEqual(profile.equipmentProfile.availability(for: item), .unknown)
            XCTAssertNil(profile.equipmentProfile.count(for: item))
        }
    }

    func testSettingEquipmentProfileRoundTripsThroughFlatFields() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.equipmentProfile = UserEquipmentProfile(
            availability: [.kettlebell: .available, .pullUpBar: .unavailable],
            counts: [.kettlebell: 2]
        )

        XCTAssertEqual(Set(profile.equipmentAvailableItemsRaw), ["kettlebell"])
        XCTAssertEqual(Set(profile.equipmentUnavailableItemsRaw), ["pullUpBar"])
        XCTAssertEqual(profile.equipmentItemCountsRaw, ["kettlebell:2"])

        XCTAssertEqual(profile.equipmentProfile.availability(for: .kettlebell), .available)
        XCTAssertEqual(profile.equipmentProfile.availability(for: .pullUpBar), .unavailable)
        XCTAssertEqual(profile.equipmentProfile.availability(for: .barbell), .unknown, "Unberuehrtes Item bleibt unbekannt")
        XCTAssertEqual(profile.equipmentProfile.count(for: .kettlebell), 2)
    }

    /// Ein Item darf nie gleichzeitig in beiden Rohlisten stehen — Umschalten
    /// von verfuegbar auf nicht-verfuegbar muss den alten Eintrag ersetzen,
    /// nicht duplizieren.
    func testTogglingAvailabilityNeverLeavesItemInBothRawLists() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.equipmentProfile = UserEquipmentProfile(availability: [.rack: .available])
        XCTAssertTrue(profile.equipmentAvailableItemsRaw.contains("rack"))
        XCTAssertFalse(profile.equipmentUnavailableItemsRaw.contains("rack"))

        profile.equipmentProfile = UserEquipmentProfile(availability: [.rack: .unavailable])
        XCTAssertFalse(profile.equipmentAvailableItemsRaw.contains("rack"))
        XCTAssertTrue(profile.equipmentUnavailableItemsRaw.contains("rack"))
    }

    /// Gleicher Robustness-Pattern wie `equipmentPreferences`/
    /// `activeDashboardWidgets`: ein veralteter Rohwert (Enum-Case existiert
    /// nicht mehr) wird beim Lesen stillschweigend uebersprungen statt zu
    /// crashen oder die uebrigen Eintraege zu verwerfen.
    func testStaleRawItemIsIgnoredOnRead() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.equipmentAvailableItemsRaw = ["kettlebell", "does-not-exist-anymore"]
        profile.equipmentItemCountsRaw = ["kettlebell:2", "garbage", "does-not-exist-anymore:3"]

        XCTAssertEqual(profile.equipmentProfile.availability(for: .kettlebell), .available)
        XCTAssertEqual(profile.equipmentProfile.count(for: .kettlebell), 2)
    }

    /// Nur Items mit `supportsCount == true` werden ueberhaupt in Betracht
    /// gezogen fuer die Stueckzahl-Erfassung in echten Aufrufen — der
    /// Accessor selbst ist zwar permissiv (encodiert, was ihm gegeben wird),
    /// aber ein Item OHNE erfasste Stueckzahl bleibt nil, niemals 0.
    func testCountDefaultsToNilNotZeroWhenNeverSet() throws {
        let container = try makeContainer()
        let profile = makeProfile(in: container.mainContext)

        profile.equipmentProfile = UserEquipmentProfile(availability: [.dumbbell: .available])

        XCTAssertNil(profile.equipmentProfile.count(for: .dumbbell))
    }
}
#endif
