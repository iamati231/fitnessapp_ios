import Testing
import Foundation
@testable import DeltiqCore

struct StrengthProgressCalculatorTests {

    typealias SPC = StrengthProgressCalculator
    typealias Log = StrengthProgressCalculator.StrengthLog
    typealias Period = StrengthProgressCalculator.Period

    static let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 16
        return Calendar.current.date(from: c)!
    }()

    static func makeLog(
        sessionDate: Date = now,
        name: String = "Squat",
        templateID: UUID? = nil,
        weightKg: Double = 100,
        reps: Int = 5,
        rpe: Double = 8,
        rir: Float = 2,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        isPlaceholder: Bool = false
    ) -> Log {
        Log(sessionStartTime: sessionDate, exerciseName: name, templateID: templateID,
            weightKg: weightKg, reps: reps, rpe: rpe, rir: rir,
            isCardio: isCardio, isTimeBased: isTimeBased, isPlaceholder: isPlaceholder)
    }

    static func daysAgo(_ n: Int, from base: Date = now) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: base)!
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

    @Test func kgUnitsUnchangedInCore() {
        // Core always works in kg; formatting/conversion is view responsibility
        let stats = SPC.overviewStats(
            logs: [makeLog(weightKg: 100, reps: 5)],
            strengthSessionDates: [now], prDates: [],
            period: .allTime, now: now
        )
        #expect(stats.volumeKg == 500)
    }
}
