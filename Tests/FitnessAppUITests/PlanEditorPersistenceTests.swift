#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

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
#endif
