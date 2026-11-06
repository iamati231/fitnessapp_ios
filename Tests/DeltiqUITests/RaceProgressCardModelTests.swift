#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqUI
import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class RaceProgressCardModelTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeProfile(cardioCoachingEnabled: Bool = true) -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: cardioCoachingEnabled, cardioGoal: .halfMarathon
        )
        context.insert(profile)
        return profile
    }

    func testMakeReturnsNilWhenCoachingDisabled() {
        let profile = makeProfile(cardioCoachingEnabled: false)
        XCTAssertNil(RaceProgressCardModel.make(for: profile, allSessions: []))
    }

    func testMakeReturnsNonNilForEnabledCoachEvenWithNoHistoryAtAll() {
        let profile = makeProfile()
        let model = RaceProgressCardModel.make(for: profile, allSessions: [])
        // Keine Historie - trotzdem ein Modell, mit einem ehrlichen
        // insufficientData/leeren Zustand statt eines nil (Ticket-Testfall 6).
        XCTAssertNotNil(model)
    }

    // Testfall 22: Schutz vor stale Werten.
    func testCurrentWeeklyVolumeNeverUsesStaleOnboardingSnapshot() {
        let week1 = CardioVolumeOverTimePoint(
            weekStart: Date(timeIntervalSince1970: 1_700_000_000), runningDistanceKm: 10, runningSessionCount: 2,
            longestRunKm: 7, averagePaceMinutesPerKm: 6, averageHeartRateBpm: nil,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 2
        )
        let week2 = CardioVolumeOverTimePoint(
            weekStart: Date(timeIntervalSince1970: 1_700_604_800), runningDistanceKm: 20, runningSessionCount: 3,
            longestRunKm: 12, averagePaceMinutesPerKm: 5.8, averageHeartRateBpm: nil,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 2
        )
        let result = RaceProgressCardModel.currentWeeklyVolume(from: [week1, week2])
        XCTAssertEqual(result, 15, "muss das Mittel der echten letzten Wochen sein (10+20)/2, nie ein anderswo gepflegter Wert")
    }

    func testCurrentWeeklyVolumeIsNilWhenNoRecentWeekHasRunningVolume() {
        let zeroWeek = CardioVolumeOverTimePoint(
            weekStart: Date(), runningDistanceKm: 0, runningSessionCount: 0, longestRunKm: nil,
            averagePaceMinutesPerKm: nil, averageHeartRateBpm: nil, crossTrainingSessionCount: 0,
            ambiguousCardioSessionCount: 0, strengthSessionCount: 3
        )
        XCTAssertNil(RaceProgressCardModel.currentWeeklyVolume(from: [zeroWeek]))
    }

    func testConfigurationFingerprintChangesWithGoalOrRaceDate() {
        let raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let a = RaceProgressCardModel.makeConfigurationFingerprint(goal: .halfMarathon, raceDate: raceDate)
        let b = RaceProgressCardModel.makeConfigurationFingerprint(goal: .marathon, raceDate: raceDate)
        let c = RaceProgressCardModel.makeConfigurationFingerprint(goal: .halfMarathon, raceDate: nil)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// `dismiss(profile:)` darf ausschliesslich den Dismiss-Fingerprint
    /// setzen - kein Plan-/Profil-Ziel anfassen.
    func testDismissOnlySetsTheDismissedFingerprint() {
        let profile = makeProfile()
        guard let model = RaceProgressCardModel.make(for: profile, allSessions: []) else {
            return XCTFail("expected model")
        }
        let originalGoal = profile.cardioGoal

        model.dismiss(profile: profile)

        XCTAssertEqual(profile.raceProgressDismissedFingerprint, model.dismissalFingerprint)
        XCTAssertEqual(profile.cardioGoal, originalGoal)
    }

    // MARK: - Bugfix-Regression, End-to-End (kritischer Migrations-Fund)
    //
    // Anforderung 4/5: beweist, dass (a) migrierte historische Laufeinheiten
    // tatsaechlich in den Wochenumfang einfliessen (nicht 0 wegen des
    // Snapshot-Bugs) und (b) `cardioCoachingEnabledAt` einen ECHTEN,
    // aktuellen Trainingsstopp NICHT verdeckt und NIE zu einem faelschlich
    // positiven "auf Kurs"-Urteil fuehrt, nur weil die Historie davor
    // (korrekterweise) keine Inaktivitaets-Warnung ausloest.

    private func makeMigratedRunningSession(startTime: Date, km: Double, seconds: Int) -> WorkoutSession {
        let day = TrainingDay(name: "Run", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Easy Run", isCardio: true, day: day)
        exercise.enduranceSportKind = .running
        context.insert(exercise)
        day.exercises.append(exercise)

        let session = WorkoutSession(startTime: startTime, isCompleted: true)
        context.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: km, durationSeconds: seconds)
        context.insert(log)
        // Migrations-Zustand: exerciseNameSnapshot ist (wie immer seit
        // DEL-051) gesetzt, aber das NEUE Sportart-Feld existierte beim
        // urspruenglichen Loggen noch nicht.
        log.exerciseEnduranceSportKindSnapshot = nil
        return session
    }

    func testMigratedHistoryCountsTowardVolumeAndARealRecentGapIsNeverHiddenByTheObservationPeriodBoundary() throws {
        let profile = makeProfile()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let week: TimeInterval = 7 * 86400

        // 6 Wochen echte, migrierte Laufhistorie (Wochen -8 bis -3).
        var sessions: [WorkoutSession] = []
        for weeksAgo in stride(from: 8, through: 3, by: -1) {
            sessions.append(makeMigratedRunningSession(startTime: now.addingTimeInterval(-Double(weeksAgo) * week), km: 20, seconds: 7200))
        }
        try context.save()

        // Beobachtungszeitraum beginnt vor 2 Wochen - die 6 Wochen Historie
        // liegen DAVOR (korrekt keine Inaktivitaets-Warnung dafuer), die
        // letzten 2 Wochen (plus die aktuelle) sind eine ECHTE, aktuelle
        // Trainingspause OHNE jegliches Log.
        profile.cardioCoachingEnabledAt = now.addingTimeInterval(-2 * week)

        let model = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: sessions, now: now))

        // Anforderung 4: die migrierte Historie zaehlt tatsaechlich.
        let historicalPoints = model.weeklySeries.filter { $0.weekStart < profile.cardioCoachingEnabledAt! }
        XCTAssertFalse(historicalPoints.isEmpty, "Testaufbau: es muessen Wochen vor der Beobachtungsgrenze existieren")
        XCTAssertTrue(
            historicalPoints.contains { $0.runningDistanceKm > 0 },
            "migrierte historische Laufeinheiten muessen in den Wochenumfang einfliessen, nicht als 0 erscheinen"
        )

        // Anforderung 5: die aktuelle, echte Luecke NACH der Beobachtungsgrenze
        // wird nicht durch die Historie oder die Beobachtungsgrenze verdeckt.
        let recentFlags = zip(model.weeklySeries, model.assessment.weeklyFlags)
            .filter { $0.0.weekStart >= profile.cardioCoachingEnabledAt! }
            .map(\.1)
        XCTAssertFalse(recentFlags.isEmpty, "Testaufbau: es muss mindestens eine Woche innerhalb des Beobachtungszeitraums geben (sonst waere die folgende Pruefung bedeutungslos erfuellt)")
        XCTAssertTrue(
            recentFlags.allSatisfy { $0 == .genuineGap },
            "die Wochen nach der Beobachtungsgrenze ohne jegliches Log muessen als echte Luecke erkannt werden, Flags: \(recentFlags)"
        )

        switch model.assessment.outcome {
        case .onTrack:
            XCTFail("eine echte, aktuelle Trainingspause darf NIE zu einem faelschlich positiven 'auf Kurs'-Urteil fuehren, nur weil die aeltere Historie (korrekt) keine Warnung ausloest")
        case .attentionNeeded(let concerns), .offTrack(let concerns):
            XCTAssertTrue(
                concerns.contains { if case .recentTrainingGap = $0 { return true }; return false },
                "die aktuelle Luecke muss als recentTrainingGap-Befund sichtbar werden"
            )
        case .insufficientData:
            XCTFail("6 Wochen Historie + 2+ Wochen Luecke sind genug Daten fuer ein echtes Urteil, nicht 'unzureichend'")
        }
    }
}
#endif
