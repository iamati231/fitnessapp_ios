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
}
#endif
