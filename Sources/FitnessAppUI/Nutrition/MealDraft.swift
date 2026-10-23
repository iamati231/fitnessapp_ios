#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftUI
#if canImport(Combine)
import Combine
#endif
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Entwurf einer Mahlzeit-Erfassung (Task 6). Sammelt Positionen rein im
/// Speicher — `totalPreview` liest nur `items`, berührt NIE einen
/// `ModelContext`. Das IST die "Vorschau erzeugt keine gespeicherte
/// Mahlzeit"-Garantie: es gibt schlicht keinen Code-Pfad von
/// `addItem`/`totalPreview` zu SwiftData. Persistenz passiert ausschliesslich
/// ueber den expliziten `save(into:)`-Aufruf.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class MealDraft: ObservableObject {

    /// Eine einzelne, noch nicht gespeicherte Position. Entspricht 1:1 den
    /// Feldern von `MealItem.init` (Data) — `save()` baut daraus die
    /// tatsaechlichen `MealItem`s.
    public struct Item: Identifiable, Sendable {
        public let id = UUID()
        public let catalogID: String?
        public let nameSnapshot: String
        public let quantity: Double
        public let unit: FoodUnit
        public let nutrients: NutrientValues

        public init(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues) {
            self.catalogID = catalogID
            self.nameSnapshot = nameSnapshot
            self.quantity = quantity
            self.unit = unit
            self.nutrients = nutrients
        }
    }

    @Published public var date: Date
    @Published public var mealType: MealType
    @Published public private(set) var items: [Item] = []
    /// Doppeltap-Schutz: sobald `save()` einmal erfolgreich war, ist jeder
    /// weitere Aufruf ein Context-freies No-Op (siehe `save(into:persist:)`).
    @Published public private(set) var didSaveSuccessfully: Bool = false

    /// Non-nil, wenn dieser Entwurf eine bestehende `MealEntry` bearbeitet
    /// (Task 7) statt eine neue anzulegen — siehe `init(editing:)`/`save`.
    private let originalMealID: PersistentIdentifier?

    /// NUT-01: noch zu entfernende ALTE Positionen eines Edits, der zwar
    /// committet, dessen Cleanup aber fehlgeschlagen ist. Bleibt ueber den
    /// Aufruf hinaus erhalten, damit der naechste `save()`-Aufruf aufraeumen
    /// kann (statt die Mahlzeit mit doppelten Positionen zu belassen).
    /// `nil` = kein offener Cleanup. Nur von `save()` bzw. dem
    /// Speicher-Fehlerpfad der View geschrieben.
    public private(set) var pendingCleanupItemIDs: [PersistentIdentifier]?

    /// NUT-01: Beim Speichern bleibt der Save-Button aktiv, damit ein offener
    /// Cleanup per erneutem Tap aufgeraeumt werden kann, ohne Positionen zu
    /// duplizieren. Das Flag wird nur gesetzt, wenn der Edit den offenen
    /// Cleanup anschliessend NICHT aufraeumen konnte.
    public func enableRetryAfterFailedCleanup() {
        if hasPendingCleanup {
            didSaveSuccessfully = false
        }
    }

    /// NUT-01: `false`, sobald der CHECKPOINT-Save fuer einen noch offenen
    /// Cleanup auch gescheitert ist. Dann wird weder im Hintergrund
    /// (`AddMealView`-`.onDisappear`) noch beim naechsten Betreten
    /// stillschweigend weiter gespeichert — der offene Zustand bleibt offen
    /// statt in einen unbekannten Store-Zustand ueberzugehen.
    public private(set) var checkpointBetriebsbereit: Bool = true

    /// NUT-01: `true`, wenn der Edit committet ist, aber die alten Positionen
    /// noch im Store stehen. Die UI muss das erklaeren (die Mahlzeit zeigt
    /// für diesen Moment alte UND neue Positionen).
    public var hasPendingCleanup: Bool {
        (pendingCleanupItemIDs?.isEmpty == false)
    }

    public init(date: Date, mealType: MealType) {
        self.date = date
        self.mealType = mealType
        self.originalMealID = nil
    }

    /// Laedt eine bestehende `MealEntry` in einen neuen Entwurf — LIEST nur
    /// `date`/`mealType`/`items`, fasst `meal` selbst nicht an. Solange
    /// `save(into:)` nicht aufgerufen wird (Abbrechen), bleibt die
    /// Original-Zeile dadurch komplett unberuehrt.
    public init(editing meal: MealEntry) {
        self.date = meal.date
        self.mealType = meal.mealType
        self.items = meal.items.map { item in
            Item(
                catalogID: item.catalogID,
                nameSnapshot: item.nameSnapshot,
                quantity: item.quantity,
                unit: item.unit,
                nutrients: item.nutrientsSnapshot
            )
        }
        self.originalMealID = meal.persistentModelID
    }

    public func addItem(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues) {
        items.append(Item(catalogID: catalogID, nameSnapshot: nameSnapshot, quantity: quantity, unit: unit, nutrients: nutrients))
    }

    /// Final-review fix (important): einzelne Position wieder entfernen —
    /// vorher gab es dafuer in der UI keinen Weg, weder im Neuanlage- noch
    /// im Edit-Flow. Ersetzt das Test-only `draft.items.removeAll()`
    /// (`items` ist dafuer wieder `private(set)`).
    public func removeItem(id: Item.ID) {
        items.removeAll { $0.id == id }
    }

    /// Summe aller Positionen — REIN lesend. Kein `ModelContext`-Zugriff,
    /// keine Seiteneffekte: das ist die gesamte Vorschau-Garantie.
    public var totalPreview: NutrientValues {
        NutrientValues.sum(items.map(\.nutrients))
    }

    /// Baut EINE `MealEntry` + ihre `MealItem`s und persistiert sie — oder,
    /// im Edit-Fall (`originalMealID != nil`), ueberschreibt die bestehende
    /// `MealEntry` atomar statt eine zweite anzulegen (Task 7).
    ///
    /// - Doppeltap: Ist `didSaveSuccessfully` bereits `true`, wird sofort
    ///   `.success(())` zurueckgegeben, OHNE den Context erneut anzufassen —
    ///   das ist der vollstaendige Schutz, unabhaengig vom UI-Button-Zustand.
    /// - Erfolg: `didSaveSuccessfully = true`.
    /// - Fehler (Neuanlage): die eingefuegte `MealEntry` UND ihre frisch
    ///   eingefuegten `MealItem`s werden explizit wieder geloescht (nicht
    ///   per Cascade-Delete verlassen — siehe Edit-Pfad unten fuer dieselbe
    ///   Begruendung), `items`/`didSaveSuccessfully` bleiben unveraendert,
    ///   der Fehler geht als `.failure` zurueck — der Entwurf bleibt fuer
    ///   einen erneuten Versuch vollstaendig erhalten.
    /// - Fehler (Edit): bewusst KEIN `context.rollback()` — das wirkt auf den
    ///   GESAMTEN, geteilten Context und wuerde unabhaengige, anderswo
    ///   bereits bestaetigte Aenderungen mit zerstoeren (gleiche Begruendung
    ///   wie `PlanGeneratorInstantiator`-Typ-Doku/`PlansListView.deletePlans`).
    ///
    ///   **NUT-01-Fix (Audit docs/AUDIT_2026-10-23_DELTIQ.md): Rueckbau
    ///   geschieht INNERHALB der Commit-Grenze, nicht danach.** Bisher wurde
    ///   vor dem Save geloescht und im Fehlerfall als Kopie neu eingefuegt,
    ///   ohne zu speichern: der Store behielt die alten Zeilen, `meal.items`
    ///   zeigte schon auf die Kopien — der naechste fremde Save schrieb den
    ///   Mischstand mit.
    ///
    ///   Zwei verworfene Varianten, damit sie nicht neu erprobt werden:
    ///   - `persist` im Fehlerpfad: bestaetigt fremde, offene Aenderungen im
    ///     selben Context.
    ///   - **Die Mahlzeit waehrend des Saves zu wechseln** (alte Positionen
    ///     temporaer aus `meal.items` haengen, damit zwei aufeinanderfolgende
    ///     Commits sich nicht ueberlappen): haengt an einer
    ///     voruebergehenden Modellmutation, die wie ein Fehler aussieht;
    ///     der Zustand „Cleanup noch offen" wird dadurch nur in Wiederholungs-
    ///     faellen erreicht und ist dort nicht eindeutig pruefbar.
    ///
    ///   Deshalb drei Regeln:
    ///   1. Alle Aenderungen von `meal.items` sind relativ (anhaengen bzw.
    ///      entfernen genau des eigenen Objekts). Ein alter Stand im laufenden
    ///      Context erzeugt dadurch nie Duplikate, auch nicht, wenn der
    ///      Cleanup noch offen ist.
    ///   2. Nach dem Commit des Edits ist der Zustand VORHANDEN, als
    ///      „Cleanup offen" markiert und mit `meal.items` neu geladen. Die
    ///      alten Positionen sind damit aus dem Context geraeumt. Ein
    ///      CHECKPOINT-Save (`context.save()`, ohne `rollback()`) macht
    ///      einen zweiphasigen SwiftData-Commit entgueltig, und `rollback()`
    ///      reicht fuer einen einphasigen — nie wird eine bereits committete
    ///      Aenderung zurueckgerollt.
    ///   3. Jeder Aufruf von `save()` raeumt einen noch offenen Cleanup auf
    ///      (Retry), statt ihn als No-Op zu behandeln.
    ///
    ///   `persist`, `cleanup` und `checkpoint` sind Test-Seams (Default
    ///   jeweils `context.save()`), damit der Cleanup-Fehler getrennt vom
    ///   Edit-Save-Fehler und vom Checkpoint injiziert werden kann.
    @discardableResult
    public func save(
        into context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() },
        cleanup: (ModelContext) throws -> Void = { try $0.save() },
        checkpoint: (ModelContext) throws -> Void = { try $0.save() }
    ) -> Result<Void, Error> {
        // NUT-01: Ein bereits committeter Edit mit offenem Cleanup wird beim
        // naechsten Versuch aufgeraeumt, nicht als No-Op behandelt (siehe
        // `finishPendingCleanup`).
        if didSaveSuccessfully {
            return finishPendingCleanup(in: context, cleanup: cleanup, checkpoint: checkpoint)
        }

        // Final-review fix (important): an empty 0-kcal meal must never be
        // persisted — neither as a brand-new MealEntry nor as the result of
        // editing an existing one down to zero items. UI-seitig gespiegelt
        // durch AddMealView's Save-Button-`.disabled`.
        guard !items.isEmpty else {
            return .failure(MealDraftError.noItems)
        }

        if let originalMealID {
            guard let meal = context.model(for: originalMealID) as? MealEntry else {
                return .failure(MealDraftError.originalMealMissing)
            }

            // NUT-01: Nur Datum/Typ werden VOR dem Save umgeschrieben (reine
            // Attribute, per Rollback exakt rueckgaengig zu machen). Die
            // alten Items bleiben gespeichert, bis der Save erfolgreich war.
            // VOR dem Einfuegen der neuen einsammeln: `meal.items` wuerde
            // danach (gleiche Inverse-Relationship) auch diese enthalten.
            let oldDate = meal.date
            let oldMealType = meal.mealType
            let oldItems = meal.items
            let oldItemIDs = oldItems.map(\.persistentModelID)

            meal.date = date
            meal.mealType = mealType
            var insertedItems: [MealItem] = []
            for item in items {
                let mealItem = MealItem(
                    catalogID: item.catalogID,
                    nameSnapshot: item.nameSnapshot,
                    quantity: item.quantity,
                    unit: item.unit,
                    nutrients: item.nutrients,
                    meal: meal
                )
                context.insert(mealItem)
                insertedItems.append(mealItem)
            }

            do {
                try persist(context)
            } catch {
                // Rueckbau innerhalb der Commit-Grenze: die neuen Items
                // verlassen den Context, die alten bleiben unangetastet die
                // gespeicherten Zeilen. Bewusst OHNE zweiten Save — siehe
                // die Typ-Doku zu `save(into:persist:cleanup:checkpoint:)`.
                for inserted in insertedItems {
                    // Apple-CI-Fund (siehe `PlanGeneratorInstantiator.revert`-
                    // Doku): bei einem frisch inserteten, nie gespeicherten
                    // Objekt bleibt `meal.items` ohne explizite Entfernung aus
                    // dem Array manchmal noch mit dem geloeschten Objekt
                    // bestueckt, bis ein Save/Re-Fetch die Relationship-Array-
                    // Seite aktualisiert hat.
                    meal.items.removeAll { $0.persistentModelID == inserted.persistentModelID }
                    context.delete(inserted)
                }
                meal.date = oldDate
                meal.mealType = oldMealType
                return .failure(error)
            }

            // Ab hier ist der Editiervorgang gespeichert.
            didSaveSuccessfully = true
            guard !oldItems.isEmpty else { return .success(()) }

            pendingCleanupItemIDs = oldItemIDs
            // Regel 2 (Typ-Doku): den alten Stand im Context ersetzen, damit
            // `meal.items` genau dem gespeicherten Zustand entspricht. Dazu
            // werden die alten Positionen aus dem Context geloest, der
            // Zustand per CHECKPOINT festgenagelt (kein `rollback()`) und die
            // Mahlzeit frisch aus dem Store geladen.
            for id in oldItemIDs {
                removeStaleItem(id, in: context)
            }
            _ = try? checkpoint(context)
            refreshOriginalMeal(in: context)

            return finishPendingCleanup(in: context, cleanup: cleanup, checkpoint: checkpoint)
        }

        let meal = MealEntry(date: date, mealType: mealType)
        context.insert(meal)
        var insertedItems: [MealItem] = []
        for item in items {
            let mealItem = MealItem(
                catalogID: item.catalogID,
                nameSnapshot: item.nameSnapshot,
                quantity: item.quantity,
                unit: item.unit,
                nutrients: item.nutrients,
                meal: meal
            )
            context.insert(mealItem)
            insertedItems.append(mealItem)
        }

        do {
            try persist(context)
            didSaveSuccessfully = true
            return .success(())
        } catch {
            // Final-review fix (important): explicit cleanup instead of
            // relying on `context.delete(meal)` cascading to its freshly-
            // inserted, never-saved MealItems — untested in this codebase
            // for un-inserted-then-deleted objects (same reasoning as the
            // edit path's Apple-CI-Fund note below).
            for inserted in insertedItems {
                meal.items.removeAll { $0.persistentModelID == inserted.persistentModelID }
                context.delete(inserted)
            }
            context.delete(meal)
            return .failure(error)
        }
    }

    /// NUT-01: Raeumt die alten Positionen eines bereits committeten Edits ab.
    ///
    /// - Erfolg: `pendingCleanupItemIDs = nil`, Mahlzeit frisch aus dem Store.
    /// - Fehler: Zustand bleibt „offen" (naechster `save()` versucht es
    ///   erneut), `meal.items` wird TROTZDEM frisch aus dem Store geladen,
    ///   damit der Entwurf nie eine Mahlzeit anzeigt, die so nicht gespeichert
    ///   ist. Es wird nie ein Commit zurueckgerollt, es wird nie etwas
    ///   doppelt eingefuegt.
    private func finishPendingCleanup(
        in context: ModelContext,
        cleanup: (ModelContext) throws -> Void,
        checkpoint: (ModelContext) throws -> Void
    ) -> Result<Void, Error> {
        guard let pendingIDs = pendingCleanupItemIDs, !pendingIDs.isEmpty else {
            pendingCleanupItemIDs = nil
            return .success(())
        }
        for id in pendingIDs {
            removeStaleItem(id, in: context)
        }
        do {
            try cleanup(context)
        } catch {
            refreshOriginalMeal(in: context)
            return .failure(MealDraftItemCleanupError(underlying: error))
        }
        // Der Edit ist bereits committet und darf NICHT zurueckgedreht
        // werden — deshalb hier kein `rollback()`. Der CHECKPOINT-Save nagelt
        // den Zustand fest (er ist bei einem zweiphasigen Store-Commit der
        // endgueltige Schreibvorgang). Scheitert auch er, bleibt der
        // Cleanup offen und `checkpointBetriebsbereit` auf `false`; dann
        // versucht KEIN spaeterer automatischer Save mehr das Aufraeumen.
        do {
            try checkpoint(context)
        } catch {
            checkpointBetriebsbereit = false
            refreshOriginalMeal(in: context)
            return .failure(MealDraftItemCleanupError(underlying: error))
        }
        pendingCleanupItemIDs = nil
        refreshOriginalMeal(in: context)
        return .success(())
    }

    /// Entfernt genau EINE alte Position: loest die Beziehung, damit kein
    /// Cascade-/Inverse-Effekt die Mahlzeit beruehrt, und loescht das Objekt.
    private func removeStaleItem(_ id: PersistentIdentifier, in context: ModelContext) {
        guard let stale = context.model(for: id) as? MealItem else { return }
        if stale.meal != nil {
            stale.meal = nil
        }
        context.delete(stale)
    }

    /// Laedt die Mahlzeit-Beziehung aus dem Store, damit die Anzeige immer
    /// die tatsaechlich gespeicherten Positionen zeigt (NUT-01).
    private func refreshOriginalMeal(in context: ModelContext) {
        guard let originalMealID, let meal = context.model(for: originalMealID) as? MealEntry else { return }
        context.delete(meal)
        context.refresh(meal, mergeChanges: false)
    }
}

