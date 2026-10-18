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

    func testExportImportRoundtripRestoresAllRows() async throws {
        // 1) Quelle befüllen + exportieren.
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)
        XCTAssertGreaterThan(bundle.data.count, 500, "ZIP darf nicht leer sein")

        // 2) In einen FRISCHEN Container importieren (Append auf leer =
        //    Neues-Gerät-Szenario).
        let target = try makeContainer()
        let result = try await DataImportService.performImport(
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

    func testReimportIntoSameStoreSkipsDuplicates() async throws {
        // Append-Import in den GLEICHEN Store: alles Duplikat, nichts doppelt.
        let container = try makeContainer()
        try seed(container.mainContext)
        let bundle = try DataExportService.makeExport(context: container.mainContext)

        let result = try await DataImportService.performImport(
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

    func testReplaceImportWipesBeforeRestore() async throws {
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

        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: container.mainContext,
            strategy: .replace
        )
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 1,
            "Replace muss die Extra-Session entfernen und exakt den ZIP-Stand herstellen"
        )
    }

    func testGarbageZipThrowsWithoutWiping() async throws {
        // DEL-183-Regression: ein kaputtes ZIP darf bei Replace NIEMALS
        // erst wipen und dann scheitern.
        let container = try makeContainer()
        try seed(container.mainContext)
        let garbage = Data("definitiv kein zip".utf8)

        // `performImport` ist jetzt `async` — `XCTAssertThrowsError`s
        // Autoclosure-Parameter ist das nicht, deshalb manuelles do/catch
        // statt der sonst ueblichen Einzeiler-Assertion.
        do {
            _ = try await DataImportService.performImport(
                zipData: garbage,
                context: container.mainContext,
                strategy: .replace
            )
            XCTFail("Erwartete einen Fehler fuer ein ungueltiges ZIP")
        } catch {
            // erwartet
        }
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 1,
            "Bestand muss nach abgelehntem ZIP unangetastet sein — Validate-first!"
        )
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<UserBodyProfile>()), 1)
    }

    // MARK: - DEL-225

    /// Zwei Serien DERSELBEN Uebung in EINER Session — schwerer Hauptsatz
    /// frueh, Back-off-Saetze spaeter. Nichts in der App verhindert das, und
    /// beide Serien beginnen bei set_index 0.
    ///
    /// Vor DEL-225 bestand der Dedup-Schluessel aus (session.startTime,
    /// set_index, name_snapshot) — fuer beide Serien identisch. Die komplette
    /// zweite Serie wurde beim Import still als Duplikat verworfen.
    func testSecondSeriesOfSameExerciseSurvivesImport() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Zwei-Serien", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .push, plan: plan)
        ctx.insert(day)
        let session = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_000_000),
            endTime: Date(timeIntervalSince1970: 1_760_005_400),
            durationMinutes: 90, isCompleted: true, day: day
        )
        ctx.insert(session)

        // Zwei separate Exercise-Rows mit demselben Namen — genau so entsteht
        // der Fall im Tages-Editor bzw. im aktiven Workout.
        for (offset, weight) in [(0, 100.0), (2_400, 70.0)] {
            let exercise = Exercise(name: "Bankdrücken", sets: 3, day: day)
            ctx.insert(exercise)
            for setIndex in 0..<3 {
                let log = ExerciseLog(
                    date: session.startTime.addingTimeInterval(Double(offset + setIndex * 120)),
                    setIndex: setIndex,
                    weight: weight, reps: weight == 100 ? 5 : 12, rir: 2,
                    exercise: exercise, session: session
                )
                log.exerciseNameSnapshot = "Bankdrücken"
                ctx.insert(log)
            }
        }
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseLog>()), 6)

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        XCTAssertEqual(
            try target.mainContext.fetchCount(FetchDescriptor<ExerciseLog>()), 6,
            "beide Serien muessen ankommen — vorher wurden 3 Saetze still verworfen"
        )
    }

    /// Derselbe Import zweimal darf nichts verdoppeln. Das ist die Invariante,
    /// die der neue Dedup-Schluessel (mit Log-Zeitstempel) halten muss —
    /// ein Schluessel ueber die Uebungs-Identitaet haette hier verdoppelt,
    /// weil `importPlanExercises` kein Dedup hat und beim zweiten Lauf neue
    /// Exercise-Rows anlegt.
    func testDoubleImportDoesNotDuplicateLogs() async throws {
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)
        let logCount = try source.mainContext.fetchCount(FetchDescriptor<ExerciseLog>())

        let target = try makeContainer()
        for _ in 0..<2 {
            _ = try await DataImportService.performImport(
                zipData: bundle.data,
                context: target.mainContext,
                strategy: .appendOnly
            )
        }

        XCTAssertEqual(
            try target.mainContext.fetchCount(FetchDescriptor<ExerciseLog>()), logCount,
            "zweiter Import derselben ZIP darf keine Logs verdoppeln"
        )
    }

    /// Ein ergaenzender Import darf den LAUFENDEN Plan des Users nicht
    /// umschalten. Vorher deaktivierte jedes Backup mit aktivem Plan
    /// bedingungslos alle bestehenden aktiven Plaene.
    func testAppendImportDoesNotHijackActivePlan() async throws {
        let source = try makeContainer()
        try seed(source.mainContext)   // enthaelt einen aktiven "Roundtrip-Plan"
        let bundle = try DataExportService.makeExport(context: source.mainContext)

        // Ziel hat schon einen eigenen aktiven Plan.
        let target = try makeContainer()
        let mine = TrainingPlan(name: "Mein laufender Plan", programType: "custom", isActive: true)
        target.mainContext.insert(mine)
        try target.mainContext.save()

        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        XCTAssertTrue(mine.isActive, "der eigene Plan muss aktiv bleiben")
        let active = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>())
            .filter(\.isActive)
        XCTAssertEqual(active.count, 1, "es darf genau EIN aktiver Plan existieren")
        XCTAssertEqual(active.first?.name, "Mein laufender Plan")
    }

    /// Die Swap-Referenz (DEL-091 Urlaubs-Modus) muss den Roundtrip
    /// ueberleben — sonst ist der Tausch nach einem Restore nicht mehr
    /// zuruecknehmbar.
    func testSwappedFromOriginalSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let plan = TrainingPlan(name: "Swap-Plan", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Push", weekday: 2, type: .push, plan: plan)
        ctx.insert(day)
        let original = Exercise(name: "Bankdrücken", sets: 3, day: day)
        ctx.insert(original)
        let replacement = Exercise(name: "Liegestütze", sets: 3, day: day)
        replacement.swappedFromOriginal = original
        ctx.insert(replacement)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<Exercise>())
        let swapped = imported.first { $0.name == "Liegestütze" }
        XCTAssertNotNil(swapped?.swappedFromOriginal, "Swap-Referenz fehlt nach dem Import")
        XCTAssertEqual(swapped?.swappedFromOriginal?.name, "Bankdrücken")
    }

    // MARK: - Bugfix (Audit): Zeitformat + Generator-Metadaten im Roundtrip

    /// Vor diesem Fix hatten `buildDays`/`buildWorkouts`/`buildPlans` keine
    /// Spalten fuer `timeFormat`/`timeCapMinutes` (Tag), die sieben
    /// Zeitformat-Ergebnisfelder (Session) oder `generatorInputRaw` (Plan) -
    /// jeder Export/Import-Roundtrip (Backups eingeschlossen) verwandelte
    /// einen AMRAP-Tag stillschweigend in einen normalen Satz/Wiederholungs-
    /// Tag, loeschte das WOD-Ergebnis komplett und deaktivierte "neu rechnen"
    /// fuer Wizard-generierte Plaene fuer immer.
    ///
    /// Bugfix (Audit, Nachtrag): dieser Test behauptete "Generator-Metadaten"
    /// im Namen/Kommentar abzudecken, pruefte aber nur `generatorInputRaw`
    /// (Plan-Ebene) - `TrainingDay.generationFingerprint`/
    /// `.generatorSequenceIndex` fehlten in `buildDays`/`importPlanDays`
    /// KOMPLETT und wurden von keinem Test erfasst. Genau die Luecke, vor
    /// der der urspruengliche Fix eigentlich schuetzen sollte: nach jedem
    /// Restore ueberspringt `PlanGeneratorInstantiator.recalculate` (siehe
    /// dort: `guard let sequenceIndex = day.generatorSequenceIndex ... else
    /// { continue }`) jeden Tag des Plans, "neu rechnen" tut fortan nichts
    /// mehr - ohne Fehler, ohne Hinweis.
    func testTimedFormatDayAndSessionSurviveRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "WOD-Plan", programType: "custom", isActive: true)
        plan.generatorInputRaw = #"{"selections":[]}"#
        ctx.insert(plan)
        let day = TrainingDay(
            name: "Cindy", weekday: 2, type: .fullBody, plan: plan,
            timeFormat: .amrap, timeCapMinutes: 20,
            generationFingerprint: "fingerprint-cindy-v1",
            generatorSequenceIndex: 1
        )
        ctx.insert(day)
        let session = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_100_000),
            endTime: Date(timeIntervalSince1970: 1_760_101_200),
            durationMinutes: 20, isCompleted: true, dayName: "Cindy", day: day,
            timeFormatSnapshot: .amrap,
            roundsCompleted: 15,
            partialReps: 7,
            partialRepsExerciseName: "Kniebeugen",
            completedTarget: true
        )
        ctx.insert(session)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let importedDay = try target.mainContext.fetch(FetchDescriptor<TrainingDay>()).first
        XCTAssertEqual(importedDay?.timeFormat, .amrap, "Zeitformat-Tag darf nach dem Roundtrip nicht zu einem normalen Tag werden")
        XCTAssertEqual(importedDay?.timeCapMinutes, 20)
        XCTAssertEqual(importedDay?.generationFingerprint, "fingerprint-cindy-v1",
                       "ohne Fingerprint erkennt \"neu rechnen\" den Tag faelschlich als unveraendert/veraendert")
        XCTAssertEqual(importedDay?.generatorSequenceIndex, 1,
                       "ohne sequenceIndex ueberspringt recalculate() den Tag fuer immer - \"neu rechnen\" wuerde stillschweigend nichts mehr tun")

        let importedSession = try target.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
        XCTAssertEqual(importedSession?.timeFormatSnapshot, .amrap)
        XCTAssertEqual(importedSession?.roundsCompleted, 15)
        XCTAssertEqual(importedSession?.partialReps, 7)
        XCTAssertEqual(importedSession?.partialRepsExerciseName, "Kniebeugen")
        XCTAssertEqual(importedSession?.completedTarget, true)

        let importedPlan = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertEqual(importedPlan?.generatorInputRaw, #"{"selections":[]}"#,
                       "\"neu rechnen\" braucht generatorInputRaw, um nach einem Restore weiter zu funktionieren")
    }

    /// Nutzer-Feedback (13. August, zweite Runde): neues `.circuit`-Zeitformat
    /// - deckt sowohl die drei neuen `TrainingDay`-Felder (`circuitRounds`/
    /// `circuitRestSeconds`/`circuitMode`) als auch die drei neuen
    /// `WorkoutSession`-Resume-Felder ab (`circuitRoundsCompleted`,
    /// `circuitRestEndDate` als optionales Datum, `circuitCurrentRoundCheckedRaw`
    /// als Snapshot einer laufenden Pause mitten in einer Session) - gleiches
    /// Prinzip wie `testTimedFormatDayAndSessionSurviveRoundtrip` fuer AMRAP.
    func testCircuitDayAndSessionSurviveRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Zirkel-Plan", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(
            name: "Ganzkörper-Komplex", weekday: 2, type: .fullBody, plan: plan,
            timeFormat: .circuit,
            circuitRounds: 5, circuitRestSeconds: 90, circuitMode: .fixedReps
        )
        ctx.insert(day)
        let restEnd = Date(timeIntervalSince1970: 1_760_500_090)
        let session = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_500_000),
            endTime: Date(timeIntervalSince1970: 1_760_500_090),
            isCompleted: false, dayName: "Ganzkörper-Komplex", day: day,
            timeFormatSnapshot: .circuit,
            circuitRoundsCompleted: 2,
            circuitRestEndDate: restEnd,
            circuitCurrentRoundCheckedRaw: "0,2"
        )
        ctx.insert(session)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let importedDay = try target.mainContext.fetch(FetchDescriptor<TrainingDay>()).first
        XCTAssertEqual(importedDay?.timeFormat, .circuit)
        XCTAssertEqual(importedDay?.circuitRounds, 5)
        XCTAssertEqual(importedDay?.circuitRestSeconds, 90)
        XCTAssertEqual(importedDay?.circuitMode, .fixedReps)

        let importedSession = try target.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
        XCTAssertEqual(importedSession?.timeFormatSnapshot, .circuit)
        XCTAssertEqual(importedSession?.circuitRoundsCompleted, 2)
        XCTAssertEqual(
            importedSession?.circuitRestEndDate.map { $0.timeIntervalSince1970.rounded() },
            restEnd.timeIntervalSince1970.rounded(),
            "circuitRestEndDate muss den laufenden Pausen-Countdown ueberleben, sonst verliert ein Backup/Restore mitten in einer Pause die verbleibende Zeit"
        )
        XCTAssertEqual(importedSession?.circuitCurrentRoundCheckedRaw, "0,2")
    }

    /// HealthKit-Import: `importSourceName`/`healthKitSampleUUID` sind die
    /// einzigen Provenienz-Marker fuer eine automatisch aus Apple Health
    /// importierte Session (z.B. Adidas Running) — ohne Roundtrip-Schutz
    /// wuerde ein Backup/Restore diese Herkunft stillschweigend verlieren,
    /// und die Session saehe danach wie eine nativ erfasste aus.
    func testHealthKitImportProvenanceSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let session = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_500_000),
            endTime: Date(timeIntervalSince1970: 1_760_501_800),
            isCompleted: true, isAdHoc: true,
            importSourceName: "Adidas Running",
            healthKitSampleUUID: "3F2504E0-4F89-11D3-9A0C-0305E82C3301"
        )
        ctx.insert(session)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let importedSession = try target.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
        XCTAssertEqual(importedSession?.importSourceName, "Adidas Running")
        XCTAssertEqual(importedSession?.healthKitSampleUUID, "3F2504E0-4F89-11D3-9A0C-0305E82C3301")
    }

    /// `healthKitExportedAt` ist der lokale "behandelt"-Merker und massgeblich:
    /// Ein markiertes Training wird nie wieder exportiert, auch wenn sein Eintrag
    /// in Health geloescht wird. Er reist bewusst NICHT durch Backup/Restore:
    /// nach einem Restore gleicht der Export wieder mit Health ab (kein Doppel,
    /// solange die eigenen Workouts dort sichtbar sind).
    /// Ein Marker aus einem fremden Backup koennte ausserdem zu einem anderen
    /// Health-Konto gehoeren. Der Test haelt fest, dass die Spalte nicht
    /// versehentlich in workouts.csv landet.
    func testHealthKitExportMarkerIsNotPartOfTheBackup() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let session = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_600_000),
            endTime: Date(timeIntervalSince1970: 1_760_603_000),
            durationMinutes: 50, exerciseCount: 1, totalSets: 3, totalVolumeKg: 900,
            isCompleted: true,
            healthKitExportedAt: Date(timeIntervalSince1970: 1_760_700_000)
        )
        ctx.insert(session)
        try ctx.save()
        XCTAssertNotNil(session.healthKitExportedAt)

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let importedSession = try target.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
        XCTAssertNotNil(importedSession, "die Session selbst muss ankommen")
        XCTAssertNil(importedSession?.healthKitExportedAt)
    }

    /// Bugfix (Nutzer-Feedback, Auf-Zeit-Resume): `forTimeCheckedRoundsRaw`
    /// nutzt bewusst den Platzhalter "-" statt eines leeren Strings fuer
    /// "gestartet, noch nichts abgehakt" - ein echter leerer String wuerde
    /// `CSVRow.optionalString` beim Import wieder zu `nil` normalisieren
    /// (siehe deren Doc-Kommentar) und damit "bereits gestartet" faelschlich
    /// zu "Vorlauf nie durchlaufen" machen. Deckt alle drei moeglichen
    /// Zustaende in einem Export/Import-Durchlauf ab: nie gestartet (nil),
    /// gestartet ohne Fortschritt ("-"), gestartet mit Fortschritt (echte
    /// Daten) - keiner darf durch den Roundtrip in einen anderen kippen.
    func testForTimeCheckedRoundsRawSurvivesRoundtripIncludingPlaceholder() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "WOD-Plan", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(
            name: "Auf Zeit Tag", weekday: 2, type: .fullBody, plan: plan,
            timeFormat: .forTime, timeCapMinutes: 20
        )
        ctx.insert(day)

        let startedButUnchecked = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_200_000),
            endTime: Date(timeIntervalSince1970: 1_760_200_600),
            isCompleted: false, dayName: "Auf Zeit Tag", day: day,
            timeFormatSnapshot: .forTime,
            forTimeCheckedRoundsRaw: "-"
        )
        ctx.insert(startedButUnchecked)

        let inProgress = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_300_000),
            endTime: Date(timeIntervalSince1970: 1_760_300_600),
            isCompleted: false, dayName: "Auf Zeit Tag", day: day,
            timeFormatSnapshot: .forTime,
            forTimeCheckedRoundsRaw: "0=2,1=1"
        )
        ctx.insert(inProgress)

        let neverStarted = WorkoutSession(
            startTime: Date(timeIntervalSince1970: 1_760_400_000),
            endTime: Date(timeIntervalSince1970: 1_760_400_600),
            isCompleted: false, dayName: "Auf Zeit Tag", day: day,
            timeFormatSnapshot: .forTime
        )
        ctx.insert(neverStarted)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(
            FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startTime, order: .forward)])
        )
        XCTAssertEqual(imported.count, 3)
        XCTAssertEqual(imported[0].forTimeCheckedRoundsRaw, "-",
                       "Platzhalter fuer \"gestartet, 0 abgehakt\" darf nicht zu nil normalisiert werden")
        XCTAssertEqual(imported[1].forTimeCheckedRoundsRaw, "0=2,1=1")
        XCTAssertNil(imported[2].forTimeCheckedRoundsRaw, "nie gestartet muss nil bleiben")
    }

    /// Ein normaler Satz/Wiederholungs-Tag (kein Zeitformat) darf durch die
    /// neuen additiven Spalten nicht ploetzlich ein Zeitformat annehmen -
    /// leere Zelle muss zuverlaessig als nil ankommen, nicht als "amrap"
    /// o.ae. missinterpretiert werden.
    func testNormalDayStaysNilTimeFormatAfterRoundtrip() async throws {
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)

        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )

        let importedDay = try target.mainContext.fetch(FetchDescriptor<TrainingDay>()).first
        XCTAssertNil(importedDay?.timeFormat)
        XCTAssertNil(importedDay?.timeCapMinutes)
        let importedSession = try target.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
        XCTAssertNil(importedSession?.timeFormatSnapshot)
        XCTAssertNil(importedSession?.roundsCompleted)
    }

    // MARK: - DEL-226 Trockenlauf

    /// Die Vorschau muss den Inhalt korrekt melden und dabei NICHTS schreiben.
    func testPreviewReportsContentWithoutTouchingData() async throws {
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)

        // Ziel mit eigenem Bestand — der muss die Vorschau unveraendert
        // ueberleben.
        let target = try makeContainer()
        try seed(target.mainContext)
        let sessionsBefore = try target.mainContext.fetchCount(FetchDescriptor<WorkoutSession>())
        let logsBefore = try target.mainContext.fetchCount(FetchDescriptor<ExerciseLog>())

        let preview = try DataImportService.preview(zipData: bundle.data)

        XCTAssertEqual(preview.formatVersion, DataExportService.formatVersion)
        XCTAssertGreaterThan(preview.totalRows, 0)
        XCTAssertTrue(preview.containsActivePlan, "der Seed enthaelt einen aktiven Plan")
        XCTAssertEqual(preview.rowCountsByFile["workouts.csv"], 1)
        // 2 Logs der Session + 1 Orphan-Log aus dem Seed.
        XCTAssertEqual(preview.rowCountsByFile["workout_sets.csv"], 3)
        XCTAssertFalse(preview.nonEmptyFiles.isEmpty)

        XCTAssertEqual(
            try target.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), sessionsBefore,
            "die Vorschau darf keine Sessions anlegen oder loeschen"
        )
        XCTAssertEqual(
            try target.mainContext.fetchCount(FetchDescriptor<ExerciseLog>()), logsBefore,
            "die Vorschau darf keine Logs anlegen oder loeschen"
        )
    }

    /// Ein kaputtes ZIP muss in der Vorschau scheitern — dort ist der Abbruch
    /// harmlos, weil noch nichts angefasst wurde.
    func testPreviewRejectsGarbage() async throws {
        XCTAssertThrowsError(
            try DataImportService.preview(zipData: Data("kein zip".utf8))
        )
    }

    // MARK: - Bugfix (Audit): "alles ausblenden" im Roundtrip

    /// `activeDashboardWidgetsRaw`/`heroMetricSlotsRaw` sind beide leer ein
    /// gueltiger, bewusst vom User gewaehlter Zustand (siehe
    /// `DashboardSettingsView` - dort laesst sich jedes Widget/jeder
    /// Hero-Slot einzeln bis auf null abwaehlen). `importProfile` konnte
    /// "Spalte existiert, Wert ist bewusst leer" bisher nicht von "alter
    /// Export kannte die Spalte noch nicht" unterscheiden (`row["..."]`
    /// liefert fuer beide `""`) und ueberschrieb eine bewusst geleerte Liste
    /// nach jedem Restore stillschweigend mit dem nicht-leeren
    /// Konstruktor-Default.
    func testEmptyDashboardWidgetsAndHeroSlotsSurviveRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.activeDashboardWidgetsRaw = []
        profile.heroMetricSlotsRaw = []
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.activeDashboardWidgetsRaw, [],
                       "bewusst leere Dashboard-Widget-Liste darf nach dem Restore nicht auf den Default zurueckspringen")
        XCTAssertEqual(imported?.heroMetricSlotsRaw, [],
                       "bewusst leere Hero-Metric-Liste darf nach dem Restore nicht auf den Default zurueckspringen")
    }

    /// DEL-250: alle sechs neuen Cardio-Profil-Felder muessen den Export/
    /// Import-Roundtrip ueberleben — inklusive `cardioRaceDate` (ein echtes
    /// `Date?`, nicht nur ein String-Feld wie `cardioGoalRaw`).
    func testCardioProfileFieldsSurviveRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.cardioCoachingEnabled = true
        profile.cardioGoal = .halfMarathon
        profile.cardioRaceDate = Date(timeIntervalSince1970: 1_800_000_000)
        profile.current5kReferenceSeconds = 1_500
        profile.weeklyBaseVolumeKm = 25.5
        profile.maxHeartRateBpm = 188
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try XCTUnwrap(try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first)
        XCTAssertEqual(imported.cardioCoachingEnabled, true)
        XCTAssertEqual(imported.cardioGoal, .halfMarathon)
        let restoredRaceDate = try XCTUnwrap(imported.cardioRaceDate)
        XCTAssertEqual(restoredRaceDate.timeIntervalSince1970, 1_800_000_000, accuracy: 1.0)
        XCTAssertEqual(imported.current5kReferenceSeconds, 1_500)
        let restoredWeeklyVolumeKm = try XCTUnwrap(imported.weeklyBaseVolumeKm)
        XCTAssertEqual(restoredWeeklyVolumeKm, 25.5, accuracy: 0.01)
        XCTAssertEqual(imported.maxHeartRateBpm, 188)
    }

    /// DEL-250: ein Profil OHNE Cardio-Ziele (Default-Zustand, z.B.
    /// Bestandsnutzer nach einem Update) darf beim Roundtrip nicht
    /// versehentlich Werte "erfinden" — alle sechs Felder bleiben auf
    /// ihrem Default/nil.
    func testCardioProfileDefaultsSurviveRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.cardioCoachingEnabled, false)
        XCTAssertEqual(imported?.cardioGoal, .generalFitness)
        XCTAssertNil(imported?.cardioRaceDate)
        XCTAssertNil(imported?.current5kReferenceSeconds)
        XCTAssertNil(imported?.weeklyBaseVolumeKm)
        XCTAssertNil(imported?.maxHeartRateBpm)
    }

    // Handoff "Lauf-Coaching - Machbarkeits-Check": der Fingerprint muss
    // ein Backup/Restore ueberleben, sonst zeigt die Karte nach einem
    // Restore erneut einen bereits verworfenen/angenommenen Vorschlag.
    func testCardioFeasibilityDismissedFingerprintSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.cardioFeasibilityDismissedFingerprint = "marathon#1800000000#22.4"
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.cardioFeasibilityDismissedFingerprint, "marathon#1800000000#22.4")
    }

    func testCardioFeasibilityDismissedFingerprintDefaultsToNilOnRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertNil(imported?.cardioFeasibilityDismissedFingerprint)
    }

    // Smart-Onboarding-Epic: `experience_track` ist eine additive CSV-Spalte
    // (ans Ende des Headers angehaengt) — ein gesetzter Wert muss Backup/
    // Restore ueberleben, sonst verliert ein Nutzer seine abgeleitete oder
    // im Onboarding gewaehlte Einstufung bei jedem Restore.
    func testExperienceTrackSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.experienceTrack = .returner
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.experienceTrack, .returner)
    }

    /// Ohne gesetzten Track (z.B. frisch angelegtes Profil, Backfill lief
    /// noch nicht) bleibt die Spalte leer und bleibt `nil` — ein Restore darf
    /// nicht versehentlich `.experienced` oder sonst einen Wert erfinden.
    func testExperienceTrackDefaultsToNilOnRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertNil(imported?.experienceTrack)
    }

    // MARK: - Smart-Onboarding-Epic Phase 2: equipmentProfile (dreiwertige Equipment-Erfassung)

    func testEquipmentProfileSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.equipmentProfile = UserEquipmentProfile(
            availability: [.kettlebell: .available, .adjustableBench: .unavailable, .pullUpBar: .available],
            counts: [.kettlebell: 1]
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .kettlebell), .available)
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .adjustableBench), .unavailable)
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .pullUpBar), .available)
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .barbell), .unknown)
        XCTAssertEqual(imported?.equipmentProfile.count(for: .kettlebell), 1)
    }

    /// Korrektur V5: eine explizite "Weiß ich nicht"-Aussage (Bank/
    /// Klimmzugstange im `EquipmentProfileEditor`) muss den vollen CSV-
    /// Export/Import-Rundlauf ueberleben — nicht nur den reinen In-Memory-
    /// Setter/Getter von `UserBodyProfileTests`. Vor dem Fix gab es dafuer
    /// gar keine eigene CSV-Spalte: `.unknown` landete in keiner der beiden
    /// bestehenden Listen und war nach dem Export/Import nicht mehr von
    /// einem nie angefassten Item unterscheidbar.
    func testExplicitlyUnknownEquipmentSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.equipmentProfile = UserEquipmentProfile(
            availability: [.adjustableBench: .unknown, .pullUpBar: .unknown, .kettlebell: .available]
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .adjustableBench), .unknown)
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .pullUpBar), .unknown)
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .kettlebell), .available)

        // Die eigentliche Regression: nach dem Rundlauf muss die explizite
        // "weiß ich nicht"-Aussage auch die anschliessende vollstaendige
        // Bestaetigung ueberleben (siehe `UserBodyProfileTests.
        // testExplicitlyUnknownBenchSurvivesConfirmEquipmentProfileCompleteThroughPersistence`
        // fuer denselben Vertrag ohne den CSV-Rundlauf dazwischen).
        imported?.confirmEquipmentProfileComplete()
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .adjustableBench), .unknown,
                       "Explizit 'weiß ich nicht' darf auch nach Export/Import nicht zu 'nicht vorhanden' kippen")
        XCTAssertEqual(imported?.equipmentProfile.availability(for: .barbell), .unavailable,
                       "Ein wirklich nie angefasstes Item kippt weiterhin wie gewohnt zu unavailable")
    }

    /// Entspricht einem Bestandsprofil von vor dieser Phase: die drei neuen
    /// Spalten fehlen im Export schlicht nicht (sie werden immer mit-
    /// geschrieben), aber ein Profil, das die Felder nie gesetzt hat, muss
    /// nach dem Rundlauf weiterhin ueberall `.unknown` liefern — kein Restore
    /// darf `.unavailable` erfinden.
    func testEquipmentProfileDefaultsToAllUnknownOnRoundtripForUntouchedProfile() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        for item in EquipmentItem.allCases {
            XCTAssertEqual(imported?.equipmentProfile.availability(for: item), .unknown)
        }
    }

    /// Smart-Onboarding-Epic Phase 3: die neue Bestaetigungs-Flag muss den
    /// Rundlauf ueberleben — sonst wuerde ein Restore eine bereits
    /// abgeschlossene Erfassung wieder als "offen" erscheinen lassen.
    func testEquipmentProfileConfirmedCompleteSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        profile.confirmBodyweightOnly()
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.equipmentProfileConfirmedComplete, true)
        XCTAssertEqual(imported?.equipmentPreferences, [.bodyweight])
        for item in EquipmentItem.allCases {
            XCTAssertEqual(imported?.equipmentProfile.availability(for: item), .unavailable)
        }
    }

    // Start-Check-Epic: Core-Pflichttest 2 ("Jede Testvariante kann
    // gespeichert, exportiert und importiert werden") + 8 ("Backward
    // compatibility: bestehender User ohne Baseline bleibt unveraendert").

    /// Ein VOLLSTAENDIGER Check (alle fuenf Bewegungsfamilien + beide
    /// Selbsteinschaetzungs-Fallbacks gesetzt) muss 1:1 ueberleben.
    func testFullBaselineAssessmentSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        let assessment = BaselineAssessment(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: .guidedTest,
            safetyStatus: .clear,
            pushUp: PushUpAssessment(variant: .knees, cleanReps: 8),
            chairSquat: ChairSquatAssessment(cleanReps: 12, durationSeconds: 30),
            pull: PullAssessment(variant: .latPulldown, cleanReps: 10, loadKg: 35.5, rir: 2.5),
            plank: PlankAssessment(seconds: 42),
            cardio: CardioBaseline(answer: .canJogEasy10Min),
            pushSelfAssessment: .canButStrenuous,
            legsSelfAssessment: .easy,
            pullSelfAssessment: .unsureNoCleanRep,
            desiredFirstWeekIntensity: .veryEasy
        )
        profile.baselineAssessment = assessment
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.baselineAssessment, assessment)
    }

    /// Ein TEILWEISE ausgefuellter Check (nur Push-up getestet, Rest nil)
    /// darf beim Restore nichts erfinden.
    func testPartialBaselineAssessmentSurvivesRoundtripWithNilFieldsIntact() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        let assessment = BaselineAssessment(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: .selfAssessment,
            safetyStatus: .flagged,
            pushUp: PushUpAssessment(variant: .standard, cleanReps: 15)
        )
        profile.baselineAssessment = assessment
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.baselineAssessment, assessment)
        XCTAssertNil(imported?.baselineAssessment?.chairSquat)
        XCTAssertNil(imported?.baselineAssessment?.pull)
        XCTAssertNil(imported?.baselineAssessment?.plank)
        XCTAssertNil(imported?.baselineAssessment?.cardio)
    }

    /// Bestandsnutzer OHNE Check (Default-Zustand) bleiben unveraendert —
    /// kein Restore darf versehentlich einen Check erfinden.
    func testNoBaselineAssessmentStaysNilOnRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male, goalWeightKg: 74, environment: .gym
        )
        ctx.insert(profile)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertNil(imported?.baselineAssessment)
    }

    // Handoff "Lauf-Coaching - Machbarkeits-Check": generationSource muss
    // ein Backup/Restore ueberleben, sonst haelt die "bereits angenommen"-
    // Erkennung (bzw. hier: die zugrundeliegende Herkunfts-Markierung) einen
    // Restore nicht durch.
    func testGenerationSourceSurvivesRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Cardio-Coach-Plan", programType: "custom", isActive: false)
        plan.generationSource = .cardioCoach
        ctx.insert(plan)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertEqual(imported?.generationSource, .cardioCoach)
    }

    func testGenerationSourceDefaultsToManualOnRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Handangelegter Plan", programType: "custom", isActive: false)
        ctx.insert(plan)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertEqual(imported?.generationSource, .manual)
    }

    // MARK: - P6.1 (Plan-Versionierung): activatedAt

    func testActivatedAtSurvivesRoundtripForAnActivePlan() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Aktiver Plan", programType: "custom", isActive: true)
        ctx.insert(plan)
        try ctx.save()
        let originalActivatedAt = try XCTUnwrap(plan.activatedAt, "Init muss bei isActive:true automatisch stempeln")

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        let importedActivatedAt = try XCTUnwrap(imported?.activatedAt)
        XCTAssertEqual(importedActivatedAt.timeIntervalSince1970, originalActivatedAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func testActivatedAtDefaultsToNilOnRoundtripForANeverActivatedPlan() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Nie aktivierter Plan", programType: "custom", isActive: false)
        ctx.insert(plan)
        try ctx.save()
        XCTAssertNil(plan.activatedAt)

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertNil(imported?.activatedAt)
    }

    /// Haertet genau den Fund, der beim Entwurf dieses Felds beinahe
    /// passiert waere: DEL-225s `mayActivate`-Regel kann einen laut Backup
    /// aktiven Plan beim Import auf `isActive = false` zuruecksetzen (wenn
    /// das Zielgeraet bereits einen anderen aktiven Plan hat). `activatedAt`
    /// darf davon UNBERUEHRT bleiben — weder auf `nil` noch auf "jetzt"
    /// zurueckfallen, sondern den echten, historischen Wert aus dem Backup
    /// behalten, auch wenn der Plan importiert gerade inaktiv ankommt.
    func testActivatedAtSurvivesEvenWhenImportSuppressesActivationDueToExistingActivePlan() async throws {
        let source = try makeContainer()
        let sourceCtx = source.mainContext
        let historicalPlan = TrainingPlan(name: "Historisch aktiver Plan", programType: "custom", isActive: true)
        sourceCtx.insert(historicalPlan)
        try sourceCtx.save()
        let historicalActivatedAt = try XCTUnwrap(historicalPlan.activatedAt)

        let bundle = try DataExportService.makeExport(context: sourceCtx)

        let target = try makeContainer()
        let targetCtx = target.mainContext
        let alreadyActiveOnTarget = TrainingPlan(name: "Bereits aktiv auf dem Zielgeraet", programType: "custom", isActive: true)
        targetCtx.insert(alreadyActiveOnTarget)
        try targetCtx.save()

        _ = try await DataImportService.performImport(
            zipData: bundle.data,
            context: targetCtx,
            strategy: .appendOnly
        )

        let imported = try targetCtx.fetch(FetchDescriptor<TrainingPlan>())
            .first { $0.name == "Historisch aktiver Plan" }
        XCTAssertEqual(imported?.isActive, false, "mayActivate muss den Import korrekt auf inaktiv setzen")
        let importedActivatedAt = try XCTUnwrap(imported?.activatedAt, "activatedAt darf trotz unterdrueckter Aktivierung nicht verloren gehen")
        XCTAssertEqual(importedActivatedAt.timeIntervalSince1970, historicalActivatedAt.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - P6.3: PeriodicCheckIn (Häufigkeit/Dauer/Beschwerden/Ziel)

    /// Gemischter Fall — manche Fragen beantwortet, manche bewusst
    /// übersprungen. Beweist, dass `nil` (übersprungen) und ein echter Wert
    /// unabhängig voneinander pro Feld überleben, nicht alles-oder-nichts.
    func testPeriodicCheckInPartialAnswersSurviveRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let checkIn = PeriodicCheckIn(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            frequencyFeedback: .asPlanned,
            durationFeedback: nil,
            hadComplaints: true,
            complaintsNote: "Knie zwickt leicht",
            goalStillCurrent: nil
        )
        ctx.insert(checkIn)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )

        let imported = try XCTUnwrap(try target.mainContext.fetch(FetchDescriptor<PeriodicCheckIn>()).first)
        XCTAssertEqual(imported.frequencyFeedback, .asPlanned)
        XCTAssertNil(imported.durationFeedback, "uebersprungene Frage bleibt nil, nicht ein geratener Default")
        XCTAssertEqual(imported.hadComplaints, true)
        XCTAssertEqual(imported.complaintsNote, "Knie zwickt leicht")
        XCTAssertNil(imported.goalStillCurrent)
    }

    /// Regressionsschutz fuer genau die Falle, die beim Bau vermieden werden
    /// musste: `CSVRow.bool(_:)` liest eine leere Spalte als `false` (etab-
    /// liertes Verhalten fuer Bestandsfelder) — fuer die beiden echten
    /// Ja/Nein-Fragen dieses Features waere das eine stille Umdeutung von
    /// "uebersprungen" zu "Nein". Ein komplett uebersprungener Rueckblick
    /// (alle vier Fragen `nil`) muss nach Export+Import weiterhin VIER MAL
    /// `nil` liefern, nie `false`/0.
    func testPeriodicCheckInFullySkippedStaysNilNotFalseAfterRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let checkIn = PeriodicCheckIn(date: Date(timeIntervalSince1970: 1_700_000_000))
        ctx.insert(checkIn)
        try ctx.save()
        XCTAssertNil(checkIn.hadComplaints)
        XCTAssertNil(checkIn.goalStillCurrent)

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )

        let imported = try XCTUnwrap(try target.mainContext.fetch(FetchDescriptor<PeriodicCheckIn>()).first)
        XCTAssertNil(imported.frequencyFeedback)
        XCTAssertNil(imported.durationFeedback)
        XCTAssertNil(imported.hadComplaints, "darf nach dem Roundtrip nicht faelschlich 'false' werden")
        XCTAssertNil(imported.complaintsNote)
        XCTAssertNil(imported.goalStillCurrent, "darf nach dem Roundtrip nicht faelschlich 'false' werden")
    }

    /// Daten-/Exportkompatibilitäts-Checkpoint für das gesamte P6-Paket:
    /// P6.1 (`TrainingPlan.activatedAt`), P6.2 (liest nur, schreibt nichts
    /// Eigenes) und P6.3 (`PeriodicCheckIn`) wurden bisher nur isoliert in
    /// ihren jeweils eigenen Minimal-Fixtures roundtrip-getestet. Dieser Test
    /// exportiert einen aktiven Plan MIT `activatedAt` und einen
    /// `PeriodicCheckIn` GEMEINSAM in einem einzigen Bundle und bestätigt,
    /// dass beide additiven Erweiterungen nebeneinander, ohne gegenseitige
    /// Beeinflussung, denselben Import-Lauf überstehen.
    func testP6CombinedPlanActivationAndPeriodicCheckInCoexistInOneRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let plan = TrainingPlan(name: "P6-Kombi-Plan", programType: "custom", isActive: true)
        ctx.insert(plan)
        let checkIn = PeriodicCheckIn(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            frequencyFeedback: .moreThanPlanned,
            durationFeedback: .justRight,
            hadComplaints: false,
            goalStillCurrent: true
        )
        ctx.insert(checkIn)
        try ctx.save()
        let activatedAt = try XCTUnwrap(plan.activatedAt)

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        let result = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )
        XCTAssertEqual(result.errorRows, 0)

        let importedPlan = try XCTUnwrap(
            try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first { $0.name == "P6-Kombi-Plan" }
        )
        let importedActivatedAt = try XCTUnwrap(importedPlan.activatedAt)
        XCTAssertEqual(importedActivatedAt.timeIntervalSince1970, activatedAt.timeIntervalSince1970, accuracy: 1.0)

        let importedCheckIn = try XCTUnwrap(try target.mainContext.fetch(FetchDescriptor<PeriodicCheckIn>()).first)
        XCTAssertEqual(importedCheckIn.frequencyFeedback, .moreThanPlanned)
        XCTAssertEqual(importedCheckIn.durationFeedback, .justRight)
        XCTAssertEqual(importedCheckIn.hadComplaints, false, "echtes 'Nein' darf nicht mit uebersprungen (nil) verwechselt werden")
        XCTAssertEqual(importedCheckIn.goalStillCurrent, true)
    }

    // MARK: - Settings-Epic Phase 5

    /// Befund-Aufhaenger: "grosse Historie". Beweist, dass der neue Off-Main-
    /// Pfad (`makeExportAsync`, ZIP-Kompression per `Task.detached`) bei
    /// echtem Datenvolumen exakt dieselben Daten liefert wie der bisherige
    /// synchrone Pfad — die Sendable-Snapshot-Aufteilung (Fetch+CSV-Bau
    /// bleibt auf dem Context-Actor, nur die Kompression wandert) darf die
    /// Zeilen nicht verlieren oder verdoppeln.
    func testAsyncExportAtVolumeRoundtripsCompletely() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 700_000_000),
            heightCm: 180, profile: .male, goalWeightKg: 90, environment: .gym
        )
        ctx.insert(profile)
        let plan = TrainingPlan(name: "Volumen-Plan", programType: "custom", isActive: true)
        ctx.insert(plan)
        let day = TrainingDay(name: "Ganzkoerper", weekday: 1, type: .fullBody, plan: plan)
        ctx.insert(day)
        let exercise = Exercise(name: "Kreuzheben", sets: 3, suggestedWeight: 100, day: day)
        ctx.insert(exercise)

        let sessionCount = 250
        for i in 0..<sessionCount {
            let start = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400)
            let session = WorkoutSession(
                startTime: start, endTime: start.addingTimeInterval(3_600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 3,
                totalVolumeKg: 900, isCompleted: true, day: day
            )
            ctx.insert(session)
            for setIndex in 0..<3 {
                ctx.insert(ExerciseLog(
                    date: start, setIndex: setIndex, weight: 100, reps: 5, rir: 2,
                    exercise: exercise, session: session
                ))
            }
        }
        try ctx.save()

        let bundle = try await DataExportService.makeExportAsync(context: ctx)
        XCTAssertEqual(bundle.totalRows, 1 /* profile */ + 1 /* plan */ + 1 /* day */ + 1 /* exercise */ + sessionCount + sessionCount * 3)

        let target = try makeContainer()
        let result = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )
        XCTAssertEqual(result.errorRows, 0)
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), sessionCount)
        XCTAssertEqual(try target.mainContext.fetchCount(FetchDescriptor<ExerciseLog>()), sessionCount * 3)
    }

    /// Befund RS-03a: `UserDataWipe.deleteSharedUserData` darf GENAU die 10
    /// mit dem Replace-Import gemeinsamen Typen loeschen — `ExerciseTemplate`
    /// (System UND Custom) muss unberuehrt bleiben, weil Reset und
    /// Replace-Import dafuer bewusst unterschiedliche, separat behandelte
    /// Umfaenge haben (siehe `SettingsView.resetApp`/
    /// `DataImportService.wipeAllUserData`).
    func testUserDataWipeDeletesOnlyTheSharedScope() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seed(ctx)
        let systemTemplate = ExerciseTemplate(name: "Systemuebung", equipment: .barbell, primaryMuscle: .chest, isCustom: false)
        let customTemplate = ExerciseTemplate(name: "Eigene Uebung", equipment: .dumbbell, primaryMuscle: .chest, isCustom: true)
        ctx.insert(systemTemplate)
        ctx.insert(customTemplate)
        try ctx.save()

        try UserDataWipe.deleteSharedUserData(in: ctx)
        try ctx.save()

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<PersonalRecordEntry>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseLog>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Exercise>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<TrainingDay>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<TrainingPlan>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WaterEntry>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<BodyMeasurement>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Gear>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<UserBodyProfile>()), 0)
        // Der eigentliche Punkt des Tests: beide Templates ueberleben.
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseTemplate>()), 2)
    }

    /// Befund RS-02/"Restore nach Reset": eine VOR einem destruktiven Wipe
    /// erzeugte Sicherung (wie `BackupService.createBackupAsync(reason:
    /// .preReset)` sie vor `SettingsView.resetApp`s Loeschung anlegt) muss
    /// den kompletten Vor-Wipe-Zustand wiederherstellen koennen. Simuliert
    /// den Reset-Loeschumfang direkt (`UserDataWipe` + alle Templates, wie
    /// `resetApp` es tut) statt ueber die UI — die eigentliche
    /// Service-Garantie ("Backup vor Wipe ist vollstaendig restaurierbar")
    /// ist hier vollstaendig pruefbar, die SwiftUI-Orchestrierung selbst
    /// nicht (kein UI-Test-Target in diesem Repo).
    func testRestoreAfterResetLikeWipeRecoversFullState() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        try seed(ctx)

        // 1) "Vorab-Sicherung" — exakt das, was vor einem Reset passieren wuerde.
        let preResetBundle = try DataExportService.makeExport(context: ctx)

        // 2) Reset-Loeschumfang: gemeinsame Typen + ALLE ExerciseTemplates
        //    (anders als der Replace-Import, der nur Custom-Templates wischt —
        //    hier gibt es ohnehin keine, seed() legt keine an).
        try UserDataWipe.deleteSharedUserData(in: ctx)
        try UserDataWipe.deleteEach(of: ExerciseTemplate.self, in: ctx)
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<UserBodyProfile>()), 0, "Wipe muss vorher wirklich leeren")

        // 3) Restore — wie `BackupListView.restore(_:)` es tut.
        let result = try await DataImportService.performImport(
            zipData: preResetBundle.data, context: ctx, strategy: .replace
        )
        XCTAssertEqual(result.errorRows, 0)

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<UserBodyProfile>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<TrainingPlan>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseLog>()), 3, "2 Session-Logs + 1 Orphan-Log, siehe seed()")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<PersonalRecordEntry>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Gear>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<BodyMeasurement>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<WaterEntry>()), 1)
    }

    // MARK: - Settings-Epic Phase 6 (EXLIB-07/09): stabile Exercise-Referenz

    /// Kern-Regression des Audit-Befunds: Umbenennen einer eigenen Übung
    /// darf Verlaufs-Lookup nicht brechen. `exerciseTemplateID` (stabil)
    /// bleibt unveraendert; `exerciseNameSnapshot` (historischer Snapshot)
    /// bleibt bewusst auf dem ALTEN Namen stehen — der Test beweist explizit,
    /// dass ein Lookup rein über den aktuellen Namen die Historie verfehlen
    /// WUERDE, waehrend die ID sie weiterhin findet.
    func testExerciseTemplateIDResolvesHistoryAfterTemplateRename() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let template = ExerciseTemplate(name: "Kabelzug", equipment: .cable, primaryMuscle: .back, isCustom: true)
        ctx.insert(template)
        let exercise = Exercise(name: template.name, exerciseTemplateID: template.id, sets: 3)
        ctx.insert(exercise)
        let log = ExerciseLog(setIndex: 0, weight: 50, reps: 10, rir: 2, exercise: exercise)
        ctx.insert(log)
        try ctx.save()

        XCTAssertEqual(log.resolvedExerciseTemplateID, template.id)
        XCTAssertEqual(log.resolvedExerciseName, "Kabelzug")

        template.name = "Lat-Zug"
        try ctx.save()

        XCTAssertEqual(log.resolvedExerciseTemplateID, template.id, "Umbenennen darf die stabile Referenz nicht brechen")
        XCTAssertEqual(log.resolvedExerciseName, "Kabelzug", "Historischer Namens-Snapshot bleibt erhalten")
        XCTAssertNotEqual(
            log.resolvedExerciseName, template.name,
            "Beweis: ein Lookup NUR ueber den aktuellen Namen wuerde diesen Log nach dem Umbenennen verfehlen — die ID ist die einzig verlässliche Referenz"
        )
    }

    /// Löschen einer (Custom-)Vorlage darf Logs/PRs strukturell niemals
    /// mitlöschen — `exerciseTemplateID` ist ein reiner UUID-Scalar, kein
    /// `@Relationship`, genau damit es keine Delete-Rule gibt, die das
    /// erzwingen könnte.
    func testDeletingTemplateNeverCascadesToExerciseLogsOrPRs() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let template = ExerciseTemplate(name: "Face Pull", equipment: .cable, primaryMuscle: .shoulders, isCustom: true)
        ctx.insert(template)
        let exercise = Exercise(name: template.name, exerciseTemplateID: template.id, sets: 3)
        ctx.insert(exercise)
        let log = ExerciseLog(setIndex: 0, weight: 15, reps: 15, rir: 2, exercise: exercise)
        ctx.insert(log)
        let pr = PersonalRecordEntry(
            date: Date(), exerciseName: template.name, exerciseTemplateID: template.id,
            kindRaw: PersonalRecord.Kind.heaviestWeight.rawValue,
            value: 15, previousValue: 10, weightKg: 15, reps: 15
        )
        ctx.insert(pr)
        try ctx.save()

        // ID VOR dem Loeschen sichern — `template` nach `ctx.delete`+`save`
        // ist ein invalidiertes SwiftData-Objekt; jeder Property-Zugriff
        // danach (auch `template.id`) ist undefiniert/crasht.
        let templateID = template.id
        ctx.delete(template)
        try ctx.save()

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<ExerciseLog>()), 1, "Log darf durch das Vorlagen-Loeschen nicht verschwinden")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<PersonalRecordEntry>()), 1, "PR darf durch das Vorlagen-Loeschen nicht verschwinden")
        // Snapshot-Felder bleiben unveraendert — nur die Live-Vorlage ist weg.
        XCTAssertEqual(log.exerciseTemplateIDSnapshot, templateID)
        XCTAssertEqual(pr.exerciseTemplateID, templateID)
    }

    /// CSV-/Backup-Roundtrip (häufiger Fall): Export + Import in einen
    /// FRISCHEN Container — die stabile `ExerciseTemplate.id` wird 1:1
    /// wiederhergestellt, und `exercise_template_id` auf Exercise/PR löst
    /// nach dem Import korrekt auf die neu angelegte Vorlage auf.
    func testCustomExerciseTemplateIDSurvivesExportImportRoundtrip() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let template = ExerciseTemplate(name: "Meine Uebung", equipment: .dumbbell, primaryMuscle: .chest, isCustom: true)
        ctx.insert(template)
        let exercise = Exercise(name: template.name, exerciseTemplateID: template.id, sets: 3)
        ctx.insert(exercise)
        let log = ExerciseLog(setIndex: 0, weight: 20, reps: 12, rir: 2, exercise: exercise)
        ctx.insert(log)
        let pr = PersonalRecordEntry(
            date: Date(), exerciseName: template.name, exerciseTemplateID: template.id,
            kindRaw: PersonalRecord.Kind.heaviestWeight.rawValue,
            value: 20, previousValue: 15, weightKg: 20, reps: 12
        )
        ctx.insert(pr)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )

        let importedTemplates = try target.mainContext.fetch(FetchDescriptor<ExerciseTemplate>())
        guard let importedTemplate = importedTemplates.first(where: { $0.name == "Meine Uebung" }) else {
            return XCTFail("Custom-Vorlage fehlt nach dem Import")
        }
        XCTAssertEqual(importedTemplate.id, template.id, "Stabile ID muss 1:1 ueberleben (frischer Container, kein Dedup)")

        let importedExercises = try target.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(importedExercises.first?.exerciseTemplateID, importedTemplate.id)

        let importedPRs = try target.mainContext.fetch(FetchDescriptor<PersonalRecordEntry>())
        XCTAssertEqual(importedPRs.first?.exerciseTemplateID, importedTemplate.id)

        let importedLogs = try target.mainContext.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(importedLogs.first?.exerciseTemplateIDSnapshot, importedTemplate.id)
    }

    /// CSV-/Backup-Roundtrip (Dedup-Fall): der Zielcontainer hat bereits eine
    /// gleichnamige Custom-Vorlage MIT EIGENER ID (z.B. ein zweiter Import
    /// derselben ZIP, oder ein Merge zweier Geräte). Der Importer legt dann
    /// KEINE zweite Vorlage an, sondern verknuepft `exercise_template_id`
    /// auf die BEREITS VORHANDENE Vorlage — nicht auf die (jetzt verwaiste)
    /// ID aus der Export-Datei.
    func testCustomExerciseTemplateIDResolvesThroughDedupOnReimport() async throws {
        let source = try makeContainer()
        let ctx = source.mainContext
        let template = ExerciseTemplate(name: "Dedup-Uebung", equipment: .machine, primaryMuscle: .quads, isCustom: true)
        ctx.insert(template)
        let exercise = Exercise(name: template.name, exerciseTemplateID: template.id, sets: 3)
        ctx.insert(exercise)
        try ctx.save()
        let bundle = try DataExportService.makeExport(context: ctx)

        // Zielcontainer hat bereits eine gleichnamige Vorlage mit ANDERER ID.
        let target = try makeContainer()
        let existingTemplate = ExerciseTemplate(name: "Dedup-Uebung", equipment: .machine, primaryMuscle: .quads, isCustom: true)
        target.mainContext.insert(existingTemplate)
        try target.mainContext.save()
        XCTAssertNotEqual(existingTemplate.id, template.id)

        _ = try await DataImportService.performImport(
            zipData: bundle.data, context: target.mainContext, strategy: .appendOnly
        )

        XCTAssertEqual(
            try target.mainContext.fetchCount(FetchDescriptor<ExerciseTemplate>()), 1,
            "Dedup muss greifen — keine zweite gleichnamige Vorlage"
        )
        let importedExercises = try target.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(
            importedExercises.first?.exerciseTemplateID, existingTemplate.id,
            "Referenz muss auf die WIEDERVERWENDETE Vorlage zeigen, nicht auf die verwaiste Export-ID"
        )
    }
}
#endif
