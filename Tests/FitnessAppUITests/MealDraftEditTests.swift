#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealDraftEditTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private var context: ModelContext { container.mainContext }

    func testEditingReplacesItemsWithoutCreatingSecondMeal() throws {
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Alt", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        for item in draft.items { draft.removeItem(id: item.id) }
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 200, unit: .gram, nutrients: .zero)
        let result = draft.save(into: context)

        if case .failure(let error) = result { XCTFail("\(error)") }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1, "Edit darf keine zweite MealEntry anlegen")
        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Neu"])
    }

    func testCancelingEditLeavesOriginalUntouched() throws {
        let meal = MealEntry(date: Date(), mealType: .dinner)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        draft.addItem(catalogID: nil, nameSnapshot: "Wird verworfen", quantity: 1, unit: .gram, nutrients: .zero)
        // Kein draft.save() — Abbrechen heisst: Entwurf wird einfach nicht gespeichert.

        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Original"], "Unveraenderte Originaldaten trotz Entwurfs-Aenderung")
    }

    // Review-Nachbesserung: ein fehlschlagender Edit-Save darf den Context
    // nicht in einem halb-geaenderten Zustand zuruecklassen (Datum/Typ schon
    // umgeschrieben, alte Positionen schon geloescht) — sonst wuerde ein
    // spaeterer, voellig unabhaengiger `context.save()` irgendwo anders in
    // der App diese eigentlich fehlgeschlagene Aenderung unbemerkt doch noch
    // committen. Spiegelt `testSaveFailurePreservesDraftAndReportsFailure`
    // aus `MealDraftTests` (Task 6), nur fuer den Edit-Pfad.
    func testEditSaveFailureRevertsMealToOriginalState() throws {
        struct Boom: Error {}
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let originalDate = meal.date
        let originalMealType = meal.mealType

        let draft = MealDraft(editing: meal)
        draft.date = Date(timeIntervalSinceNow: 86_400)
        draft.mealType = .dinner
        for item in draft.items { draft.removeItem(id: item.id) }
        draft.addItem(catalogID: nil, nameSnapshot: "Wuerde-gespeichert", quantity: 50, unit: .gram, nutrients: .zero)

        // Nur der Edit-Save scheitert; `cleanup`/`checkpoint` bleiben die
        // echten Seams.
        let result = draft.save(into: context, persist: { _ in throw Boom() })

        switch result {
        case .success: XCTFail("Erwartet: Fehler")
        case .failure: break
        }
        XCTAssertFalse(draft.didSaveSuccessfully)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1, "Fehlgeschlagener Edit-Save darf keine zweite MealEntry anlegen")
        XCTAssertEqual(meal.date, originalDate, "Datum muss nach Fehler zurueckgesetzt sein")
        XCTAssertEqual(meal.mealType, originalMealType, "Typ muss nach Fehler zurueckgesetzt sein")
        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Original"], "Fehlgeschlagener Edit-Save darf die Original-Positionen nicht verlieren")
    }

    // MARK: - NUT-01 (docs/AUDIT_2026-10-23_DELTIQ.md): Rollback innerhalb der Commit-Grenze

    /// NUT-01, Kernfall: nach einem fehlgeschlagenen Edit-Save darf ein
    /// SPAETERER, voellig unabhaengiger Save (irgendein anderer Screen) keine
    /// Spur des fehlgeschlagenen Edits festschreiben. Vor dem Fix tat er
    /// genau das: die Original-Items waren ungespeichert geloescht und durch
    /// Kopien ersetzt — der naechste `context.save()` schrieb Loeschung +
    /// Kopien.
    func testEditSaveFailureLeavesNothingBehindForAnUnrelatedLaterSave() throws {
        struct Boom: Error {}
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        let original = MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram,
                                nutrients: NutrientValues(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1), meal: meal)
        context.insert(original)
        try context.save()
        let originalID = original.persistentModelID

        let draft = MealDraft(editing: meal)
        for item in draft.items { draft.removeItem(id: item.id) }
        draft.addItem(catalogID: nil, nameSnapshot: "Wuerde-gespeichert", quantity: 50, unit: .gram,
                      nutrients: NutrientValues(kcal: 50, proteinG: 1, carbsG: 1, fatG: 1))

        guard case .failure = draft.save(into: context, persist: { _ in throw Boom() }) else {
            return XCTFail("Erwartet: Fehler")
        }

        // Der „fremde" Save: irgendein anderer Screen speichert den Context.
        try context.save()

        // Frisch aus dem Store gelesen (eigener Context, kein In-Memory-Cache).
        let reader = ModelContext(container)
        let storedItems = try reader.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(storedItems.map(\.nameSnapshot), ["Original"],
                       "NUT-01: Der fehlgeschlagene Edit darf auch nach einem fremden Save nicht im Store stehen")
        XCTAssertEqual(storedItems.map(\.persistentModelID), [originalID],
                       "Das Original-Item muss dasselbe Objekt bleiben — keine Kopie, kein Duplikat")
        XCTAssertEqual(try reader.fetch(FetchDescriptor<MealEntry>()).first?.mealType, .lunch)

        // Und im aufrufenden Context zeigt die Mahlzeit weiterhin exakt eine
        // Position: das Original.
        XCTAssertEqual(meal.items.map(\.nameSnapshot), ["Original"])
    }

    /// NUT-01: Der Rollback darf fremde, unabhaengige offene Aenderungen im
    /// selben Context weder loeschen noch bestaetigen — er laesst sie einfach
    /// stehen (der naechste Save des Eigentuemers schreibt sie, wie vorher).
    func testEditSaveFailureDoesNotTouchUnrelatedPendingChanges() throws {
        struct Boom: Error {}
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        // Unabhaengige, anderswo offene Aenderung im GEMEINSAMEN Context.
        let sentinel = MealEntry(date: Date(), mealType: .snack)
        context.insert(sentinel)

        let draft = MealDraft(editing: meal)
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 10, unit: .gram, nutrients: .zero)

        guard case .failure = draft.save(into: context, persist: { _ in throw Boom() }) else {
            return XCTFail("Erwartet: Fehler")
        }

        XCTAssertEqual(sentinel.modelContext, context, "Fremde offene Aenderung muss im Context bleiben")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealItem>()), 1,
                       "Nur das Original-Item ist im Context, keine liegengebliebenen Neuanlagen")
    }

    /// NUT-01, Erfolgsfall: nach einem erfolgreichen Edit stehen exakt die
    /// neuen Positionen im Store — die alten werden im zweiten (Cleanup-)
    /// Save entfernt, nicht vorher.
    func testSuccessfulEditPersistsNewItemsAndRemovesOldOnes() throws {
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Alt", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        for item in draft.items { draft.removeItem(id: item.id) }
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 200, unit: .gram, nutrients: .zero)

        guard case .success = draft.save(into: context) else { return XCTFail("Erwartet: Erfolg") }

        let storedItems = try ModelContext(container).fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(storedItems.map(\.nameSnapshot), ["Neu"])
    }

    /// NUT-01, Cleanup-Fehlerpfad – der Fall, den der Review verlangt:
    /// Der erste Save gelingt, der zweite (Entfernen der alten Positionen)
    /// scheitert. Geprüft wird gegen den **tatsächlich gespeicherten** Store
    /// (frischer `ModelContext`), nicht gegen den In-Memory-Zustand.
    ///
    /// Erwartung:
    /// - Der Edit ist committet (die neuen Positionen sind dauerhaft da).
    /// - Der Cleanup bleibt als offene Arbeit markiert, `meal.items` zeigt
    ///   den gespeicherten Stand (alte + neue), nicht den Entwurf.
    /// - Ein späterer, unabhängiger Save erzeugt KEINE Duplikate.
    /// - Ein zweiter Versuch räumt genau einmal auf (alte Positionen weg,
    ///   neue genau einmal vorhanden); danach ist erneut Speichern No-Op.
    func testCleanupFailureKeepsCommittedEditAndRetryCleansUpExactlyOnce() throws {
        struct Boom: Error {}
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        for item in draft.items { draft.removeItem(id: item.id) }
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 50, unit: .gram, nutrients: .zero)

        // 1) Edit committet, Cleanup scheitert.
        let first = draft.save(into: context, persist: { try $0.save() }, cleanup: { _ in throw Boom() })
        guard case .failure(let error) = first else { return XCTFail("Erwartet: Cleanup-Fehler") }
        XCTAssertTrue(error is MealDraftItemCleanupError)
        XCTAssertTrue(draft.didSaveSuccessfully, "Der Edit selbst ist gespeichert")
        XCTAssertTrue(draft.hasPendingCleanup, "Der Cleanup ist als offen markiert")

        // Frischer Context = der tatsächliche Store.
        let storeAfterFailure = try ModelContext(container).fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(Set(storeAfterFailure.map(\.nameSnapshot)), ["Original", "Neu"],
                       "Der committete Edit steht im Store (neue Position), die alte ist noch nicht entfernt")

        // `meal.items` im Entwurfs-Context entspricht dem gespeicherten Stand.
        XCTAssertEqual(Set(meal.items.map(\.nameSnapshot)), ["Original", "Neu"],
                       "meal.items darf nicht vom gespeicherten Stand abweichen")

        // 2) Ein späterer, unabhängiger Save darf nichts duplizieren.
        try context.save()
        let afterForeignSave = try ModelContext(container).fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(afterForeignSave.count, 2, "keine Duplikate durch einen fremden Save")
        XCTAssertEqual(Set(afterForeignSave.map(\.nameSnapshot)), ["Original", "Neu"])

        // 3) Zweiter Versuch räumt auf — genau einmal.
        let second = draft.save(into: context)
        if case .failure(let error) = second { XCTFail("Cleanup-Retry sollte gelingen: \(error)") }
        XCTAssertFalse(draft.hasPendingCleanup)

        let finalItems = try ModelContext(container).fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(finalItems.map(\.nameSnapshot), ["Neu"], "genau die neue Position, die alte ist entfernt")
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<MealEntry>()).count, 1)

        // 4) Nach erfolgreichem Aufräumen ist ein weiteres Speichern No-Op.
        _ = draft.save(into: context)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<MealItem>()).count, 1,
                       "erneutes Speichern nach erfolgreichem Cleanup darf nichts duplizieren")
    }

    /// NUT-01: Scheitert auch der CHECKPOINT nach dem Cleanup, bleibt der
    /// Zustand bewusst offen (kein stilles Weiterspeichern) und ein weiterer
    /// Versuch wird nicht durch `didSaveSuccessfully` blockiert.
    func testCleanupCheckpointFailureLeavesStateOpenAndAllowsRetry() throws {
        struct Boom: Error {}
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        for item in draft.items { draft.removeItem(id: item.id) }
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 50, unit: .gram, nutrients: .zero)

        let result = draft.save(
            into: context,
            persist: { try $0.save() },
            cleanup: { try $0.save() },
            checkpoint: { _ in throw Boom() }
        )
        guard case .failure = result else { return XCTFail("Erwartet: Checkpoint-Fehler") }
        XCTAssertTrue(draft.hasPendingCleanup)
        XCTAssertFalse(draft.checkpointBetriebsbereit, "kein stilles Weiterspeichern nach CHECKPOINT-Fehler")

        draft.enableRetryAfterFailedCleanup()
        let retry = draft.save(into: context)
        if case .failure(let error) = retry { XCTFail("Retry sollte gelingen: \(error)") }
        let items = try ModelContext(container).fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Neu"])
    }
}
#endif
