#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Integration tests for `PersonalRecordSync` against a real in-memory
/// `ModelContainer`. Both helper functions are stateful and order-sensitive —
/// `rebuild` walks completed sessions chronologically and accumulates history
/// as it goes; bugs there silently corrupt the user's Trophy Room. Pure-value
/// detection logic lives in `PRDetectorTests` (Core); these tests only verify
/// the SwiftData boundary: insertion, ordering, wipe, attribution.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PersonalRecordSyncTests: XCTestCase {

    // SwiftData's mainContext is main-thread-only, so the whole class is
    // @MainActor. The container is recreated per test for full isolation.
    var container: ModelContainer!

    override func setUpWithError() throws {
        // Schema(types:) accepts the array of model types directly — index-based
        // unpacking would silently break the moment AppSchema.types grows.
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Builders

    /// Creates a completed `WorkoutSession` with a single ExerciseLog for the
    /// given exercise. The exercise is created on demand if needed.
    @discardableResult
    private func makeSession(
        exerciseName: String = "Bankdruecken",
        weight: Double,
        reps: Int,
        date: Date,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        completed: Bool = true
    ) -> WorkoutSession {
        let exercise = fetchOrCreateExercise(
            name: exerciseName, isCardio: isCardio, isTimeBased: isTimeBased
        )

        let session = WorkoutSession(
            startTime: date,
            endTime: date,
            durationMinutes: 30,
            exerciseCount: 1,
            totalSets: 1,
            totalVolumeKg: weight * Double(reps),
            isCompleted: completed,
            dayName: "Test"
        )
        context.insert(session)

        let log = ExerciseLog(
            date: date,
            setIndex: 0,
            weight: weight,
            reps: reps,
            rir: 2.0,
            exercise: exercise,
            session: session
        )
        context.insert(log)
        return session
    }

    /// Returns an existing Exercise with `name` or creates one.
    private func fetchOrCreateExercise(
        name: String,
        isCardio: Bool = false,
        isTimeBased: Bool = false
    ) -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let exercise = Exercise(
            name: name,
            isCardio: isCardio,
            isTimeBased: isTimeBased
        )
        context.insert(exercise)
        return exercise
    }

    /// Returns all PRE rows currently in the store, sorted by date ascending so
    /// chronological assertions read naturally top-to-bottom.
    private func allPREs() throws -> [PersonalRecordEntry] {
        try context.fetch(
            FetchDescriptor<PersonalRecordEntry>(
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
        )
    }

    // MARK: - Helpers for date arithmetic

    private func day(_ offsetDays: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: TimeInterval(offsetDays) * 24 * 3600)
    }

    // MARK: - Test A: Chronological rebuild

    /// Three sessions: 80 → 85 → 82 kg. Rebuild should produce only TWO PRs
    /// (the 80 kg baseline doesn't get one — first session has no history)
    /// — wait, that's wrong: the first session is the BASELINE, so it produces
    /// no PR. Second session beats first → 1 PR. Third session is below second →
    /// no PR. Net: 1 PR.
    ///
    /// Actually with 3 weighted PRs per session (heaviest, bestSet, est1RM), the
    /// second session can produce up to 3. We assert on the heaviestWeight slice
    /// because that's the unambiguous one.
    func testRebuildProducesPRsOnlyForGenuineImprovements() throws {
        // Session 1: 80 kg × 5 — baseline, no PR.
        makeSession(weight: 80, reps: 5, date: day(1))
        // Session 2: 85 kg × 5 — clear improvement, heaviestWeight PR.
        makeSession(weight: 85, reps: 5, date: day(2))
        // Session 3: 82 kg × 5 — below previous best, NO heaviestWeight PR.
        makeSession(weight: 82, reps: 5, date: day(3))
        try context.save()

        let inserted = PersonalRecordSync.rebuild(in: context)
        try context.save()

        XCTAssertGreaterThan(inserted, 0, "Should produce at least one PR")
        let prs = try allPREs()
        let heaviest = prs.filter { $0.kindRaw == PersonalRecord.Kind.heaviestWeight.rawValue }
        XCTAssertEqual(heaviest.count, 1,
                       "Exactly one heaviestWeight PR — Session 2 over Session 1's baseline")
        XCTAssertEqual(heaviest.first?.value, 85)
        XCTAssertEqual(heaviest.first?.previousValue, 80)
        XCTAssertEqual(heaviest.first?.date, day(2),
                       "PR is dated to the session that achieved it, not the rebuild moment")
    }

    func testRebuildProcessesSessionsInChronologicalOrder() throws {
        // Insert in REVERSE date order to verify the rebuild's internal sort
        // — if it processed insertion order instead of dates, Session 3
        // (90 kg) inserted first would become the baseline and Session 1
        // (80 kg) would never produce a PR.
        makeSession(weight: 90, reps: 5, date: day(3))   // newest, inserted FIRST
        makeSession(weight: 85, reps: 5, date: day(2))
        makeSession(weight: 80, reps: 5, date: day(1))   // oldest, inserted LAST
        try context.save()

        PersonalRecordSync.rebuild(in: context)
        try context.save()

        let heaviest = try allPREs()
            .filter { $0.kindRaw == PersonalRecord.Kind.heaviestWeight.rawValue }
            .sorted { $0.date < $1.date }

        XCTAssertEqual(heaviest.count, 2,
                       "Two improvements in chronological order: 80→85 and 85→90")
        XCTAssertEqual(heaviest[0].value, 85)
        XCTAssertEqual(heaviest[0].date, day(2))
        XCTAssertEqual(heaviest[1].value, 90)
        XCTAssertEqual(heaviest[1].date, day(3))
    }

    // MARK: - Test B: Wipe behavior

    func testRebuildWipesPreExistingPREsBeforeRecomputing() throws {
        // 1) Two real sessions that should produce one heaviestWeight PR.
        makeSession(weight: 80, reps: 5, date: day(1))
        makeSession(weight: 85, reps: 5, date: day(2))
        try context.save()

        // 2) Manually inject a bogus PRE that wouldn't be produced by detection
        //    (e.g. survived from a buggy earlier version).
        let bogus = PersonalRecordEntry(
            date: day(99),
            exerciseName: "Bankdruecken",
            kindRaw: PersonalRecord.Kind.heaviestWeight.rawValue,
            value: 999,
            previousValue: 0,
            weightKg: 999,
            reps: 1
        )
        context.insert(bogus)
        try context.save()

        let beforeRebuild = try allPREs()
        XCTAssertTrue(beforeRebuild.contains { $0.value == 999 },
                      "Sanity: bogus PRE is in the store pre-rebuild")

        // 3) Rebuild — must wipe + recompute.
        PersonalRecordSync.rebuild(in: context)
        try context.save()

        let afterRebuild = try allPREs()
        XCTAssertFalse(afterRebuild.contains { $0.value == 999 },
                       "Bogus PRE must be wiped by rebuild")
        let heaviest = afterRebuild.filter { $0.kindRaw == PersonalRecord.Kind.heaviestWeight.rawValue }
        XCTAssertEqual(heaviest.count, 1)
        XCTAssertEqual(heaviest.first?.value, 85)
    }

    func testRebuildOnEmptyStoreProducesZeroEntries() throws {
        let inserted = PersonalRecordSync.rebuild(in: context)
        try context.save()

        XCTAssertEqual(inserted, 0)
        XCTAssertTrue(try allPREs().isEmpty)
    }

    func testRebuildIgnoresIncompleteSessions() throws {
        // First session: completed, baseline 80kg.
        makeSession(weight: 80, reps: 5, date: day(1), completed: true)
        // Second session: NOT completed, with a higher lift.
        // It must NOT contribute to history (that's a "set in flight", not a
        // record), and must NOT produce a PR row of its own.
        makeSession(weight: 100, reps: 5, date: day(2), completed: false)
        try context.save()

        let inserted = PersonalRecordSync.rebuild(in: context)
        try context.save()

        XCTAssertEqual(inserted, 0,
                       "Incomplete sessions are invisible to rebuild — only one completed session, no history to beat")
    }

    // MARK: - Test C: Forward-Save (recordPRs)

    func testForwardSaveAttributesPRToTheCorrectSession() throws {
        // Session 1 establishes the baseline.
        let session1 = makeSession(weight: 80, reps: 5, date: day(1))
        try context.save()

        // Session 2 beats it.
        let session2 = makeSession(weight: 90, reps: 5, date: day(2))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session2, in: context)
        try context.save()

        XCTAssertFalse(detected.isEmpty,
                       "Session 2's 90kg over Session 1's 80kg should yield PRs")
        let heaviest = detected.first { $0.kind == .heaviestWeight }
        XCTAssertNotNil(heaviest)
        XCTAssertEqual(heaviest?.previousValue, 80)
        XCTAssertEqual(heaviest?.newValue, 90)

        // Verify the persisted PRE row is back-linked to session2 specifically.
        let prs = try allPREs()
            .filter { $0.kindRaw == PersonalRecord.Kind.heaviestWeight.rawValue }
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs.first?.session?.persistentModelID, session2.persistentModelID,
                       "PRE.session must point to session2, not session1")
        XCTAssertNotEqual(prs.first?.session?.persistentModelID, session1.persistentModelID)
    }

    func testForwardSaveSkipsWhenSessionIsNotCompleted() throws {
        // Baseline.
        makeSession(weight: 80, reps: 5, date: day(1))
        // Incomplete-but-better session.
        let session2 = makeSession(weight: 100, reps: 5, date: day(2), completed: false)
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session2, in: context)
        try context.save()

        XCTAssertTrue(detected.isEmpty,
                      "recordPRs is a no-op for incomplete sessions — defensive guard")
        XCTAssertTrue(try allPREs().isEmpty)
    }

    func testForwardSaveExcludesOwnSessionFromHistory() throws {
        // Edge case: the only completed session is the one we're calling
        // recordPRs on. There's no PRIOR history, so no PR can be set
        // (matches PRDetector's "first session establishes baseline" rule).
        let session = makeSession(weight: 100, reps: 5, date: day(1))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session, in: context)
        try context.save()

        XCTAssertTrue(detected.isEmpty,
                      "Session must not see itself as history — first-ever workout produces no PR")
        XCTAssertTrue(try allPREs().isEmpty)
    }

    /// Regression (Audit-Fund): `fetchHistoricalLifts` zaehlte vorher JEDE
    /// andere abgeschlossene Session als Historie, auch eine mit SPAETEREM
    /// `startTime` — z.B. wenn ein Nutzer eine Session nachtraeglich
    /// rueckdatiert und `recordPRs` danach fuer die rueckdatierte (aeltere)
    /// Session laeuft, waehrend die juengere Session schon im Store steckt.
    /// `rebuild(in:)` sieht pro Session dagegen nur Lifts STRIKT DAVOR.
    ///
    /// Ohne echte AELTERE Historie (session0) waere JEDE Erwartung hier nur
    /// Zufall: PRDetector verlangt per Vertrag mindestens einen Historie-
    /// Eintrag, bevor ueberhaupt ein PR moeglich ist ("erste Session liefert
    /// nur die Baseline, kein PR") — das gilt auch fuer `rebuild(in:)`, das
    /// der chronologisch ersten Session ebenfalls KEINEN PR gibt. Der
    /// eigentliche Fund: ohne den Datums-Filter wuerde session1 (day 1,
    /// 80kg) faelschlich gegen session2 (day 2, 100kg) verglichen und damit
    /// ihre echte Verbesserung gegenueber session0 (day 0, 50kg) verlieren.
    func testForwardSaveIgnoresLaterSessionsAsHistory() throws {
        makeSession(weight: 50, reps: 5, date: day(0))
        makeSession(weight: 100, reps: 5, date: day(2))
        let session1 = makeSession(weight: 80, reps: 5, date: day(1))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session1, in: context)
        try context.save()

        XCTAssertFalse(detected.isEmpty,
                       "session1 (80kg) beats session0's 50kg baseline — the later " +
                       "session2 (100kg) must not be counted as history and hide that")
        let heaviest = detected.first { $0.kind == .heaviestWeight }
        XCTAssertNotNil(heaviest)
        XCTAssertEqual(heaviest?.newValue, 80)
        XCTAssertEqual(heaviest?.previousValue, 50)
    }

    // MARK: - Cross-cutting: bodyweight + time-based

    func testRebuildHandlesBodyweightExerciseMaxRepsPR() throws {
        // Pushup history: 12 reps → 15 reps. Bodyweight category, so the second
        // session produces a maxReps PR (no heaviestWeight, weight is 0).
        makeSession(exerciseName: "Liegestuetze", weight: 0, reps: 12, date: day(1))
        makeSession(exerciseName: "Liegestuetze", weight: 0, reps: 15, date: day(2))
        try context.save()

        PersonalRecordSync.rebuild(in: context)
        try context.save()

        let prs = try allPREs()
        XCTAssertEqual(prs.count, 1, "One maxReps PR for the second session")
        XCTAssertEqual(prs.first?.kindRaw, PersonalRecord.Kind.maxReps.rawValue)
        XCTAssertEqual(prs.first?.reps, 15)
        XCTAssertEqual(prs.first?.previousValue, 12)
    }

    func testRebuildHandlesTimeBasedExerciseMaxHoldSeconds() throws {
        // Plank: 30s → 60s. Time-based category, expect a maxHoldSeconds PR.
        makeSession(exerciseName: "Plank", weight: 0, reps: 30,
                    date: day(1), isTimeBased: true)
        makeSession(exerciseName: "Plank", weight: 0, reps: 60,
                    date: day(2), isTimeBased: true)
        try context.save()

        PersonalRecordSync.rebuild(in: context)
        try context.save()

        let prs = try allPREs()
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs.first?.kindRaw, PersonalRecord.Kind.maxHoldSeconds.rawValue)
        XCTAssertEqual(prs.first?.reps, 60)
    }

    func testRebuildIgnoresCardioCompletely() throws {
        // Cardio sessions should never produce PRs (separate metric domain).
        makeSession(exerciseName: "Laufband", weight: 0, reps: 20,
                    date: day(1), isCardio: true)
        makeSession(exerciseName: "Laufband", weight: 0, reps: 30,
                    date: day(2), isCardio: true)
        try context.save()

        let inserted = PersonalRecordSync.rebuild(in: context)
        try context.save()

        XCTAssertEqual(inserted, 0)
        XCTAssertTrue(try allPREs().isEmpty)
    }

    // MARK: - Zeitformate (Bugfix, Audit)

    /// Timed-format sessions (AMRAP/EMOM/Auf Zeit) never write `ExerciseLog`s,
    /// so `sessionLifts` is always empty for them. Creates a completed
    /// session directly (no log, no exercise) — mirrors how
    /// `TimedWorkoutPlayerView.finishTimedSession` actually persists a WOD run.
    @discardableResult
    private func makeTimedSession(
        wodName: String = "Cindy",
        format: WorkoutTimeFormat = .amrap,
        date: Date,
        roundsCompleted: Int? = nil,
        finishTimeSeconds: Int? = nil,
        completedTarget: Bool = false
    ) -> WorkoutSession {
        let session = WorkoutSession(
            startTime: date,
            endTime: date,
            durationMinutes: 20,
            exerciseCount: 3,
            isCompleted: true,
            dayName: wodName,
            timeFormatSnapshot: format,
            roundsCompleted: roundsCompleted,
            finishTimeSeconds: finishTimeSeconds,
            completedTarget: completedTarget
        )
        context.insert(session)
        return session
    }

    /// Bugfix (Audit): `rebuild()` used to wipe every `PersonalRecordEntry`
    /// and regenerate PRs ONLY from `ExerciseLog`-based lifts — timed-format
    /// sessions were never re-examined, so "Aus History neu berechnen"
    /// permanently deleted every WOD personal record without ever restoring
    /// it. Two AMRAP "Cindy" runs, same WOD name — the second, higher round
    /// count must produce exactly one `mostRounds` PR, just like the
    /// incremental `recordTimedFormatPR` path already did.
    func testRebuildDetectsAmrapMostRoundsPR() throws {
        makeTimedSession(date: day(1), roundsCompleted: 12, completedTarget: true)
        makeTimedSession(date: day(2), roundsCompleted: 15, completedTarget: true)
        try context.save()

        let inserted = PersonalRecordSync.rebuild(in: context)
        try context.save()

        XCTAssertEqual(inserted, 1, "Erste Session ist die Baseline, nur die zweite liefert einen PR")
        let prs = try allPREs()
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs.first?.kindRaw, PersonalRecord.Kind.mostRounds.rawValue)
        XCTAssertEqual(prs.first?.value, 15)
        XCTAssertEqual(prs.first?.previousValue, 12)
        XCTAssertEqual(prs.first?.date, day(2))
    }

    /// Gleiche Erwartung fuer `.forTime` — die zweite (schnellere,
    /// vollstaendig abgeschlossene) Session muss eine `fastestTime`-PR
    /// liefern, nicht nur die AMRAP-Variante.
    func testRebuildDetectsForTimeFastestTimePR() throws {
        makeTimedSession(wodName: "Fran", format: .forTime, date: day(1),
                          finishTimeSeconds: 300, completedTarget: true)
        makeTimedSession(wodName: "Fran", format: .forTime, date: day(2),
                          finishTimeSeconds: 240, completedTarget: true)
        try context.save()

        PersonalRecordSync.rebuild(in: context)
        try context.save()

        let prs = try allPREs()
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs.first?.kindRaw, PersonalRecord.Kind.fastestTime.rawValue)
        XCTAssertEqual(prs.first?.value, 240)
        XCTAssertEqual(prs.first?.previousValue, 300)
    }

    /// Strength- und Zeitformat-PRs muessen im selben Rebuild-Durchlauf
    /// unabhaengig voneinander erkannt werden — keiner darf den anderen
    /// verdraengen oder dessen Historie-Akkumulator kontaminieren.
    func testRebuildDetectsBothStrengthAndTimedFormatPRsInSameRun() throws {
        makeSession(weight: 80, reps: 5, date: day(1))
        makeSession(weight: 85, reps: 5, date: day(2))
        makeTimedSession(date: day(1), roundsCompleted: 12, completedTarget: true)
        makeTimedSession(date: day(2), roundsCompleted: 15, completedTarget: true)
        try context.save()

        let inserted = PersonalRecordSync.rebuild(in: context)
        try context.save()

        let prs = try allPREs()
        XCTAssertGreaterThanOrEqual(inserted, 2)
        XCTAssertTrue(prs.contains { $0.kindRaw == PersonalRecord.Kind.mostRounds.rawValue })
        XCTAssertTrue(prs.contains { $0.kindRaw == PersonalRecord.Kind.heaviestWeight.rawValue })
    }

    // MARK: - Perf scoping (Audit Fix 1): targeted history fetch

    /// Creates a completed `WorkoutSession` with a single `ExerciseLog` for an
    /// already-existing `Exercise` object (unlike `makeSession(exerciseName:...)`,
    /// which looks the exercise up/creates it by name) — needed to test history
    /// lookup via a stable `exerciseTemplateID` across a later rename.
    @discardableResult
    private func makeSession(
        for exercise: Exercise,
        weight: Double,
        reps: Int,
        date: Date,
        completed: Bool = true
    ) -> WorkoutSession {
        let session = WorkoutSession(
            startTime: date,
            endTime: date,
            durationMinutes: 30,
            exerciseCount: 1,
            totalSets: 1,
            totalVolumeKg: weight * Double(reps),
            isCompleted: completed,
            dayName: "Test"
        )
        context.insert(session)
        context.insert(ExerciseLog(
            date: date, setIndex: 0, weight: weight, reps: reps, rir: 2.0,
            exercise: exercise, session: session
        ))
        return session
    }

    /// Regression (Audit-Fix): `fetchHistoricalLifts` now fetches history per
    /// exercise identity (scoped to the finished session's own exercises)
    /// instead of scanning the whole `ExerciseLog` table. A session that logs
    /// TWO different exercises must still find each one's own correct prior
    /// best, in the same `recordPRs` call.
    func testForwardSaveFindsCorrectHistoryAcrossMultipleExercisesInOneSession() throws {
        makeSession(exerciseName: "Bankdruecken", weight: 80, reps: 5, date: day(1))
        makeSession(exerciseName: "Kniebeuge", weight: 100, reps: 5, date: day(1))
        try context.save()

        let session = WorkoutSession(
            startTime: day(2), endTime: day(2), durationMinutes: 30,
            exerciseCount: 2, totalSets: 2, totalVolumeKg: 85 * 5 + 110 * 5,
            isCompleted: true, dayName: "Test"
        )
        context.insert(session)
        let bench = fetchOrCreateExercise(name: "Bankdruecken")
        let squat = fetchOrCreateExercise(name: "Kniebeuge")
        context.insert(ExerciseLog(date: day(2), setIndex: 0, weight: 85, reps: 5, rir: 2, exercise: bench, session: session))
        context.insert(ExerciseLog(date: day(2), setIndex: 0, weight: 110, reps: 5, rir: 2, exercise: squat, session: session))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session, in: context)
        try context.save()

        let heaviest = detected.filter { $0.kind == .heaviestWeight }
        XCTAssertEqual(heaviest.count, 2, "Both exercises must find their own history and each produce a PR")
        XCTAssertTrue(heaviest.contains { $0.exerciseName == "Bankdruecken" && $0.newValue == 85 && $0.previousValue == 80 })
        XCTAssertTrue(heaviest.contains { $0.exerciseName == "Kniebeuge" && $0.newValue == 110 && $0.previousValue == 100 })
    }

    /// Regression (Audit-Fix): irrelevant history for an exercise NOT present
    /// in the finished session must not leak into — or block — PR detection
    /// for the exercise that actually was logged. Guards against the new
    /// targeted fetch accidentally over- or under-scoping.
    func testForwardSaveIgnoresHistoryOfUnrelatedExercise() throws {
        // Unrelated exercise with its own (much higher) history — must have
        // zero influence on "Bankdruecken" detection below.
        makeSession(exerciseName: "Kreuzheben", weight: 200, reps: 3, date: day(1))
        makeSession(exerciseName: "Bankdruecken", weight: 80, reps: 5, date: day(1))
        try context.save()

        let session = makeSession(exerciseName: "Bankdruecken", weight: 85, reps: 5, date: day(2))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session, in: context)
        try context.save()

        XCTAssertEqual(detected.filter { $0.kind == .heaviestWeight }.count, 1)
        XCTAssertEqual(detected.first { $0.kind == .heaviestWeight }?.previousValue, 80,
                       "Must compare against Bankdruecken's own history (80kg), not Kreuzheben's (200kg)")
        XCTAssertTrue(try allPREs().allSatisfy { $0.exerciseName == "Bankdruecken" },
                      "No PR row should ever be attributed to the unrelated exercise")
    }

    /// Regression (Audit-Fix): the targeted fetch matches history both by
    /// `exerciseNameSnapshot` AND by the stable `exerciseTemplateIDSnapshot`
    /// — a renamed exercise must still find its pre-rename history via the
    /// unchanged template ID, exactly like the old unscoped fetch did.
    func testForwardSaveFindsHistoryAcrossExerciseRenameViaStableTemplateID() throws {
        let templateID = UUID()
        let exercise = Exercise(name: "Overhead Press", exerciseTemplateID: templateID, isCardio: false, isTimeBased: false)
        context.insert(exercise)
        makeSession(for: exercise, weight: 40, reps: 5, date: day(1))
        try context.save()

        // Rename after the fact — the template ID (and thus identity) stays stable.
        exercise.name = "Schulterdruecken stehend"
        try context.save()

        let session = makeSession(for: exercise, weight: 45, reps: 5, date: day(2))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session, in: context)
        try context.save()

        XCTAssertFalse(detected.isEmpty, "Renamed exercise must still find its history via the stable exerciseTemplateID")
        let heaviest = detected.first { $0.kind == .heaviestWeight }
        XCTAssertEqual(heaviest?.previousValue, 40)
        XCTAssertEqual(heaviest?.newValue, 45)
    }

    /// Regression (Audit-Fix): a log whose exercise has BOTH a matching
    /// `exerciseNameSnapshot` AND a matching `exerciseTemplateIDSnapshot`
    /// hits both of the targeted fetches in `fetchHistoricalLifts` — dedup by
    /// `persistentModelID` must keep it from being returned (and counted)
    /// twice.
    func testForwardSaveDoesNotDoubleCountALogMatchedByBothNameAndTemplateID() throws {
        let templateID = UUID()
        let exercise = Exercise(name: "Kreuzheben", exerciseTemplateID: templateID, isCardio: false, isTimeBased: false)
        context.insert(exercise)
        makeSession(for: exercise, weight: 120, reps: 3, date: day(1))
        try context.save()

        let session = makeSession(for: exercise, weight: 130, reps: 3, date: day(2))
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: session, in: context)
        try context.save()

        let heaviest = detected.filter { $0.kind == .heaviestWeight }
        XCTAssertEqual(heaviest.count, 1, "Exactly one heaviestWeight PR, not duplicated by the two-predicate fetch")
        XCTAssertEqual(heaviest.first?.previousValue, 120)
    }

    /// Regression (Audit-Fix): a timed-format session (AMRAP/EMOM/Auf Zeit)
    /// has `sessionLifts.isEmpty` — the new early-return in
    /// `fetchHistoricalLifts` must not break `recordPRs`' no-op contract for
    /// those (handled separately by `recordTimedFormatPR`).
    func testForwardSaveOnEmptySessionLiftsIsANoOpWithoutFetching() throws {
        makeSession(exerciseName: "Bankdruecken", weight: 80, reps: 5, date: day(1))
        try context.save()

        let timedSession = makeTimedSession(date: day(2), roundsCompleted: 10, completedTarget: true)
        try context.save()

        let detected = PersonalRecordSync.recordPRs(for: timedSession, in: context)
        try context.save()

        XCTAssertTrue(detected.isEmpty, "No ExerciseLogs on a timed-format session — nothing for recordPRs to detect")
    }
}
#endif
