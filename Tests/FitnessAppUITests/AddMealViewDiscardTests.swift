#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): `AddMealView`'s
/// Cancel-Button verwarf den `MealDraft` bisher kommentarlos. Dieser Test
/// deckt die beiden Haelften von `isDirty` ab:
///
///   1. `MealDraftItemFieldsSnapshot` -- die Vergleichsbasis fuer bereits per
///      "Add" uebernommene Positionen. Das ist der bugtraechtigste Teil: Edit-
///      Mode startet mit vorbefuellten Items aus der bestehenden Mahlzeit, die
///      fuer sich allein NICHT dirty machen duerfen -- eine naive
///      `!draft.items.isEmpty`-Pruefung waere in JEDEM Edit-Aufruf faelschlich
///      dirty. `MealDraftItemFieldsSnapshot` ist `internal` (nicht `private`,
///      siehe dortige Doku) und per `@testable import` direkt pruefbar, ganz
///      ohne lebenden SwiftUI-Graph (reiner Wertevergleich).
///
///   2. Die restliche `isDirty`-Formel (selektierter Katalog-Eintrag +
///      Bottom-Bar-Menge, KI-Freitext, offene KI-Kandidaten) haengt an
///      @State, das `AddMealView.isDirty` selbst `private` haelt und das ohne
///      lebenden View-Graph nach einer Mutation nicht zuverlaessig lesbar ist
///      (siehe `EditorDiscardSnapshotTests`-Dateikopf fuer die dokumentierte
///      Einschraenkung, identisch zu `MeasurementDoubleTapGuardTests`' Ansatz
///      fuer dasselbe Problem). `isDirtyFormula` unten reproduziert die
///      EXAKTE Formel aus `AddMealView.isDirty` gegen reine Werte -- das
///      beweist (a)/(b) aus dem Task-8-Brief fuer jede der vier Quellen
///      einzeln, auch wenn die eigentliche View-Verdrahtung (Cancel-Button,
///      Dialog) nur per echtem Geraete-/Apple-CI-Test verifizierbar bleibt.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class AddMealViewDiscardTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeNutrients() -> NutrientValues {
        NutrientValues(kcal: 140, proteinG: 12, carbsG: 1, fatG: 10)
    }

    // MARK: - MealDraftItemFieldsSnapshot

    func testUnchangedEditModeItemsAreNotDirty() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let meal = MealEntry(date: Date(), mealType: .lunch)
        ctx.insert(meal)
        let existing = MealItem(catalogID: "egg", nameSnapshot: "Ei", quantity: 2, unit: .piece, nutrients: makeNutrients(), meal: meal)
        ctx.insert(existing)

        let draft = MealDraft(editing: meal)
        let itemsAtOpen = MealDraftItemFieldsSnapshot.capture(from: draft.items)

        // (b) aus dem Brief: Edit-Mode ohne jede weitere Aenderung darf NICHT
        // dirty sein, obwohl `draft.items` nicht leer ist.
        XCTAssertFalse(itemsAtOpen.isEmpty)
        XCTAssertEqual(MealDraftItemFieldsSnapshot.capture(from: draft.items), itemsAtOpen)
    }

    func testAddingAnItemDuringEditIsDetectedAsDirty() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let meal = MealEntry(date: Date(), mealType: .lunch)
        ctx.insert(meal)
        let existing = MealItem(catalogID: "egg", nameSnapshot: "Ei", quantity: 2, unit: .piece, nutrients: makeNutrients(), meal: meal)
        ctx.insert(existing)

        let draft = MealDraft(editing: meal)
        let itemsAtOpen = MealDraftItemFieldsSnapshot.capture(from: draft.items)

        draft.addItem(catalogID: "bread", nameSnapshot: "Brot", quantity: 50, unit: .gram, nutrients: makeNutrients())

        // (a) aus dem Brief: eine zusaetzliche Position macht dirty.
        XCTAssertNotEqual(MealDraftItemFieldsSnapshot.capture(from: draft.items), itemsAtOpen)
    }

    func testRemovingAnExistingItemDuringEditIsDetectedAsDirty() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let meal = MealEntry(date: Date(), mealType: .lunch)
        ctx.insert(meal)
        let existing = MealItem(catalogID: "egg", nameSnapshot: "Ei", quantity: 2, unit: .piece, nutrients: makeNutrients(), meal: meal)
        ctx.insert(existing)

        let draft = MealDraft(editing: meal)
        let itemsAtOpen = MealDraftItemFieldsSnapshot.capture(from: draft.items)
        XCTAssertFalse(draft.items.isEmpty)

        draft.removeItem(id: draft.items[0].id)

        XCTAssertNotEqual(MealDraftItemFieldsSnapshot.capture(from: draft.items), itemsAtOpen)
    }

    func testNewModeStartsWithEmptySnapshotAndAddingAnItemIsDirty() {
        // New-Mode: `AddMealView.init(date:mealType:)` setzt `itemsAtOpen = []`.
        let itemsAtOpen: [MealDraftItemFieldsSnapshot] = []
        let draft = MealDraft(date: Date(), mealType: .snack)
        XCTAssertEqual(MealDraftItemFieldsSnapshot.capture(from: draft.items), itemsAtOpen, "(b) frisch geoeffnet, nichts eingegeben -> nicht dirty")

        draft.addItem(catalogID: nil, nameSnapshot: "Eigenes Essen", quantity: 1, unit: .piece, nutrients: makeNutrients())
        XCTAssertNotEqual(MealDraftItemFieldsSnapshot.capture(from: draft.items), itemsAtOpen, "(a) erste Position -> dirty")
    }

    // MARK: - isDirty-Formel (Shape-Reproduktion fuer die @State-Quellen)

    /// Reproduziert `AddMealView.isDirty` exakt (siehe dortige Doku) --
    /// bewusst keine View-Instanz, siehe Dateikopf fuer die Begruendung.
    ///
    /// Fix-Runde 1 (Befund 2): `dateNow`/`dateAtOpen` und `mealTypeNow`/
    /// `mealTypeAtOpen` ergaenzt -- `MealDraft.save()` schreibt im Edit-Mode
    /// auch diese beiden Felder zurueck, `isDirty` hat sie vorher nicht
    /// geprueft.
    private func isDirtyFormula(
        itemsNow: [MealDraftItemFieldsSnapshot],
        itemsAtOpen: [MealDraftItemFieldsSnapshot],
        selectedEntryIsSet: Bool,
        quantityIsSet: Bool,
        aiInputText: String,
        aiCandidatesIsEmpty: Bool,
        dateNow: Date,
        dateAtOpen: Date,
        mealTypeNow: MealType,
        mealTypeAtOpen: MealType
    ) -> Bool {
        itemsNow != itemsAtOpen
            || selectedEntryIsSet
            || quantityIsSet
            || !aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !aiCandidatesIsEmpty
            || dateNow != dateAtOpen
            || mealTypeNow != mealTypeAtOpen
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testIsDirtyFormulaIsFalseWhenNothingWasEntered() {
        XCTAssertFalse(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: false, quantityIsSet: false,
            aiInputText: "   ", aiCandidatesIsEmpty: true,
            dateNow: Self.referenceDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .lunch, mealTypeAtOpen: .lunch
        ))
    }

    func testIsDirtyFormulaIsTrueForSelectedCatalogEntryWithoutAddTap() {
        XCTAssertTrue(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: true, quantityIsSet: false,
            aiInputText: "", aiCandidatesIsEmpty: true,
            dateNow: Self.referenceDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .lunch, mealTypeAtOpen: .lunch
        ), "ein angewaehlter Katalog-Eintrag in der Bottom-Bar allein muss schon dirty machen")
    }

    func testIsDirtyFormulaIsTrueForTypedQuantityWithoutAddTap() {
        XCTAssertTrue(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: false, quantityIsSet: true,
            aiInputText: "", aiCandidatesIsEmpty: true,
            dateNow: Self.referenceDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .lunch, mealTypeAtOpen: .lunch
        ))
    }

    func testIsDirtyFormulaIsTrueForUnextractedAIFreeText() {
        XCTAssertTrue(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: false, quantityIsSet: false,
            aiInputText: "2 Eier und Toast", aiCandidatesIsEmpty: true,
            dateNow: Self.referenceDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .lunch, mealTypeAtOpen: .lunch
        ), "getippter, noch nicht extrahierter KI-Freitext muss dirty machen")
    }

    func testIsDirtyFormulaIsTrueForPendingAICandidates() {
        XCTAssertTrue(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: false, quantityIsSet: false,
            aiInputText: "", aiCandidatesIsEmpty: false,
            dateNow: Self.referenceDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .lunch, mealTypeAtOpen: .lunch
        ), "bereits extrahierte, aber noch nicht uebernommene KI-Kandidaten muessen dirty machen")
    }

    /// Fix-Runde 1 (Befund 2, Kernvertrag): ein im Edit-Mode auf einen
    /// anderen Tag verschobenes Datum -- sonst NICHTS veraendert -- muss
    /// allein schon dirty machen, sonst geht die Verschiebung beim Abbrechen
    /// kommentarlos verloren.
    func testIsDirtyFormulaIsTrueForDateOnlyChangeInEditMode() {
        let movedDate = Self.referenceDate.addingTimeInterval(86_400)
        XCTAssertTrue(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: false, quantityIsSet: false,
            aiInputText: "", aiCandidatesIsEmpty: true,
            dateNow: movedDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .lunch, mealTypeAtOpen: .lunch
        ), "ein verschobenes Datum allein muss im Edit-Mode dirty machen")
    }

    /// Fix-Runde 1 (Befund 2, Kernvertrag): ein im Edit-Mode geaenderter
    /// Mahlzeittyp -- sonst NICHTS veraendert -- muss allein schon dirty
    /// machen.
    func testIsDirtyFormulaIsTrueForMealTypeOnlyChangeInEditMode() {
        XCTAssertTrue(isDirtyFormula(
            itemsNow: [], itemsAtOpen: [], selectedEntryIsSet: false, quantityIsSet: false,
            aiInputText: "", aiCandidatesIsEmpty: true,
            dateNow: Self.referenceDate, dateAtOpen: Self.referenceDate,
            mealTypeNow: .dinner, mealTypeAtOpen: .lunch
        ), "ein geaenderter Mahlzeittyp allein muss im Edit-Mode dirty machen")
    }
}
#endif
