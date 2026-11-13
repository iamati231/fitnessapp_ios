#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import DeltiqCore
import DeltiqData
@testable import DeltiqUI

/// Plan-Editor-Persistenzbug: `PlanEditorView.saveAction` (die "Fertig"-
/// Checkmark) rief bislang NUR `dismiss()` auf — die Typ-Doku nannte
/// `TrainingPlan` faelschlich "autosaved direkt in SwiftData" ueber
/// `@Bindable`. Tatsaechlich mutiert `@Bindable` nur den Live-Objektgraphen
/// im Speicher; die tatsaechliche Persistenz haengt an SwiftDatas implizitem
/// Context-Autosave, der nach einem App-Kaltstart kurz nach der Aenderung
/// nicht zuverlaessig schon gelaufen sein muss — derselbe bereits an anderer
/// Stelle (`DayEditorView`, siehe `DayEditorPersistenceTests`) gefundene und
/// behobene Musterfehler. Der Fix fuegt `saveAndDismiss()` hinzu (explizites
/// `context.save()` VOR `dismiss()`, kein Dismiss bei Fehlschlag).
///
/// `saveAndDismiss()` ist bewusst WEITERHIN `private` und liest
/// `self.modelContext` aus `@Environment` — direktes Aufrufen ueber eine ohne
/// lebenden SwiftUI-/`.modelContainer`-Kontext konstruierte `PlanEditorView`-
/// Instanz wuerde NICHT den in diesem Test aufgesetzten Context treffen
/// (siehe `DayEditorPersistenceTests`-Typ-Dokumentation fuer dieselbe
/// Einschraenkung). Dieser Test beweist deshalb NICHT die Methode selbst,
/// sondern die zugrundeliegende Fix-Technik, die sie jetzt anwendet: ein
/// explizites `context.save()` UNMITTELBAR nach der `@Bindable`-Mutation,
/// OHNE jede weitere UI-Interaktion, uebersteht einen echten Store-Neustart
/// — waehrend dieselbe Mutation OHNE diesen Save (der vorherige Zustand,
/// reines `dismiss()`) das nicht garantiert tut. Die tatsaechliche
/// Verdrahtung in `PlanEditorView.saveAction`/`saveAndDismiss()` bleibt per
/// sorgfaeltiger manueller Durchsicht verifiziert (siehe Kommentare dort)
/// und per Geraete-/TestingBot-Kaltstart noch zu bestaetigen — in dieser
/// Session nicht durchfuehrbar (kein TestingBot-Zugriff, siehe Auftrag),
/// ehrlich offen ausgewiesen.
///
/// Der Save-FEHLSCHLAG-Pfad (catch-Zweig / `showTransientToast`) ist NICHT
/// durch einen automatisierten Test abgedeckt: SwiftData-`ModelContext.save()`
/// laesst sich in diesem Repo an keiner Stelle deterministisch zum
/// Fehlschlagen zwingen (kein Mock-/Fault-Injection-Precedent gefunden,
/// weder hier noch in `DayEditorPersistenceTests`). Dieser Pfad ist
/// ausschliesslich durch Code-Review abgedeckt: `saveAndDismiss()` dismisst
/// im `catch`-Zweig nachweislich NICHT (kein `dismiss()`-Aufruf in diesem
/// Zweig) und ruft stattdessen den bereits an anderer Stelle in dieser View
/// genutzten `showTransientToast`-Helfer auf — exakt dasselbe Muster wie
/// `DayEditorView.saveAndDismiss()`, dessen Fehlerpfad laut dessen Tests
/// ebenfalls nur per Review abgedeckt ist.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanEditorPersistenceTests: XCTestCase {

    /// Reproduziert die Fix-Technik: `@Bindable`-Feldaenderung (wie ein
    /// Wochen-Stepper es am Live-`plan` taete) + SOFORTIGER `context.save()`
    /// (wie jetzt in `saveAndDismiss()`), Container-Ende OHNE jede weitere
    /// Interaktion, dann eine FRISCHE `ModelContainer`-Instanz auf DERSELBEN
    /// Store-Datei — genau die Sequenz, die ein App-Kaltstart kurz nach dem
    /// Tippen auf die Checkmark nachbildet.
    func testPlanFieldChangeWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("plan-editor-save-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Ganzkörper", programType: "custom", weeks: 12, isActive: false, targetEnvironment: .gym)
            context.insert(plan)
            try context.save()

            // Exakt die Sequenz aus `saveAndDismiss()` nach dem Fix: Felder
            // am `@Bindable`-Plan direkt mutieren (wie Wochen-Stepper und
            // Trainingsort-Picker es tun), SOFORT `context.save()` — kein
            // `dismiss()`-Aufruf noetig, der ist fuer die Persistenz selbst
            // irrelevant.
            plan.weeks = 16
            plan.targetEnvironment = .homeGym
            plan.customName = "Mein Plan"
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let plans = try reopened.mainContext.fetch(FetchDescriptor<TrainingPlan>())
        guard let plan = plans.first else {
            return XCTFail("der Plan muss einen echten Store-Neustart ueberstehen")
        }
        XCTAssertEqual(plan.weeks, 16, "die Wochen-Aenderung muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(plan.targetEnvironment, .homeGym)
        XCTAssertEqual(plan.customName, "Mein Plan")
    }

    /// Belegt Punkt 4 des Auftrags: erneutes Speichern nach einem (simulierten)
    /// fehlgeschlagenen ersten Versuch ist sicher, weil `plan` bereits per
    /// `context.insert` in diesem Context verwaltet wird — ein zweiter
    /// `context.save()`-Aufruf auf demselben, in der Zwischenzeit weiter
    /// mutierten Objekt ist ein reines UPDATE, kein erneutes INSERT. Es
    /// entsteht dabei nachweislich kein zweiter Datensatz.
    func testRepeatedSaveOnSameBindableObjectDoesNotDuplicate() throws {
        let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let plan = TrainingPlan(name: "Ganzkörper", programType: "custom", weeks: 12, isActive: false)
        context.insert(plan)
        try context.save()

        // Erster "Tap" auf die Checkmark: Mutation + Save.
        plan.weeks = 14
        try context.save()

        // Zweiter "Tap" (z.B. nach einem zuvor fehlgeschlagenen Save, der
        // laut Fix NICHT dismissed hat): dieselbe Mutation nochmal
        // angewendet + erneuter Save auf demselben, bereits verwalteten
        // Objekt.
        plan.weeks = 14
        try context.save()

        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 1, "wiederholtes Speichern auf demselben @Bindable-Objekt darf keinen zweiten Datensatz anlegen")
        XCTAssertEqual(allPlans.first?.weeks, 14)
    }
}

