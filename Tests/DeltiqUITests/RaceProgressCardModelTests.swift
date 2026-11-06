#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqUI
import DeltiqData
import DeltiqCore
import DeltiqHealth

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

    // MARK: - Dashboard-Fix "0.0 km vor Coaching-Beginn" (Ticket-Integrationstest)
    //
    // Baut eine Session exakt so, wie `ExternalWorkoutImportService.
    // insertSession` sie NACH dem Fix anlegt (eigene, freistehende Exercise
    // ohne Tag/Plan, `enduranceSportKind` direkt gesetzt, `healthKitSampleUUID`
    // + `isAdHoc`) - beweist, dass echte HealthKit-importierte Laufhistorie
    // vor Coaching-Aktivierung korrekt mitgezaehlt wird und KEINE rueckwirkenden
    // Beobachtungs-Warnungen (Luecke/Plateau) fuer die Zeit davor entstehen.
    private func makeExternalWorkoutRunningSession(startTime: Date, km: Double, seconds: Int, uuid: String) -> WorkoutSession {
        let exercise = Exercise(name: "Freier Lauf", isCardio: true, day: nil)
        exercise.enduranceSportKind = .running
        context.insert(exercise)
        let session = WorkoutSession(startTime: startTime, isCompleted: true, isAdHoc: true, healthKitSampleUUID: uuid)
        context.insert(session)
        context.insert(ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: km, durationSeconds: seconds))
        return session
    }

    func testEightWeeksOfHealthKitImportedHistoryBeforeActivationCountsWithoutRetroactiveWarnings() throws {
        let profile = makeProfile()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let week: TimeInterval = 7 * 86400

        var sessions: [WorkoutSession] = []
        for weeksAgo in stride(from: 8, through: 1, by: -1) {
            let km = Double(15 + weeksAgo)
            sessions.append(makeExternalWorkoutRunningSession(
                startTime: now.addingTimeInterval(-Double(weeksAgo) * week),
                km: km, seconds: 3600, uuid: "hk-\(weeksAgo)"
            ))
        }
        try context.save()

        // Coaching wird erst JETZT, nach den 8 Wochen Historie, aktiviert.
        profile.cardioCoachingEnabledAt = now

        let model = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: sessions, now: now))

        // Summiert statt auf eine exakte Wochen-/Bucket-Zahl zu pruefen -
        // `weekStart` haengt von `Calendar.current` (host-/locale-abhaengig)
        // ab, siehe CardioVolumeOverTimeAggregatorTests-Doku zur selben Falle.
        let expectedKm = stride(from: 8, through: 1, by: -1).reduce(0.0) { $0 + Double(15 + $1) }
        let totalCountedKm = model.weeklySeries.reduce(0.0) { $0 + $1.runningDistanceKm }
        XCTAssertEqual(totalCountedKm, expectedKm, accuracy: 0.001,
                       "alle 8 Wochen echter Importhistorie muessen in den Laufkilometern erscheinen, keine als 0.0 km")
        XCTAssertTrue(
            model.assessment.weeklyFlags.allSatisfy { $0 == .beforeCoachingObservationPeriod },
            "alle 8 Wochen liegen vor der Aktivierung - keine darf als genuineGap/Plateau markiert werden, Flags: \(model.assessment.weeklyFlags)"
        )
        if case .attentionNeeded(let concerns) = model.assessment.outcome {
            XCTAssertFalse(
                concerns.contains { if case .recentTrainingGap = $0 { return true }; if case .volumePlateau = $0 { return true }; return false },
                "keine rueckwirkende Luecken-/Plateau-Warnung fuer Wochen vor der Coaching-Aktivierung"
            )
        }
    }

    // MARK: - Vollstaendiger Datenfluss ueber den ECHTEN Importpfad
    //
    // Anforderung (Verifikations-Nachfrage): nicht nur importaehnliche
    // Fixtures, sondern der komplette Weg HealthKit-Sample -> `insertSession`
    // (echte Produktionsfunktion) -> ExerciseLog/Exercise -> `CardioHistory-
    // Extractor` -> `CardioVolumeOverTimeAggregator` -> `RaceProgressAssessment`
    // -> `RaceProgressCardModel`.
    func testEightWeeksOfHistoryImportedViaTheRealInsertSessionPathCountsCorrectlyEndToEnd() throws {
        let profile = makeProfile()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let week: TimeInterval = 7 * 86400

        for weeksAgo in stride(from: 8, through: 1, by: -1) {
            let km = Double(15 + weeksAgo)
            let start = now.addingTimeInterval(-Double(weeksAgo) * week)
            ExternalWorkoutImportService.insertSession(for: ExternalWorkoutSample(
                hkUUID: "hk-real-\(weeksAgo)", activityType: .running,
                startDate: start, endDate: start.addingTimeInterval(3600),
                distanceKm: km, sourceName: "Strava", sourceBundleIdentifier: "com.strava.app"
            ), in: context)
        }
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 8, "Testaufbau: 8 echte Importe")

        // Coaching wird erst JETZT, nach den 8 Wochen Historie, aktiviert.
        profile.cardioCoachingEnabledAt = now

        let model = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: sessions, now: now))

        let expectedKm = stride(from: 8, through: 1, by: -1).reduce(0.0) { $0 + Double(15 + $1) }
        let totalCountedKm = model.weeklySeries.reduce(0.0) { $0 + $1.runningDistanceKm }
        XCTAssertEqual(totalCountedKm, expectedKm, accuracy: 0.001,
                       "ueber den echten insertSession-Pfad importierte Historie muss vollstaendig in den Laufkilometern erscheinen")
        XCTAssertTrue(
            model.assessment.weeklyFlags.allSatisfy { $0 == .beforeCoachingObservationPeriod },
            "alle 8 Wochen liegen vor der Aktivierung, Flags: \(model.assessment.weeklyFlags)"
        )
    }

    // MARK: - Running Coach - Herzfrequenz-Trainingszonen (Testfaelle 8/9/12)

    func testHeartRateZoneContextIsNoMaxHeartRateConfiguredWhenProfileHasNoMaxHeartRate() throws {
        let profile = makeProfile()
        profile.maxHeartRateBpm = nil
        let model = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: []))
        XCTAssertEqual(model.heartRateZoneContext, .noMaxHeartRateConfigured)
    }

    /// Testfall 8: Phase 1 hat (noch) keine Messdatenquelle fuer
    /// `averageHeartRateBpm` - jede Session ohne Messwert fuehrt daher zu
    /// `.zonesCalculatedNoMeasuredData`, solange eine gueltige HFmax
    /// hinterlegt ist.
    func testHeartRateZoneContextIsZonesOnlyWhenProfileHasMaxHeartRateButNoMeasuredSeries() throws {
        let profile = makeProfile()
        profile.maxHeartRateBpm = 190
        let model = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: []))
        guard case .zonesCalculatedNoMeasuredData(let maxHR, let zones) = model.heartRateZoneContext else {
            return XCTFail("expected .zonesCalculatedNoMeasuredData, got \(model.heartRateZoneContext)")
        }
        XCTAssertEqual(maxHR, 190)
        XCTAssertEqual(zones.count, 5)
    }

    /// Testfall 9 (Modell-Ebene): sobald IRGENDEINE Woche in der Serie einen
    /// gueltigen gemessenen Durchschnittspuls traegt, muss das Modell ihn
    /// aufgreifen und korrekt einordnen - unabhaengig davon, ob Phase 1
    /// diese Quelle heute schon befuellt.
    func testMostRecentMeasuredAverageHeartRateBpmPicksTheLatestWeekWithAValue() {
        let withoutValue = CardioVolumeOverTimePoint(
            weekStart: Date(timeIntervalSince1970: 1_700_000_000), runningDistanceKm: 10, runningSessionCount: 2,
            longestRunKm: 7, averagePaceMinutesPerKm: 6, averageHeartRateBpm: nil,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 0
        )
        let withValue = CardioVolumeOverTimePoint(
            weekStart: Date(timeIntervalSince1970: 1_700_604_800), runningDistanceKm: 12, runningSessionCount: 2,
            longestRunKm: 8, averagePaceMinutesPerKm: 5.9, averageHeartRateBpm: 149.6,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 0
        )
        let result = RaceProgressCardModel.mostRecentMeasuredAverageHeartRateBpm(from: [withoutValue, withValue])
        XCTAssertEqual(result, 150, "muss auf einen ganzzahligen bpm-Wert runden")
    }

    /// Verifikations-Nachfrage Punkt 4: `RaceProgressCardModel.make` liest
    /// `profile.maxHeartRateBpm` bei JEDEM Aufruf frisch - es gibt keinen
    /// gecachten/gespeicherten Zonen-Schnappschuss irgendwo. Eine Aenderung
    /// am Profil zwischen zwei `.make`-Aufrufen muss sich daher vollstaendig
    /// in neu berechneten Zonen niederschlagen, nie in veralteten Werten.
    func testChangingProfileMaxHeartRateBetweenTwoMakeCallsProducesFreshlyRecalculatedZones() throws {
        let profile = makeProfile()
        profile.maxHeartRateBpm = 180

        let before = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: []))
        guard case .zonesCalculatedNoMeasuredData(let maxHRBefore, let zonesBefore) = before.heartRateZoneContext else {
            return XCTFail("expected .zonesCalculatedNoMeasuredData, got \(before.heartRateZoneContext)")
        }
        XCTAssertEqual(maxHRBefore, 180)
        XCTAssertEqual(zonesBefore.last?.upperBoundBpm, 180)

        // Nutzer aendert die HFmax im Profil-Editor.
        profile.maxHeartRateBpm = 200

        let after = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: []))
        guard case .zonesCalculatedNoMeasuredData(let maxHRAfter, let zonesAfter) = after.heartRateZoneContext else {
            return XCTFail("expected .zonesCalculatedNoMeasuredData, got \(after.heartRateZoneContext)")
        }
        XCTAssertEqual(maxHRAfter, 200, "muss den NEUEN Profilwert widerspiegeln, nicht den alten")
        XCTAssertEqual(zonesAfter.last?.upperBoundBpm, 200)
        XCTAssertNotEqual(zonesBefore, zonesAfter, "die Zonen muessen sich mit der HFmax aendern - kein veralteter Stand")
    }

    /// Dieselbe Garantie, wenn die HFmax komplett entfernt wird (z.B.
    /// versehentlich geleertes Feld) - das Modell darf dann nicht die
    /// zuletzt berechneten Zonen weiter anzeigen.
    func testClearingProfileMaxHeartRateRemovesTheZonesOnTheNextMakeCall() throws {
        let profile = makeProfile()
        profile.maxHeartRateBpm = 180
        let before = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: []))
        guard case .zonesCalculatedNoMeasuredData = before.heartRateZoneContext else {
            return XCTFail("Testaufbau: erwartet Zonen vor dem Leeren")
        }

        profile.maxHeartRateBpm = nil
        let after = try XCTUnwrap(RaceProgressCardModel.make(for: profile, allSessions: []))
        XCTAssertEqual(after.heartRateZoneContext, .noMaxHeartRateConfigured)
    }

    func testMostRecentMeasuredAverageHeartRateBpmIsNilWhenNoWeekHasAValue() {
        let point = CardioVolumeOverTimePoint(
            weekStart: Date(), runningDistanceKm: 10, runningSessionCount: 2, longestRunKm: 7,
            averagePaceMinutesPerKm: 6, averageHeartRateBpm: nil,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 0
        )
        XCTAssertNil(RaceProgressCardModel.mostRecentMeasuredAverageHeartRateBpm(from: [point]))
    }
}
#endif
