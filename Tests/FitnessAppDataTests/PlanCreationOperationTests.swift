#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Nachbesserung (Task #197, dritte Korrekturrunde): prüft den tatsächlich von der UI
/// verwendeten Operationszustand (`PlanCreationOperation`) unabhängig von SwiftUI — reines
/// `ModelContainer`/`ModelContext`-Setup, keine View, kein `@State`. Der bestehende
/// `PlanGeneratorInstantiatorTests`-Service-Test belegt nur, dass `createPlan` selbst GENAU
/// EINEN internen Retry unternimmt — er belegt NICHT, dass ein erneuter Tap auf den
/// Übernehmen-Button (modelliert hier als wiederholter `attempt(...)`-Aufruf) niemals ein
/// zweites Mal `create()` aufruft.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanCreationOperationTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
        PlanGeneratorInstantiator.rebindOverrideForTesting = nil
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
    }

    private var context: ModelContext { container.mainContext }

    private func makeInput(days: Int = 2) -> PlanGeneratorInput {
        PlanGeneratorInput(
            selections: [PlanGeneratorTypeSelection(kind: .barbell, daysPerWeek: days, sessionDurationMinutes: 45, experience: .intermediate)],
            equipmentPreferences: [], usesFixedWeekdays: false
        )
    }

    private func makeProfile() -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000), heightCm: 180,
            profile: .male, goalWeightKg: 80, environment: .gym
        )
        context.insert(profile)
        return profile
    }

    /// Kern-Regressionstest (geforderter Test): erster Aufruf speichert genau einen Plan, die
    /// Rückbindung scheitert DAUERHAFT (auch über `createPlan`s eigenen internen Retry hinaus,
    /// simuliert durch einen permanent fehlschlagenden `rebindOverrideForTesting`) —
    /// mehrfaches Wiederholen darf NIE ein zweites `create()` auslösen, die Anzahl
    /// persistierter Pläne bleibt bei eins. Behebt sich die Störung, löst ein weiterer
    /// Versuch dieselbe ID auf, immer noch ohne `create()` erneut aufzurufen.
    func testRepeatedAttemptsAfterPermanentRebindFailureNeverCreateASecondPlan() throws {
        let profile = makeProfile()
        let input = makeInput()
        PlanGeneratorInstantiator.rebindOverrideForTesting = { _, _ in nil }

        let operation = PlanCreationOperation()
        var createCallCount = 0
        func create() throws -> TrainingPlan? {
            createCallCount += 1
            return try PlanGeneratorInstantiator.createPlan(from: input, for: profile, generationSource: .manual, in: context)
        }

        guard case .committedButUnresolved = operation.attempt(in: context, create: create) else {
            return XCTFail("erster Aufruf muss .committedButUnresolved liefern")
        }
        XCTAssertEqual(createCallCount, 1)

        let persistedAfterFirstAttempt = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(persistedAfterFirstAttempt.count, 1, "der Plan muss bereits nach dem ersten Versuch persistiert sein")
        let committedID = try XCTUnwrap(operation.committedPlanID)

        for _ in 0..<3 {
            guard case .committedButUnresolved = operation.attempt(in: context, create: create) else {
                return XCTFail("weiterer Versuch bei dauerhaftem Rebind-Fehler muss .committedButUnresolved liefern")
            }
        }
        XCTAssertEqual(createCallCount, 1, "create() darf nach dem ersten erfolgreichen Commit NIE WIEDER aufgerufen werden")

        let allPlansStillPending = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlansStillPending.count, 1, "Anzahl persistierter Pläne muss trotz mehrfacher Wiederholung bei eins bleiben")

        // Störung behoben - ein weiterer Versuch löst dieselbe ID auf, erfolgreich, immer noch
        // ohne `create()` erneut aufzurufen.
        PlanGeneratorInstantiator.rebindOverrideForTesting = nil
        guard case .success(let resolvedPlan) = operation.attempt(in: context, create: create) else {
            return XCTFail("nach Behebung der Störung muss der Versuch .success liefern")
        }
        XCTAssertEqual(resolvedPlan.persistentModelID, committedID)
        XCTAssertEqual(createCallCount, 1, "auch der erfolgreiche Abschluss-Versuch darf create() nicht erneut aufrufen")

        let finalPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(finalPlans.count, 1)
    }

    /// Gegenprobe: im Normalfall (keinerlei Rebind-Problem) bleibt `committedPlanID` `nil` —
    /// die Zustandsmaschine greift nur ein, wenn sie tatsächlich gebraucht wird.
    func testFirstAttemptSucceedsNormallyWithoutAnyRebindIssue() throws {
        let profile = makeProfile()
        let operation = PlanCreationOperation()

        guard case .success(let plan) = operation.attempt(in: context, create: {
            try PlanGeneratorInstantiator.createPlan(from: self.makeInput(), for: profile, generationSource: .manual, in: self.context)
        }) else {
            return XCTFail("muss im Normalfall .success liefern")
        }
        XCTAssertTrue(plan.isActive)
        XCTAssertNil(operation.committedPlanID, "im Normalfall bleibt committedPlanID nil")
    }

    /// Ein leeres Generator-Ergebnis (`create()` liefert `nil`, kein Fehler) darf nichts als
    /// committed markieren - ein erneuter Versuch muss weiterhin die volle Operation ausführen
    /// dürfen.
    func testNothingToCreateDoesNotMarkAnythingAsCommitted() throws {
        let profile = makeProfile()
        let operation = PlanCreationOperation()
        let emptyInput = PlanGeneratorInput(selections: [], equipmentPreferences: [], usesFixedWeekdays: false)

        guard case .nothingToCreate = operation.attempt(in: context, create: {
            try PlanGeneratorInstantiator.createPlan(from: emptyInput, for: profile, generationSource: .manual, in: self.context)
        }) else {
            return XCTFail("leeres Generator-Ergebnis muss .nothingToCreate liefern")
        }
        XCTAssertNil(operation.committedPlanID)
    }

    /// Ein ECHTER Speicherfehler (nichts persistiert) darf ebenfalls nichts als committed
    /// markieren - ein erneuter Versuch muss die volle Operation wiederholen dürfen, das ist
    /// der bewusst unterschiedliche Vertrag zu `committedButUnresolved`.
    func testGenuineSaveFailureIsRetryableAndDoesNotMarkAnythingAsCommitted() throws {
        let profile = makeProfile()
        let operation = PlanCreationOperation()

        struct TestSaveError: Error {}
        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        guard case .failedBeforeCommit = operation.attempt(in: context, create: {
            try PlanGeneratorInstantiator.createPlan(from: self.makeInput(), for: profile, generationSource: .manual, in: self.context)
        }) else {
            return XCTFail("ein echter Speicherfehler muss .failedBeforeCommit liefern")
        }
        XCTAssertNil(operation.committedPlanID, "nichts wurde persistiert - ein erneuter Versuch darf die volle Operation wiederholen")

        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertTrue(allPlans.isEmpty)

        // Gegenprobe: Stoerung beheben, erneuter Versuch darf jetzt die volle Operation
        // erfolgreich ausfuehren (anders als bei committedButUnresolved).
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
        guard case .success = operation.attempt(in: context, create: {
            try PlanGeneratorInstantiator.createPlan(from: self.makeInput(), for: profile, generationSource: .manual, in: self.context)
        }) else {
            return XCTFail("nach Behebung muss ein erneuter Versuch die volle Operation erfolgreich wiederholen")
        }
        let allPlansAfterRetry = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlansAfterRetry.count, 1)
    }
}
#endif
