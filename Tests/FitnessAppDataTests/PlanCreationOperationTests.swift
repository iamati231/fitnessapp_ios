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

    /// Nachbesserung (vierte Korrekturrunde, Punkt 2): auch ein ganz normaler, problemloser
    /// Erfolg (kein Rebind-Problem) markiert `committedPlanID` - NICHT nur `createdButRebindFailed`
    /// tut das. Vorher blieb `committedPlanID` hier `nil`, wodurch ein wiederholter `attempt(...)`-
    /// Aufruf (z.B. durch einen nicht korrekt gesperrten Doppel-Tap) `create()` ein zweites Mal
    /// aufgerufen und einen echten zweiten Plan angelegt haette (siehe
    /// `testSuccessThenRepeatedAttemptStillCallsCreateExactlyOnce` fuer den direkten Beleg dafuer).
    func testFirstAttemptSucceedsNormallyWithoutAnyRebindIssue() throws {
        let profile = makeProfile()
        let operation = PlanCreationOperation()

        guard case .success(let plan) = operation.attempt(in: context, create: {
            try PlanGeneratorInstantiator.createPlan(from: self.makeInput(), for: profile, generationSource: .manual, in: self.context)
        }) else {
            return XCTFail("muss im Normalfall .success liefern")
        }
        XCTAssertTrue(plan.isActive)
        XCTAssertEqual(operation.committedPlanID, plan.persistentModelID,
                        "auch ein ganz normaler Erfolg muss committedPlanID setzen")
    }

    /// Geforderter Test (vierte Korrekturrunde, Punkt 2): "Erfolg → erneuter Versuch →
    /// weiterhin genau ein create-Aufruf". Ergaenzt
    /// `testRepeatedAttemptsAfterPermanentRebindFailureNeverCreateASecondPlan` um den Fall OHNE
    /// jedes Rebind-Problem - die "nie wieder create()"-Garantie gilt unconditioniert ab JEDEM
    /// Commit, nicht nur nach einem Rebind-Fehler.
    func testSuccessThenRepeatedAttemptStillCallsCreateExactlyOnce() throws {
        let profile = makeProfile()
        let input = makeInput()
        let operation = PlanCreationOperation()
        var createCallCount = 0
        func create() throws -> TrainingPlan? {
            createCallCount += 1
            return try PlanGeneratorInstantiator.createPlan(from: input, for: profile, generationSource: .manual, in: context)
        }

        guard case .success(let firstPlan) = operation.attempt(in: context, create: create) else {
            return XCTFail("erster Aufruf muss .success liefern")
        }
        XCTAssertEqual(createCallCount, 1)

        for _ in 0..<3 {
            guard case .success(let resolvedPlan) = operation.attempt(in: context, create: create) else {
                return XCTFail("wiederholter Versuch nach normalem Erfolg muss weiterhin .success liefern")
            }
            XCTAssertEqual(resolvedPlan.persistentModelID, firstPlan.persistentModelID)
        }
        XCTAssertEqual(createCallCount, 1, "create() darf nach einem ganz normalen Erfolg NIE WIEDER aufgerufen werden")

        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 1, "trotz mehrfacher Wiederholung darf nur genau ein Plan entstanden sein")
    }

    /// Nachbesserung (vierte Korrekturrunde, Punkt 3): `completion` laeuft bei einem SOFORTIGEN,
    /// problemlosen Erfolg genau einmal, synchron noch vor der Rueckgabe von `attempt(...)` - ein
    /// wiederholter Aufruf (jetzt bereits committed) darf sie nicht nochmal ausloesen.
    func testCompletionRunsExactlyOnceOnImmediateSuccess() throws {
        let profile = makeProfile()
        let operation = PlanCreationOperation()
        var completionRunCount = 0

        guard case .success = operation.attempt(
            in: context,
            create: { try PlanGeneratorInstantiator.createPlan(from: self.makeInput(), for: profile, generationSource: .manual, in: self.context) },
            completion: { completionRunCount += 1 }
        ) else {
            return XCTFail("muss im Normalfall .success liefern")
        }
        XCTAssertEqual(completionRunCount, 1)

        _ = operation.attempt(
            in: context,
            create: { try PlanGeneratorInstantiator.createPlan(from: self.makeInput(), for: profile, generationSource: .manual, in: self.context) },
            completion: { completionRunCount += 1 }
        )
        XCTAssertEqual(completionRunCount, 1, "completion darf nach dem ersten Lauf nie wieder ausgefuehrt werden")
    }

    /// Nachbesserung (vierte Korrekturrunde, Punkt 3): scheitert die Rueckbindung zunaechst,
    /// laeuft die BEIM ERSTEN AUFRUF uebergebene `completion` erst bei der SPAETEREN
    /// erfolgreichen Aufloesung — genau einmal, nicht bei jedem Zwischenversuch. Eine bei einem
    /// spaeteren Aufruf NEU uebergebene Closure wird dabei bewusst ignoriert (siehe Typ-Doku
    /// Punkt 3): nur die beim urspruenglichen, erfolgreichen Commit bestaetigten Werte zaehlen,
    /// nie eine zwischenzeitlich neu berechnete Aufrufer-Closure.
    func testCompletionFromFirstCallReplaysExactlyOnceOnLaterResolutionIgnoringNewerClosures() throws {
        let profile = makeProfile()
        let input = makeInput()
        PlanGeneratorInstantiator.rebindOverrideForTesting = { _, _ in nil }

        let operation = PlanCreationOperation()
        var firstCompletionRunCount = 0
        var laterCompletionRunCount = 0

        guard case .committedButUnresolved = operation.attempt(
            in: context,
            create: { try PlanGeneratorInstantiator.createPlan(from: input, for: profile, generationSource: .manual, in: self.context) },
            completion: { firstCompletionRunCount += 1 }
        ) else {
            return XCTFail("erster Aufruf muss .committedButUnresolved liefern")
        }
        XCTAssertEqual(firstCompletionRunCount, 0, "completion darf vor erfolgreicher Aufloesung nicht laufen")

        // Zwischenversuch waehrend die Stoerung noch besteht - weder die urspruengliche noch
        // eine neu uebergebene completion darf laufen.
        _ = operation.attempt(
            in: context,
            create: { try PlanGeneratorInstantiator.createPlan(from: input, for: profile, generationSource: .manual, in: self.context) },
            completion: { laterCompletionRunCount += 1 }
        )
        XCTAssertEqual(firstCompletionRunCount, 0)
        XCTAssertEqual(laterCompletionRunCount, 0)

        // Stoerung beheben - die naechste Aufloesung (hier ueber resumeIfCommitted, wie es ein
        // spaeterer "Erneut versuchen"-Tap tatsaechlich ausloest) muss GENAU die ERSTE
        // completion nachholen, nicht die zwischenzeitlich uebergebene.
        PlanGeneratorInstantiator.rebindOverrideForTesting = nil
        guard case .success = operation.resumeIfCommitted(in: context) else {
            return XCTFail("nach Behebung muss die Aufloesung .success liefern")
        }
        XCTAssertEqual(firstCompletionRunCount, 1, "die urspruengliche completion muss jetzt genau einmal gelaufen sein")
        XCTAssertEqual(laterCompletionRunCount, 0, "eine spaeter uebergebene, neue completion darf nie laufen")

        // Weitere Aufloesung darf die bereits gelaufene completion nicht nochmal ausfuehren.
        _ = operation.resumeIfCommitted(in: context)
        XCTAssertEqual(firstCompletionRunCount, 1)
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