/// NUT-01: Der Edit selbst (Datum/Typ + neue Positionen) ist committet, nur
/// das Entfernen der ALTEN Positionen ist gescheitert. Der Entwurf gilt als
/// gespeichert — ein erneutes `save()` raeumt den offenen Cleanup auf
/// (`MealDraft.pendingCleanupItemIDs`) statt Positionen zu duplizieren. Bis
/// dahin zeigt die Mahlzeit den tatsaechlich gespeicherten Stand (alte UND
/// neue Positionen sind vorhanden, weil der Edit nicht rueckgaengig gemacht
/// werden darf); die UI erklaert genau das.
public struct MealDraftItemCleanupError: Error, CustomStringConvertible {
    public let underlying: Error

    public init(underlying: Error) {
        self.underlying = underlying
    }

    public var description: String {
        "MealDraftItemCleanupError(underlying: \(underlying))"
    }
}

/// Fehler, die `MealDraft.save` zurueckgeben kann.
public enum MealDraftError: Error, Equatable {
    /// Die `MealEntry`, aus der dieser Entwurf per `init(editing:)` gebaut
    /// wurde, existiert im uebergebenen Context nicht mehr (z.B. zwischen-
    /// zeitlich geloescht).
    case originalMealMissing
    /// Final-review fix (important): `save()` wurde ohne Positionen
    /// aufgerufen — weder eine neue noch eine editierte Mahlzeit darf mit
    /// 0 Items persistiert werden.
    case noItems
}
#endif
