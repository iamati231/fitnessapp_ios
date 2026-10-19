#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Day-Editor-Persistenzbugs (Swipe-Loeschen + Tag-Level-Stepper/Picker):
/// `DayEditorView.deleteExercises(at:)` und die "Fertig"-Checkmark-Aktion
/// (jetzt `saveAndDismiss()`) nutzten bislang KEIN explizites
/// `context.save()` — die Typ-Doku nannte `TrainingDay`/`Exercise`
/// faelschlich "autosaved direkt in SwiftData" ueber `@Bindable`. Tatsaechlich
/// mutiert `@Bindable` nur den Live-Objektgraphen im Speicher; die
/// tatsaechliche Persistenz haengt an SwiftDatas implizitem Context-Autosave,
/// der nach einem App-Kaltstart kurz nach der Aenderung nicht zuverlaessig
/// schon gelaufen sein muss — exakt der bereits an anderer Stelle dieser
/// App per TestingBot bestaetigte Musterfehler (siehe
/// `TrainingDayContentSnapshotWriterTests.testCapturePersistsWithoutAny-
/// AdditionalCallerSave`).
///
/// `deleteExercises`/`saveAndDismiss` sind bewusst WEITERHIN `private` und
/// lesen `self.modelContext` aus `@Environment` — direktes Aufrufen ueber
/// eine ohne lebenden SwiftUI-/`.modelContainer`-Kontext konstruierte
/// `DayEditorView`-Instanz wuerde NICHT den in diesem Test aufgesetzten
/// Context treffen (siehe `EditorDiscardSnapshotTests`-Typ-Dokumentation:
/// "nie `@Environment`-rueckgebundene Properties"). Ein echter
/// View-/UI-Test-Harness fehlt in diesem Repo (siehe dort). Dieser Test
/// beweist deshalb NICHT die beiden Funktionen selbst, sondern die
/// zugrundeliegende Fix-Technik, die beide jetzt anwenden: ein explizites
/// `context.save()` UNMITTELBAR nach der Mutation, OHNE jede weitere
/// UI-Interaktion, uebersteht einen echten Store-Neustart — waehrend
/// dieselbe Mutation OHNE diesen Save (der vorherige Zustand) das nicht
/// garantiert tut. Die tatsaechliche Verdrahtung in `DayEditorView` bleibt
/// per sorgfaeltiger manueller Durchsicht verifiziert (siehe Kommentare an
/// `deleteExercises`/`saveAndDismiss`) und per Geraete-/TestingBot-Kaltstart
/// noch zu bestaetigen — in dieser Session nicht durchfuehrbar (kein
/// TestingBot-Zugriff), ehrlich offen ausgewiesen.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DayEditorPersistenceTests: XCTestCase {

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Reproduziert die Fix-Technik fuer Bug 1 (Swipe-Loeschen): Loeschen +
    /// SOFORTIGER `context.save()`, Container-Ende OHNE jede weitere
    /// Interaktion, dann Store-Neuoeffnung — genau die Sequenz, die ein
    /// App-Kaltstart kurz nach dem Swipe nachbildet.
    func testExerciseDeletionWithImmediateSaveSurvivesARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-editor-delete-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        var keptExerciseID: PersistentIdentifier!
        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Push A", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
            context.insert(day)
            let toDelete = Exercise(name: "Bankdrücken", exerciseTemplateID: UUID(), orderIndex: 0, day: day)
            context.insert(toDelete)
            let toKeep = Exercise(name: "Kurzhantel-Rudern", exerciseTemplateID: UUID(), orderIndex: 1, day: day)
            context.insert(toKeep)
            try context.save()
            keptExerciseID = toKeep.persistentModelID

            // Exakt die Sequenz aus `deleteExercises(at:)` nach dem Fix:
            // Loeschen, Re-Indizierung, SOFORT `context.save()` — kein
            // weiterer Schritt, der SwiftDatas impliziten Autosave haette
            // ausloesen koennen.
            context.delete(toDelete)
            toKeep.orderIndex = 0
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let exercises = try reopened.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.name), ["Kurzhantel-Rudern"], "die Loeschung muss einen echten Store-Neustart ueberstehen, nicht nur In-Memory-Retention")
        XCTAssertEqual(exercises.first?.persistentModelID, keptExerciseID)
        XCTAssertEqual(exercises.first?.orderIndex, 0)
    }

    /// Reproduziert die Fix-Technik fuer Bug 2 (Tag-Level-Stepper/Picker):
    /// Aenderung an `timeFormat`/`circuitRounds`/`circuitRestSeconds` +
    /// SOFORTIGER `context.save()` (wie jetzt in `saveAndDismiss()`),
    /// Container-Ende, Store-Neuoeffnung.
    func testCircuitFieldChangesWithImmediateSaveSurviveARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-editor-circuit-persistence-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let plan = TrainingPlan(name: "Zirkel-Tag", programType: "custom", isActive: true)
            context.insert(plan)
            let day = TrainingDay(name: "Zirkel", weekday: 2, type: .custom, plan: plan)
            context.insert(day)
            try context.save()

            // Exakt die Sequenz aus `saveAndDismiss()` nach dem Fix: Felder
            // am `@Bindable`-Tag direkt mutieren (wie der Stepper/Picker es
            // tut), SOFORT `context.save()` — kein `dismiss()`-Aufruf noetig,
            // der ist fuer die Persistenz selbst irrelevant.
            day.timeFormat = .circuit
            day.circuitRounds = 5
            day.circuitRestSeconds = 45
            day.circuitMode = .fixedReps
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let days = try reopened.mainContext.fetch(FetchDescriptor<TrainingDay>())
        guard let day = days.first else {
            return XCTFail("der Tag muss einen echten Store-Neustart ueberstehen")
        }
        XCTAssertEqual(day.timeFormat, .circuit)
        XCTAssertEqual(day.circuitRounds, 5)
        XCTAssertEqual(day.circuitRestSeconds, 45)
        XCTAssertEqual(day.circuitMode, .fixedReps)
    }
}
#endif
