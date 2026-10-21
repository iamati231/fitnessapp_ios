#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Smart-Onboarding-Epic: Integrationstests fuer `ExperienceTrackBackfill`
/// gegen einen echten in-memory `ModelContainer`. Die reine Herleitungslogik
/// (`ExperienceTrackResolver`) ist bereits in `FitnessAppCoreTests` ohne
/// SwiftData abgedeckt — hier geht es nur um die Persistenz-Grenze: Predicate-
/// Filter, Session-Aggregation, Idempotenz, "nie einen bestehenden Wert
/// ueberschreiben".
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExperienceTrackBackfillTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Builders

    @discardableResult
    private func makeProfile() -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172,
            profile: .male,
            goalWeightKg: 74,
            environment: .gym
        )
        context.insert(profile)
        return profile
    }

    @discardableResult
    private func makeSession(
        exerciseName: String = "Bankdruecken",
        weight: Double = 60,
        reps: Int = 8,
        date: Date,
        isCardio: Bool = false,
        completed: Bool = true
    ) -> WorkoutSession {
        let exercise = fetchOrCreateExercise(name: exerciseName, isCardio: isCardio)

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

    private func fetchOrCreateExercise(name: String, isCardio: Bool = false) -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let exercise = Exercise(name: name, isCardio: isCardio, isTimeBased: false)
        context.insert(exercise)
        return exercise
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    // MARK: - Tests

    /// Kein Trainingsverlauf -> zu wenig Signal, Backfill setzt `.experienced`
    /// statt einen Starter-Plan aufzuzwingen (siehe Resolver-Doku).
    func testBackfillWithNoHistorySetsExperienced() throws {
        let profile = makeProfile()
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)

        XCTAssertEqual(profile.experienceTrack, .experienced)
    }

    /// Genug Kraft-Sessions, die letzte ist frisch (< 14 Tage) -> Experienced.
    func testBackfillWithRecentStrengthHistorySetsExperienced() throws {
        let profile = makeProfile()
        makeSession(date: daysAgo(60))
        makeSession(date: daysAgo(30))
        makeSession(date: daysAgo(5))
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)

        XCTAssertEqual(profile.experienceTrack, .experienced)
    }

    /// Genug Kraft-Sessions, die letzte liegt >= `ComebackAdvisor.minimumGapDays`
    /// zurueck -> Returner, dieselbe Schwelle wie der Comeback-Modus.
    func testBackfillWithOldStrengthHistorySetsReturner() throws {
        let profile = makeProfile()
        makeSession(date: daysAgo(120))
        makeSession(date: daysAgo(90))
        makeSession(date: daysAgo(ComebackAdvisor.minimumGapDays))
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)

        XCTAssertEqual(profile.experienceTrack, .returner)
    }

    /// Reine Cardio-Historie zaehlt nicht als Kraft-Session -> wie "keine
    /// Historie" behandelt (Experienced), nicht faelschlich als Returner.
    func testBackfillIgnoresCardioOnlySessions() throws {
        let profile = makeProfile()
        makeSession(exerciseName: "Laufen", date: daysAgo(200), isCardio: true)
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)

        XCTAssertEqual(profile.experienceTrack, .experienced)
    }

    /// Unvollstaendige (nicht abgeschlossene) Sessions zaehlen nicht mit —
    /// dieselbe "echte Session"-Definition wie `AbsenceDeload`.
    func testBackfillIgnoresIncompleteSessions() throws {
        let profile = makeProfile()
        makeSession(date: daysAgo(ComebackAdvisor.minimumGapDays), completed: false)
        makeSession(date: daysAgo(ComebackAdvisor.minimumGapDays + 1), completed: false)
        makeSession(date: daysAgo(ComebackAdvisor.minimumGapDays + 2), completed: false)
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)

        XCTAssertEqual(profile.experienceTrack, .experienced)
    }

    /// Idempotenz: ein zweiter Lauf nach erfolgreichem Backfill aendert nichts
    /// mehr (Predicate filtert auf `experienceTrackRaw == nil`).
    func testBackfillIsIdempotent() throws {
        let profile = makeProfile()
        makeSession(date: daysAgo(120))
        makeSession(date: daysAgo(90))
        makeSession(date: daysAgo(ComebackAdvisor.minimumGapDays))
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)
        XCTAssertEqual(profile.experienceTrack, .returner)

        // Zweiter Lauf, Historie haette sich inzwischen "verjuengt" (neue,
        // frische Session) -- darf den bereits gesetzten Wert NICHT mehr
        // anfassen, weil das Predicate ihn ausschliesst.
        makeSession(date: daysAgo(1))
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)
        XCTAssertEqual(profile.experienceTrack, .returner)
    }

    /// Ein bereits (z.B. vom echten Onboarding-Flow) gesetzter Wert wird nie
    /// ueberschrieben, selbst wenn er der Historie widerspricht.
    func testBackfillNeverOverwritesExplicitlySetValue() throws {
        let profile = makeProfile()
        profile.experienceTrack = .starter
        makeSession(date: daysAgo(120))
        makeSession(date: daysAgo(90))
        makeSession(date: daysAgo(ComebackAdvisor.minimumGapDays))
        try context.save()

        ExperienceTrackBackfill.runIfNeeded(in: context)

        XCTAssertEqual(profile.experienceTrack, .starter)
    }

    /// Keine Profile in der Datenbank -> darf nicht crashen.
    func testBackfillWithNoProfileDoesNothing() {
        ExperienceTrackBackfill.runIfNeeded(in: context)
        // Kein Assert noetig -- der Test besteht, wenn hier nichts crasht.
    }
}
#endif
