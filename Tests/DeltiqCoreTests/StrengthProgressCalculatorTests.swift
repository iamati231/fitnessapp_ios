import Testing
import Foundation
@testable import DeltiqCore

struct StrengthProgressCalculatorTests {

    typealias SPC = StrengthProgressCalculator
    typealias Log = StrengthProgressCalculator.StrengthLog
    typealias Period = StrengthProgressCalculator.Period

    let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 16
        return Calendar.current.date(from: c)!
    }()

    func makeLog(
        sessionDate: Date? = nil,
        name: String = "Squat",
        templateID: UUID? = nil,
        weightKg: Double = 100,
        reps: Int = 5,
        rpe: Double = 8,
        rir: Float = 2,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        isPlaceholder: Bool = false,
        logID: String? = nil
    ) -> Log {
        Log(sessionStartTime: sessionDate ?? now, exerciseName: name, templateID: templateID,
            weightKg: weightKg, reps: reps, rpe: rpe, rir: rir,
            isCardio: isCardio, isTimeBased: isTimeBased, isPlaceholder: isPlaceholder,
            logID: logID)
    }

    func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: now)!
    }

    // MARK: - overviewStats

    @Test func regularStrengthSession() {
        let logs = [makeLog(weightKg: 100, reps: 5), makeLog(weightKg: 80, reps: 8)]
        let stats = SPC.overviewStats(logs: logs, strengthSessionDates: [now], prDates: [], period: .allTime, now: now)
        #expect(stats.sessionCount == 1)
        #expect(stats.workSetCount == 2)
        #expect(stats.volumeKg == 100*5 + 80*8)
        #expect(stats.prCount == 0)
    }

    @Test func mixedSessionExcludesCardio() {
        let logs = [makeLog(weightKg: 100, reps: 5), makeLog(name: "Run", isCardio: true)]
        let stats = SPC.overviewStats(logs: logs, strengthSessionDates: [now], prDates: [], period: .allTime, now: now)
        #expect(stats.workSetCount == 1)
        #expect(stats.volumeKg == 500)
    }

    @Test func placeholderSetsExcluded() {
        let logs = [makeLog(weightKg: 0, reps: 0, isPlaceholder: true), makeLog(weightKg: 100, reps: 5)]
        let stats = SPC.overviewStats(logs: logs, strengthSessionDates: [now], prDates: [], period: .allTime, now: now)
        #expect(stats.workSetCount == 1)
        #expect(stats.volumeKg == 500)
    }

    @Test func periodFilterFourWeeksCutsOldSets() {
        let recent = makeLog(sessionDate: daysAgo(10))
        let old    = makeLog(sessionDate: daysAgo(50))
        let stats = SPC.overviewStats(
            logs: [recent, old],
            strengthSessionDates: [daysAgo(10)],
            prDates: [],
            period: .fourWeeks,
            now: now
        )
        #expect(stats.workSetCount == 1)
        #expect(stats.sessionCount == 1)
    }

    /// Four sessions at the four canonical test dates from Issue #26 QA.
    /// now = Nov 16, 2026:
    ///   daysAgo(0)   → within 4W (28 d cutoff)
    ///   daysAgo(57)  → within 12W (84 d) but NOT 4W  → Sep 20, 2026
    ///   daysAgo(168) → within 1Y (365 d) but NOT 12W → Jun 1, 2026
    ///   daysAgo(411) → allTime only                   → Oct 1, 2025
    /// Expected session counts: 4W=1, 12W=2, 1Y=3, All=4.
    @Test func periodFilterAllFourPeriodsDistinctCounts() {
        let d4W  = daysAgo(0)
        let d12W = daysAgo(57)
        let d1Y  = daysAgo(168)
        let dAll = daysAgo(411)
        let logs = [makeLog(sessionDate: d4W), makeLog(sessionDate: d12W),
                    makeLog(sessionDate: d1Y),  makeLog(sessionDate: dAll)]
        let sessionDates = [d4W, d12W, d1Y, dAll]

        let s4W  = SPC.overviewStats(logs: logs, strengthSessionDates: sessionDates, prDates: [], period: .fourWeeks,   now: now)
        let s12W = SPC.overviewStats(logs: logs, strengthSessionDates: sessionDates, prDates: [], period: .twelveWeeks, now: now)
        let s1Y  = SPC.overviewStats(logs: logs, strengthSessionDates: sessionDates, prDates: [], period: .oneYear,     now: now)
        let sAll = SPC.overviewStats(logs: logs, strengthSessionDates: sessionDates, prDates: [], period: .allTime,     now: now)

        #expect(s4W.sessionCount  == 1)
        #expect(s12W.sessionCount == 2)
        #expect(s1Y.sessionCount  == 3)
        #expect(sAll.sessionCount == 4)
        #expect(s4W.workSetCount  == 1)
        #expect(s12W.workSetCount == 2)
        #expect(s1Y.workSetCount  == 3)
        #expect(sAll.workSetCount == 4)
    }

    @Test func prCountFilteredByPeriod() {
        let prDates = [daysAgo(5), daysAgo(50)]
        let stats = SPC.overviewStats(logs: [], strengthSessionDates: [], prDates: prDates,
                                      period: .fourWeeks, now: now)
        #expect(stats.prCount == 1)
    }

    @Test func volumeZeroForBodyweightSets() {
        // weightKg == 0 → no volume contribution
        let logs = [Log(sessionStartTime: now, exerciseName: "Pull-up", templateID: nil,
                        weightKg: 0, reps: 10, rpe: 7, rir: 3, isCardio: false,
                        isTimeBased: false, isPlaceholder: false)]
        let stats = SPC.overviewStats(logs: logs, strengthSessionDates: [now], prDates: [], period: .allTime, now: now)
        #expect(stats.workSetCount == 1)
        #expect(stats.volumeKg == 0)
    }

    // MARK: - exerciseSummaries

    @Test func groupsByTemplateIDForRenamedExercise() {
        let id = UUID()
        // Different sessionDates so exerciseSummaries counts 2 unique sessions.
        let logs = [makeLog(sessionDate: daysAgo(1), name: "Squat", templateID: id),
                    makeLog(sessionDate: daysAgo(2), name: "Back Squat", templateID: id)]
        let summaries = SPC.exerciseSummaries(logs: logs)
        #expect(summaries.count == 1)
        #expect(summaries[0].sessionCount == 2)
    }

    @Test func multipleSetsSameSessionCountsOnce() {
        let id = UUID()
        let logs = [makeLog(name: "Squat", templateID: id, weightKg: 100, reps: 5),
                    makeLog(name: "Squat", templateID: id, weightKg: 90, reps: 3)]
        let summaries = SPC.exerciseSummaries(logs: logs)
        #expect(summaries.count == 1)
        #expect(summaries[0].sessionCount == 1)
    }

    @Test func groupsByNameWhenNoTemplateID() {
        let logs = [makeLog(name: "Squat"), makeLog(name: "Squat"), makeLog(name: "Bench Press")]
        let summaries = SPC.exerciseSummaries(logs: logs)
        #expect(summaries.count == 2)
    }

    @Test func deletedExerciseAppearsViaSnapshotName() {
        // Deleted exercise: no templateID, name from snapshot
        let logs = [makeLog(name: "Deleted Old Exercise", templateID: nil)]
        let summaries = SPC.exerciseSummaries(logs: logs)
        #expect(summaries.count == 1)
        #expect(summaries[0].name == "Deleted Old Exercise")
    }

    @Test func timeBasedExerciseHasNo1RM() {
        let logs = [makeLog(name: "Plank", weightKg: 0, reps: 60, isTimeBased: true)]
        let summaries = SPC.exerciseSummaries(logs: logs)
        #expect(summaries.count == 1)
        #expect(summaries[0].best1RMKg == nil)
    }

    @Test func sortedBySessionCountDescending() {
        let d1 = daysAgo(1); let d2 = daysAgo(2); let d3 = daysAgo(3)
        let logs = [
            makeLog(sessionDate: d1, name: "Bench Press"),
            makeLog(sessionDate: d1, name: "Squat"),
            makeLog(sessionDate: d2, name: "Squat"),
            makeLog(sessionDate: d3, name: "Squat"),
        ]
        let summaries = SPC.exerciseSummaries(logs: logs)
        #expect(summaries[0].name == "Squat") // 3 sessions > 1 session
    }

    /// Sibling bug to Commit 069fa3a / PR #58: `groups.values` iteration order is not
    /// insertion-order-stable, so a genuine sessionCount tie needs an explicit tie-breaker.
    @Test func sessionCountTieBreaksAlphabeticallyRegardlessOfInsertionOrder() {
        let d1 = daysAgo(1)
        let orderA = [makeLog(sessionDate: d1, name: "Bench Press"), makeLog(sessionDate: d1, name: "Squat")]
        let orderB = [makeLog(sessionDate: d1, name: "Squat"), makeLog(sessionDate: d1, name: "Bench Press")]

        let summariesA = SPC.exerciseSummaries(logs: orderA)
        let summariesB = SPC.exerciseSummaries(logs: orderB)

        #expect(summariesA.map(\.name) == ["Bench Press", "Squat"])
        #expect(summariesB.map(\.name) == ["Bench Press", "Squat"])
    }

    // MARK: - oneRMHistory

    @Test func bestPerSessionReturnsOnePointPerSession() {
        let d1 = daysAgo(10)
        let logs = [makeLog(sessionDate: d1, weightKg: 100, reps: 5),
                    makeLog(sessionDate: d1, weightKg: 90, reps: 3)]
        let points = SPC.oneRMHistory(logs: logs, exerciseName: "Squat", templateID: nil)
        #expect(points.count == 1)
        let est100x5 = ExerciseCalculations.estimate1RMAverage(weightKg: 100, reps: 5)!
        #expect(abs(points[0].estimatedKg - est100x5) < 0.01)
    }

    @Test func singleSessionYieldsOnePoint() {
        let logs = [makeLog(weightKg: 80, reps: 8)]
        let points = SPC.oneRMHistory(logs: logs, exerciseName: "Squat", templateID: nil)
        #expect(points.count == 1)
    }

    @Test func noPointsForTimeBasedExercise() {
        let logs = [makeLog(name: "Plank", weightKg: 0, reps: 60, isTimeBased: true)]
        let points = SPC.oneRMHistory(logs: logs, exerciseName: "Plank", templateID: nil)
        #expect(points.isEmpty)
    }

    /// Pure-bodyweight exercise (weightKg=0, NOT time-based): no 1RM chart point.
    /// Covers Issue #26 QA: "Reine Bodyweight-/Halteübung ohne 1RM".
    @Test func oneRMHistoryEmptyForPureBodyweightExercise() {
        let logs = [makeLog(name: "Pull-up", weightKg: 0, reps: 10, isTimeBased: false),
                    makeLog(name: "Pull-up", weightKg: 0, reps: 8,  isTimeBased: false)]
        let points = SPC.oneRMHistory(logs: logs, exerciseName: "Pull-up", templateID: nil)
        #expect(points.isEmpty, "weightKg=0 sets must not produce 1RM chart points")
    }

    /// Mixed session: weighted and bodyweight sets for the same exercise.
    /// 1RM history uses only the weighted sets; bodyweight sets still appear in bestSets.
    @Test func oneRMHistoryIgnoresBodyweightSetsInMixedSession() {
        let bw      = makeLog(name: "Pull-up", weightKg: 0,  reps: 10)
        let weighted = makeLog(name: "Pull-up", weightKg: 10, reps: 5)  // 10kg added
        let points = SPC.oneRMHistory(logs: [bw, weighted], exerciseName: "Pull-up", templateID: nil)
        #expect(points.count == 1, "Only the weighted set contributes a 1RM point")
        let sets = SPC.bestSets(logs: [bw, weighted], exerciseName: "Pull-up", templateID: nil)
        #expect(sets.count == 2, "Both sets appear in Best Sets list")
    }

    /// Deleted exercise (no templateID, name via snapshot): still appears in summaries
    /// with correct best1RMKg from its logs. Covers Issue #26 QA:
    /// "Historische oder gelöschte Übung mit Snapshot".
    @Test func deletedExerciseKeepsBest1RMFromSnapshotLogs() {
        let id: UUID? = nil  // templateID gone — grouping falls back to name
        let log = Log(sessionStartTime: now, exerciseName: "Old Exercise", templateID: id,
                      weightKg: 100, reps: 5, rpe: 8, rir: 2,
                      isCardio: false, isTimeBased: false, isPlaceholder: false)
        let summaries = SPC.exerciseSummaries(logs: [log])
        #expect(summaries.count == 1)
        #expect(summaries[0].name == "Old Exercise")
        #expect(summaries[0].best1RMKg != nil, "Deleted exercise must still expose estimated 1RM")
        let expected = ExerciseCalculations.estimate1RMAverage(weightKg: 100, reps: 5)
        #expect(abs(summaries[0].best1RMKg! - expected!) < 0.01)
    }

    // MARK: - bestSets

    @Test func bestSetsLimitRespected() {
        let logs = (1...8).map { makeLog(weightKg: Double($0 * 10), reps: 5) }
        let sets = SPC.bestSets(logs: logs, exerciseName: "Squat", templateID: nil, limit: 5)
        #expect(sets.count == 5)
    }

    @Test func bestSetsOrderedByVolumeDescending() {
        let logs = [makeLog(weightKg: 60, reps: 10), makeLog(weightKg: 100, reps: 5)]
        let sets = SPC.bestSets(logs: logs, exerciseName: "Squat", templateID: nil)
        // 60×10=600 > 100×5=500
        #expect(sets[0].weightKg == 60)
    }

    @Test func identicalSetsHaveUniqueIDs() {
        // Two sets with same weight+reps in same session must not produce duplicate SwiftUI ids.
        let logs = [makeLog(weightKg: 100, reps: 5), makeLog(weightKg: 100, reps: 5)]
        let sets = SPC.bestSets(logs: logs, exerciseName: "Squat", templateID: nil)
        #expect(sets.count == 2)
        #expect(Set(sets.map { $0.id }).count == 2)
    }

    @Test func kgUnitsUnchangedInCore() {
        // Core always works in kg; formatting/conversion is view responsibility
        let stats = SPC.overviewStats(
            logs: [makeLog(weightKg: 100, reps: 5)],
            strengthSessionDates: [now], prDates: [],
            period: .allTime, now: now
        )
        #expect(stats.volumeKg == 500)
    }

    // MARK: - isStrengthPRKind (Issue #24 regression)

    @Test func strengthKindsAccepted() {
        for raw in ["heaviestWeight", "bestSet", "estimated1RM",
                    "maxReps", "maxHoldSeconds", "mostRounds", "fastestTime"] {
            #expect(SPC.isStrengthPRKind(raw) == true, "Expected \(raw) to be a strength kind")
        }
    }

    @Test func cardioKindsRejected() {
        #expect(SPC.isStrengthPRKind("longestDistance") == false)
        #expect(SPC.isStrengthPRKind("fastestPace") == false)
    }

    @Test func unknownKindRejected() {
        // Legacy or future unknown rawValues must not inflate the strength PR count.
        #expect(SPC.isStrengthPRKind("") == false)
        #expect(SPC.isStrengthPRKind("someFutureKind") == false)
    }

    /// End-to-end: legacy cardio PRs (longestDistance/fastestPace) must not appear
    /// in the strength PR count. Covers Issue #26 QA: "Legacy-Cardio-PR ohne Equipment-Snapshot".
    ///
    /// Flow mirrors StrengthProgressView: pre-filter prEntries with isStrengthPRKind,
    /// then pass the remaining dates to overviewStats — cardio dates never enter.
    @Test func cardioLegacyPRNotCountedInStrengthOverview() {
        typealias Entry = (kind: String, date: Date)
        let prEntries: [Entry] = [
            ("longestDistance", now),     // cardio — must be excluded
            ("fastestPace",     now),     // cardio — must be excluded
            ("heaviestWeight",  now),     // strength — must be counted
            ("estimated1RM",    daysAgo(5)), // strength — must be counted
        ]
        let strengthPRDates = prEntries
            .filter { SPC.isStrengthPRKind($0.kind) }
            .map(\.date)
        let stats = SPC.overviewStats(logs: [], strengthSessionDates: [],
                                      prDates: strengthPRDates, period: .allTime, now: now)
        #expect(stats.prCount == 2, "longestDistance and fastestPace must not inflate strength PR count")
    }

    // MARK: - SetDetail.id stability (Issue #24 regression)

    @Test func setIDStableAfterResort() {
        // Set A: 100kg×5 = volume 500 → initially rank 1
        let logA = makeLog(sessionDate: daysAgo(10), weightKg: 100, reps: 5, logID: "log-A")
        // Set B: 80kg×6  = volume 480 → rank 2
        let logB = makeLog(sessionDate: daysAgo(5),  weightKg: 80,  reps: 6, logID: "log-B")

        let sets1 = SPC.bestSets(logs: [logA, logB], exerciseName: "Squat", templateID: nil)
        let idA_before = sets1.first(where: { $0.logID == "log-A" })!.id

        // Set C: 100kg×6 = volume 600 → displaces A to rank 2
        let logC = makeLog(sessionDate: daysAgo(1), weightKg: 100, reps: 6, logID: "log-C")
        let sets2 = SPC.bestSets(logs: [logA, logB, logC], exerciseName: "Squat", templateID: nil)
        let idA_after = sets2.first(where: { $0.logID == "log-A" })!.id

        #expect(idA_before == idA_after, "SetDetail.id must not change when a heavier set enters and shifts rank")
    }
}
