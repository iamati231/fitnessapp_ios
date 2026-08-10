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

    // MARK: - DEL-225

    /// Zwei Serien DERSELBEN Uebung in EINER Session — schwerer Hauptsatz
    /// frueh, Back-off-Saetze spaeter. Nichts in der App verhindert das, und
    /// beide Serien beginnen bei set_index 0.
    ///
    /// Vor DEL-225 bestand der Dedup-Schluessel aus (session.startTime,
    /// set_index, name_snapshot) — fuer beide Serien identisch. Die komplette
    /// zweite Serie wurde beim Import still als Duplikat verworfen.
    func testSecondSeriesOfSameExerciseSurvivesImport() throws {
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
        _ = try DataImportService.performImport(
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
    func testDoubleImportDoesNotDuplicateLogs() throws {
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)
        let logCount = try source.mainContext.fetchCount(FetchDescriptor<ExerciseLog>())

        let target = try makeContainer()
        for _ in 0..<2 {
            _ = try DataImportService.performImport(
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
    func testAppendImportDoesNotHijackActivePlan() throws {
        let source = try makeContainer()
        try seed(source.mainContext)   // enthaelt einen aktiven "Roundtrip-Plan"
        let bundle = try DataExportService.makeExport(context: source.mainContext)

        // Ziel hat schon einen eigenen aktiven Plan.
        let target = try makeContainer()
        let mine = TrainingPlan(name: "Mein laufender Plan", programType: "custom", isActive: true)
        target.mainContext.insert(mine)
        try target.mainContext.save()

        _ = try DataImportService.performImport(
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
    func testSwappedFromOriginalSurvivesRoundtrip() throws {
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
        _ = try DataImportService.performImport(
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
    func testTimedFormatDayAndSessionSurviveRoundtrip() throws {
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
        _ = try DataImportService.performImport(
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

    /// Bugfix (Nutzer-Feedback, Auf-Zeit-Resume): `forTimeCheckedRoundsRaw`
    /// nutzt bewusst den Platzhalter "-" statt eines leeren Strings fuer
    /// "gestartet, noch nichts abgehakt" - ein echter leerer String wuerde
    /// `CSVRow.optionalString` beim Import wieder zu `nil` normalisieren
    /// (siehe deren Doc-Kommentar) und damit "bereits gestartet" faelschlich
    /// zu "Vorlauf nie durchlaufen" machen. Deckt alle drei moeglichen
    /// Zustaende in einem Export/Import-Durchlauf ab: nie gestartet (nil),
    /// gestartet ohne Fortschritt ("-"), gestartet mit Fortschritt (echte
    /// Daten) - keiner darf durch den Roundtrip in einen anderen kippen.
    func testForTimeCheckedRoundsRawSurvivesRoundtripIncludingPlaceholder() throws {
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
        _ = try DataImportService.performImport(
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
    func testNormalDayStaysNilTimeFormatAfterRoundtrip() throws {
        let source = try makeContainer()
        try seed(source.mainContext)
        let bundle = try DataExportService.makeExport(context: source.mainContext)

        let target = try makeContainer()
        _ = try DataImportService.performImport(
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
    func testPreviewReportsContentWithoutTouchingData() throws {
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
    func testPreviewRejectsGarbage() throws {
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
    func testEmptyDashboardWidgetsAndHeroSlotsSurviveRoundtrip() throws {
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
        _ = try DataImportService.performImport(
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
    func testCardioProfileFieldsSurviveRoundtrip() throws {
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
        _ = try DataImportService.performImport(
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
    func testCardioProfileDefaultsSurviveRoundtrip() throws {
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
        _ = try DataImportService.performImport(
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
    func testCardioFeasibilityDismissedFingerprintSurvivesRoundtrip() throws {
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
        _ = try DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertEqual(imported?.cardioFeasibilityDismissedFingerprint, "marathon#1800000000#22.4")
    }

    func testCardioFeasibilityDismissedFingerprintDefaultsToNilOnRoundtrip() throws {
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
        _ = try DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<UserBodyProfile>()).first
        XCTAssertNil(imported?.cardioFeasibilityDismissedFingerprint)
    }

    // Handoff "Lauf-Coaching - Machbarkeits-Check": generationSource muss
    // ein Backup/Restore ueberleben, sonst haelt die "bereits angenommen"-
    // Erkennung (bzw. hier: die zugrundeliegende Herkunfts-Markierung) einen
    // Restore nicht durch.
    func testGenerationSourceSurvivesRoundtrip() throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Cardio-Coach-Plan", programType: "custom", isActive: false)
        plan.generationSource = .cardioCoach
        ctx.insert(plan)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertEqual(imported?.generationSource, .cardioCoach)
    }

    func testGenerationSourceDefaultsToManualOnRoundtrip() throws {
        let source = try makeContainer()
        let ctx = source.mainContext

        let plan = TrainingPlan(name: "Handangelegter Plan", programType: "custom", isActive: false)
        ctx.insert(plan)
        try ctx.save()

        let bundle = try DataExportService.makeExport(context: ctx)
        let target = try makeContainer()
        _ = try DataImportService.performImport(
            zipData: bundle.data,
            context: target.mainContext,
            strategy: .appendOnly
        )

        let imported = try target.mainContext.fetch(FetchDescriptor<TrainingPlan>()).first
        XCTAssertEqual(imported?.generationSource, .manual)
    }
}
#endif
