#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// DEL-199: End-to-End-Roundtrip für die Datenportabilität —
/// Seed → Export (ZIP) → Import in einen FRISCHEN Container → Assert.
///
/// Genau dieser Pfad ist im Mai 2026 real schiefgegangen (DEL-182-188:
/// Wipe vor Validation + Grapheme-Cluster-Parser-Bug = kompletter
/// Datenbestand weg). Die Unit-Tests in `CSVRoundtripTests` decken die
/// Parser-Schicht ab; HIER wird die volle Pipeline durch ZIPFoundation,
/// alle CSV-Builder und den Three-Pass-Merge verifiziert.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DataPortabilityRoundtripTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Befüllt einen Context mit einem realistischen Mini-Datenbestand:
    /// Profil, Plan→Day→Exercise-Kette, Session mit Logs, PR, Gear,
    /// Messung, Wasser — plus ein Orphan-Log (Session-Backref nil), wie
    /// es das DEL-051-Snapshot-Pattern erlaubt.
    private func seed(_ context: ModelContext) throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172,
            profile: .male,
            goalWeightKg: 74,
            environment: .gym
        )
        profile.firstName = "Test"
        context.insert(profile)

        let plan = TrainingPlan(name: "Roundtrip-Plan", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .push, plan: plan)
        context.insert(day)
        // DEL-208: Übung MITTEN in einer Deload-Woche (DEL-200) — das
        // suggestedWeight ist halbiert, das Original liegt im Snapshot.
        // Der Import muss aufs Original normalisieren.
        let exercise = Exercise(name: "Bankdrücken", sets: 3, suggestedWeight: 40, day: day)
        exercise.deloadOriginalWeight = 80
        context.insert(exercise)

        let gear = Gear(name: "Testschuh", type: .shoe)
        context.insert(gear)

        let session = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_750_000_000),
            endTime: Date(timeIntervalSince1970: 1_750_003_600),
            durationMinutes: 60, exerciseCount: 1, totalSets: 2,
            totalVolumeKg: 1_280, isCompleted: true, day: day
        )
        session.gear = gear
        context.insert(session)

        for setIndex in 0..<2 {
            let log = ExerciseLog(
                date: session.startTime, setIndex: setIndex,
                weight: 80, reps: 8, rir: 2,
                exercise: exercise, session: session
            )
            context.insert(log)
        }
        // Orphan-Log: nur Snapshot-Identität, keine Session (DEL-189-Pfad).
        let orphan = ExerciseLog(
            date: Date(timeIntervalSince1970: 1_749_000_000),
            setIndex: 0, weight: 60, reps: 10, rir: 3
        )
        orphan.exerciseNameSnapshot = "Kniebeuge"
        context.insert(orphan)

        context.insert(PersonalRecordEntry(
            date: session.startTime, exerciseName: "Bankdrücken",
            kindRaw: "estimated1RM", value: 100, previousValue: 95,
            weightKg: 80, reps: 8, session: session
        ))
        context.insert(BodyMeasurement(
            date: Date(timeIntervalSince1970: 1_749_500_000),
            ageYearsAtMeasurement: 32, weightKg: 78.5
        ))
        context.insert(WaterEntry(
            date: Date(timeIntervalSince1970: 1_750_000_000), amountMl: 500
        ))
        try context.save()
    }

    // MARK: - Tests

    func testExportImportRoundtripRestoresAllRows() throws {
        // 1) Quelle befüllen + exportieren.
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)
        XCTAssertGreaterThan(bundle.data.count, 500, "ZIP darf nicht leer sein")

        // 2) In einen FRISCHEN Container importieren (Append auf leer =
        //    Neues-Gerät-Szenario).
        let target = try makeContainer()
        let result = try DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        // 3) Asserts — Result-Counter UND echte Store-Inhalte.
        XCTAssertEqual(result.errorRows, 0, "Roundtrip darf keine Row-Errors produzieren")
        let ctx = target.mainContext
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<UserBodyProfile>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<TrainingPlan>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<TrainingDay>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Exercise>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseLog>()), 3,
                       "2 Session-Logs + 1 Orphan-Log")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<PersonalRecordEntry>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Gear>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<BodyMeasurement>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WaterEntry>()), 1)

        // 4) Beziehungen + Werte stichprobenartig.
        let plan = try ctx.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertEqual(plan?.isActive, true, "DEL-192: aktiver Plan bleibt aktiv")
        let importedExercise = plan?.days.first?.exercises.first
        XCTAssertEqual(importedExercise?.name, "Bankdrücken")
        // DEL-208: Mid-Deload-Export wird beim Import aufs Original
        // normalisiert — NICHT die halbierten 40 kg übernehmen.
        XCTAssertEqual(importedExercise?.suggestedWeight, 80,
                       "Deload-Original muss restauriert werden, nicht das halbierte Gewicht")
        XCTAssertNil(importedExercise?.deloadOriginalWeight,
                     "Import landet im sauberen Nicht-Deload-Zustand")
        let profile = try ctx.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(profile?.firstName, "Test")
        let session = try ctx.fetch(FetchDescriptor<WorkoutSession>()).first
        XCTAssertEqual(session?.logs.count, 2)
        XCTAssertNotNil(session?.gear, "Gear-FK muss über die idMap resolven")
    }

    func testReimportIntoSameStoreSkipsDuplicates() throws {
        // Append-Import in den GLEICHEN Store: alles Duplikat, nichts doppelt.
        let container = try makeContainer()
        try seed(container.mainContext)
        let bundle = try DataExportService.makeExport(context: container.mainContext)

        let result = try DataImportService.performImport(
            zipData: bundle.data,
            context: container.mainContext,
            strategy: .appendOnly
        )

        let ctx = container.mainContext
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WorkoutSession>()), 1,
                       "Session darf nicht dupliziert werden")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseLog>()), 3)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<UserBodyProfile>()), 1,
                       "Profil bleibt Singleton (DEL-191: in-place update)")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<PersonalRecordEntry>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Gear>()), 1)
        XCTAssertGreaterThan(result.totalSkipped, 0)
        // Pläne sind bewusst append-immer (User darf Duplikate haben) —
        // deshalb hier KEIN Plan-Count-Assert.
    }

    func testReplaceImportWipesBeforeRestore() throws {
        // Replace: Store enthält EXTRA-Daten, die nicht im ZIP sind — nach
        // dem Replace-Import müssen sie weg sein.
        let container = try makeContainer()
        try seed(container.mainContext)
        let bundle = try DataExportService.makeExport(context: container.mainContext)

        // Extra-Session NACH dem Export anlegen (simuliert "neue Daten,
        // die das Backup nicht kennt").
        let extra = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_751_000_000),
            endTime: Date(timeIntervalSince1970: 1_751_003_600),
            durationMinutes: 45, isCompleted: true
        )
        container.mainContext.insert(extra)
        try container.mainContext.save()
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 2)

        _ = try DataImportService.performImport(
            zipData: bundle.data,
            context: container.mainContext,
            strategy: .replace
        )
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 1,
            "Replace muss die Extra-Session entfernen und exakt den ZIP-Stand herstellen"
        )
    }

    func testGarbageZipThrowsWithoutWiping() throws {
        // DEL-183-Regression: ein kaputtes ZIP darf bei Replace NIEMALS
        // erst wipen und dann scheitern.
        let container = try makeContainer()
        try seed(container.mainContext)
        let garbage = Data("definitiv kein zip".utf8)

        XCTAssertThrowsError(try DataImportService.performImport(
            zipData: garbage,
            context: container.mainContext,
            strategy: .replace
        ))
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 1,
            "Bestand muss nach abgelehntem ZIP unangetastet sein — Validate-first!"
        )
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<UserBodyProfile>()), 1)
    }
}
#endif