// MARK: - Issue #12: Custom-Exercise Migration (PlanEnvironmentMigrator)

/// Issue #12: Regressionstests für Custom-Exercise-Behandlung in PlanEnvironmentMigrator.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanEnvironmentMigratorCustomExerciseTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makePlanWithCustomExercise(
        equipment: Equipment?,
        in context: ModelContext
    ) -> (plan: TrainingPlan, exercise: Exercise) {
        let plan = TrainingPlan(name: "Test", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let exercise = Exercise(
            name: "Meine Custom-Übung XYZ-\(UUID().uuidString)",
            orderIndex: 0,
            equipment: equipment,
            day: day
        )
        context.insert(exercise)
        return (plan, exercise)
    }

    func testCustomBodyweightExerciseStaysActiveInNoEquipmentMode() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .bodyweight, in: context)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Bodyweight-Custom-Exercise muss aktiv bleiben")
        XCTAssertFalse(exercise.archivedByEnvironmentChange)
        XCTAssertEqual(result.compatible, 1)
        XCTAssertEqual(result.kept, 0)
    }

    func testCustomBarbellExerciseArchivedInNoEquipmentMode() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertTrue(exercise.isArchived, "Barbell-Custom-Exercise muss archiviert werden")
        XCTAssertTrue(exercise.archivedByEnvironmentChange, "archivedByEnvironmentChange muss gesetzt sein")
        XCTAssertNil(exercise.swappedFromOriginal, "kein swappedFromOriginal-Link für .keep-Pfad")
        XCTAssertEqual(result.kept, 1)
        XCTAssertEqual(result.compatible, 0)
    }

    func testCustomBarbellExerciseRestoredOnReturnToGym() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        try context.save()

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        XCTAssertTrue(exercise.isArchived)
        XCTAssertTrue(exercise.archivedByEnvironmentChange)

        let restoreResult = PlanEnvironmentMigrator.restoreOriginals(plan: plan, toEnvironment: .gym, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Exercise muss nach Restore reaktiviert sein")
        XCTAssertFalse(exercise.archivedByEnvironmentChange, "archivedByEnvironmentChange muss nach Restore gelöscht sein")
        XCTAssertEqual(restoreResult.restored, 1)
    }

    func testCustomExerciseWithNilEquipmentArchivedConservatively() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: nil, in: context)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertTrue(exercise.isArchived, "Custom-Exercise ohne Equipment-Info muss konservativ archiviert werden")
        XCTAssertTrue(exercise.archivedByEnvironmentChange)
        XCTAssertEqual(result.kept, 1)
    }

    func testTrainingHistoryPreservedAfterArchiveAndRestore() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .barbell, in: context)

        let log = ExerciseLog(setIndex: 0, weight: 100.0, reps: 5, rir: 2.0, exercise: exercise)
        context.insert(log)
        try context.save()

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        let logs = try context.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logs.count, 1, "ExerciseLog muss beim Archivieren erhalten bleiben (.nullify delete rule)")
        XCTAssertEqual(logs.first?.exerciseNameSnapshot, exercise.name)

        PlanEnvironmentMigrator.restoreOriginals(plan: plan, toEnvironment: .gym, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Exercise muss nach Restore aktiv sein")
        let logsAfterRestore = try context.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logsAfterRestore.count, 1, "Log muss auch nach Restore erhalten bleiben")
    }

    func testPreviewMigrateShowsCustomBarbellAsArchived() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        plan.targetEnvironment = .gym
        try context.save()

        let previews = PlanEnvironmentMigrator.previewMigrateAll(plans: [plan], toEnvironment: .noEquipment)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews.first?.archived.count, 1, "Barbell-Custom-Exercise muss in preview.archived erscheinen")
        XCTAssertTrue(previews.first?.swaps.isEmpty ?? false)
    }

    func testPreviewRestoreShowsArchivedByEnvChangeAsRestored() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        plan.targetEnvironment = .gym
        try context.save()

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        let previews = PlanEnvironmentMigrator.previewRestoreAll(plans: [plan], toEnvironment: .gym)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews.first?.restored.count, 1, "archivedByEnvironmentChange-Exercise muss in preview.restored erscheinen")
    }

    func testHasAnyRestorableOriginalsTrueForArchivedCustomExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        plan.targetEnvironment = .gym
        try context.save()

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        let hasRestorable = PlanEnvironmentMigrator.hasAnyRestorableOriginals(plans: [plan], forEnvironment: .gym)
        XCTAssertTrue(hasRestorable, "hasAnyRestorableOriginals muss true sein wenn archivedByEnvironmentChange-Exercise vorhanden")
    }

    /// Befund #4 (Audit): Custom-Exercise mit demselben Namen wie eine System-Exercise
    /// muss über exerciseTemplateID.isCustom als Custom erkannt werden, nicht über byName.
    func testCustomExerciseWithCatalogNameIsNotSwappedLikeSystemExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // "Bankdrücken" ist im Systemkatalog (barbell). Wir erstellen eine
        // Custom-Variante mit bodyweight — beim Wechsel zu noEquipment muss sie
        // als Custom (bodyweight → kompatibel) behandelt werden, nicht als
        // System-Exercise (barbell → würde gswappt).
        let customTemplate = ExerciseTemplate(
            name: "Bankdrücken",
            equipment: .bodyweight,
            primaryMuscle: .chest,
            isCustom: true
        )
        context.insert(customTemplate)

        let plan = TrainingPlan(name: "Test", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let exercise = Exercise(
            name: "Bankdrücken",
            orderIndex: 0,
            equipment: .bodyweight,
            day: day
        )
        exercise.exerciseTemplateID = customTemplate.id
        context.insert(exercise)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Custom-Bankdrücken (bodyweight) muss aktiv bleiben — nicht als System-Exercise gswappt werden")
        XCTAssertEqual(result.compatible, 1, "bodyweight ist noEquipment-kompatibel")
        XCTAssertEqual(result.swapped, 0, "Custom-Exercise darf nicht über resolveAlternative gswappt werden")
    }

    func testExerciseWithDeletedTemplateIsNotTreatedAsSystemExercise() throws {
        // Regressions-Test für gelöschtes Template: exerciseTemplateID vorhanden,
        // Template nicht mehr im Store → isSystemExercise muss false zurückgeben,
        // nicht auf byName-Fallback zurückfallen (der die Übung fälschlich als System
        // einordnen würde, wenn der Name im Katalog existiert).
        let container = try makeContainer()
        let context = container.mainContext

        let deletedTemplateID = UUID()

        let plan = TrainingPlan(name: "Test", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        // "Bankdrücken" ist im Systemkatalog (barbell). exerciseTemplateID zeigt
        // auf ein Template, das nicht im Store existiert.
        let exercise = Exercise(
            name: "Bankdrücken",
            orderIndex: 0,
            equipment: .bodyweight,
            day: day
        )
        exercise.exerciseTemplateID = deletedTemplateID
        context.insert(exercise)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertFalse(exercise.isArchived,
            "Übung mit gelöschtem Template (bodyweight) muss aktiv bleiben — defensiv als Custom behandelt, nicht als System via byName")
        XCTAssertEqual(result.compatible, 1)
        XCTAssertEqual(result.swapped, 0)
    }

    // MARK: - Deleted-Template-Tests (previewMigrateAll / previewRestoreAll / hasAnyRestorableOriginals / restoreOriginals)
    // HINWEIS: Tests vorhanden, noch nicht auf aktuellem Commit auf macbox ausgeführt (macbox-Sync-Bug).
    // Diese Suite ist das Merge-Gate für Issue #12, sobald macbox synchronisiert.

    /// Helper: Template einfügen, exerciseTemplateID setzen, Template danach löschen + speichern.
    /// Simuliert eine gelöschte Custom-Vorlage bei weiterbestehendem Plan-Exercise.
    private func makePlanWithDeletedTemplate(
        exerciseEquipment: Equipment?,
        exerciseName: String = "Bankdrücken",
        in context: ModelContext
    ) throws -> (plan: TrainingPlan, exercise: Exercise) {
        let template = ExerciseTemplate(name: exerciseName, equipment: .bodyweight, primaryMuscle: .chest, isCustom: true)
        context.insert(template)
        let deletedID = template.id
        let plan = TrainingPlan(name: "Test", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let exercise = Exercise(name: exerciseName, orderIndex: 0, equipment: exerciseEquipment, day: day)
        exercise.exerciseTemplateID = deletedID
        context.insert(exercise)
        try context.save()
        context.delete(template)
        try context.save()
        // Vorbedingungen nach dem Löschen absichern.
        let gone = try context.fetch(FetchDescriptor<ExerciseTemplate>(predicate: #Predicate { t in t.id == deletedID }))
        XCTAssertTrue(gone.isEmpty, "Template muss nach delete nicht mehr fetchbar sein")
        XCTAssertFalse(exercise.isArchived, "Exercise muss nach Setup noch aktiv sein")
        XCTAssertEqual(exercise.exerciseTemplateID, deletedID, "exerciseTemplateID muss die gelöschte ID behalten")
        return (plan, exercise)
    }

    func testPreviewMigrateAllBodyweightDeletedTemplateProducesNoSwapNoArchived() throws {
        // "Bankdrücken" ist Katalogname (barbell im System), aber Template gelöscht + bodyweight →
        // isSystemExercise = false → Custom-Pfad → bodyweight kompatibel mit noEquipment → nichts archiviert.
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = try makePlanWithDeletedTemplate(exerciseEquipment: .bodyweight, in: context)

        let previews = PlanEnvironmentMigrator.previewMigrateAll(plans: [plan], toEnvironment: .noEquipment)

        XCTAssertTrue(previews.isEmpty,
            "bodyweight + gelöschtes Template → kein Swap, kein Archived → leere Preview (kein Plan-Eintrag)")
    }

    func testPreviewMigrateAllBarbellDeletedTemplateAppearsInArchived() throws {
        // Gleiche Namenskollision, aber barbell → Custom-Pfad → inkompatibel → archived.
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = try makePlanWithDeletedTemplate(exerciseEquipment: .barbell, in: context)

        let previews = PlanEnvironmentMigrator.previewMigrateAll(plans: [plan], toEnvironment: .noEquipment)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews.first?.archived.count, 1,
            "barbell + gelöschtes Template → isSystemExercise=false → Custom-Pfad → archived")
        XCTAssertTrue(previews.first?.swaps.isEmpty ?? false,
            "kein Swap — Custom-Exercises haben keine Alternativ-Mappings im System")
    }

    func testPreviewRestoreAllDeletedTemplateAppearsInRestored() throws {
        // Migrate archiviert Barbell-Custom-Exercise mit archivedByEnvironmentChange=true.
        // Template wird danach gelöscht. previewRestoreAll(.gym) muss archived[] trotzdem
        // im restored-Feld zeigen (isArchivedExerciseCompatible → Custom-Pfad → barbell+gym → true).
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = try makePlanWithDeletedTemplate(exerciseEquipment: .barbell, in: context)

        // Migrate archiviert die Exercise; Template ist zu diesem Zeitpunkt schon gelöscht.
        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        XCTAssertTrue(exercise.archivedByEnvironmentChange, "Precondition: Exercise muss archiviert sein")
        try context.save()

        let previews = PlanEnvironmentMigrator.previewRestoreAll(plans: [plan], toEnvironment: .gym)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews.first?.restored.count, 1,
            "gelöschtes Template + barbell + gym → isArchivedExerciseCompatible=true → restored")
    }

    func testRestoreOriginalsDeletedTemplateReactivatesExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = try makePlanWithDeletedTemplate(exerciseEquipment: .barbell, in: context)

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()
        XCTAssertTrue(exercise.isArchived, "Precondition: archiviert")

        let result = PlanEnvironmentMigrator.restoreOriginals(plan: plan, toEnvironment: .gym, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Exercise mit gelöschtem Template muss nach Restore reaktiviert sein")
        XCTAssertFalse(exercise.archivedByEnvironmentChange, "archivedByEnvironmentChange muss nach Restore gelöscht sein")
        XCTAssertEqual(result.restored, 1)
    }

    func testHasAnyRestorableOriginalsReturnsTrueForDeletedTemplateBarbellInGym() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = try makePlanWithDeletedTemplate(exerciseEquipment: .barbell, in: context)

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        XCTAssertTrue(
            PlanEnvironmentMigrator.hasAnyRestorableOriginals(plans: [plan], forEnvironment: .gym),
            "hasAnyRestorableOriginals muss true sein wenn archivedByEnvironmentChange-Exercise mit barbell im Gym reaktivierbar ist")
    }

    func testLegacyNilTemplateIDWithSystemNameIsNotTreatedAsCustom() throws {
        // Legacy-Schutz: exerciseTemplateID == nil → isSystemExercise nutzt byName-Fallback.
        // "Bankdrücken" ist im Systemkatalog → Swap-Pfad (Bankdrücken → Liegestütze), kein Custom-Keep.
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Test", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let exercise = Exercise(name: "Bankdrücken", orderIndex: 0, equipment: .barbell, day: day)
        // exerciseTemplateID bewusst nil lassen (Legacy-Eintrag)
        context.insert(exercise)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertEqual(result.swapped, 1, "nil-templateID + Systemname → byName-Fallback → Swap-Pfad")
        XCTAssertTrue(exercise.isArchived, "Original gearchiviert (Swap-Pfad)")
        XCTAssertFalse(exercise.archivedByEnvironmentChange,
            "archivedByEnvironmentChange=false → System-Swap-Pfad, nicht Custom-Keep-Pfad")
        let replacement = day.exercises.first { $0.swappedFromOriginal === exercise && !$0.isArchived }
        XCTAssertNotNil(replacement, "Aktive Ersatzübung mit swappedFromOriginal === exercise muss existieren")
    }
}
#endif
