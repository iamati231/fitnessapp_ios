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
    // internal(set) statt private(set): MealDraftEditTests (@testable) muss
    // fuer den Edit-Test `draft.items.removeAll()` aufrufen koennen.
    @Published public internal(set) var items: [Item] = []
    /// Doppeltap-Schutz: sobald `save()` einmal erfolgreich war, ist jeder
    /// weitere Aufruf ein Context-freies No-Op (siehe `save(into:persist:)`).
    @Published public private(set) var didSaveSuccessfully: Bool = false

    /// Non-nil, wenn dieser Entwurf eine bestehende `MealEntry` bearbeitet
    /// (Task 7) statt eine neue anzulegen — siehe `init(editing:)`/`save`.
    private let originalMealID: PersistentIdentifier?

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
    /// - Fehler (Neuanlage): die eingefuegte `MealEntry` (kaskadiert ihre
    ///   Items) wird wieder geloescht, `items`/`didSaveSuccessfully` bleiben
    ///   unveraendert, der Fehler geht als `.failure` zurueck — der Entwurf
    ///   bleibt fuer einen erneuten Versuch vollstaendig erhalten.
    /// - Fehler (Edit): bewusst KEIN `context.rollback()` — das wirkt auf den
    ///   GESAMTEN, geteilten Context und wuerde unabhaengige, anderswo
    ///   bereits bestaetigte Aenderungen mit zerstoeren (gleiche Begruendung
    ///   wie `PlanGeneratorInstantiator`-Typ-Doku/`PlansListView.deletePlans`).
    ///   shortcut: der in-flight Item-Swap (alte MealItems zum Loeschen
    ///   markiert, neue eingefuegt, Datum/Typ geaendert) bleibt im Context
    ///   unkommittiert stehen statt feldgenau zurueckgedreht zu werden —
    ///   kein Test deckt diesen Pfad ab; Upgrade falls noetig: Original-
    ///   werte vor der Mutation sichern und im Fehlerfall manuell restaurieren.
    @discardableResult
    public func save(
        into context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) -> Result<Void, Error> {
        if didSaveSuccessfully {
            return .success(())
        }

        if let originalMealID {
            guard let meal = context.model(for: originalMealID) as? MealEntry else {
                return .failure(MealDraftError.originalMealMissing)
            }
            // Vor jeder Aenderung einsammeln: `meal.items` wuerde nach dem
            // Einfuegen der neuen MealItems (gleiche Inverse-Relationship)
            // auch diese enthalten.
            let oldItems = meal.items
            meal.date = date
            meal.mealType = mealType
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
            }
            for oldItem in oldItems {
                context.delete(oldItem)
            }

            do {
                try persist(context)
                didSaveSuccessfully = true
                return .success(())
            } catch {
                return .failure(error)
            }
        }

        let meal = MealEntry(date: date, mealType: mealType)
        context.insert(meal)
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
        }

        do {
            try persist(context)
            didSaveSuccessfully = true
            return .success(())
        } catch {
            // Rollback: MealEntry.items hat die Cascade-Delete-Rule (siehe
            // MealEntry-Doku), das reisst die eingefuegten MealItems mit.
            context.delete(meal)
            return .failure(error)
        }
    }
}

/// Fehler, die nur im Edit-Pfad von `MealDraft.save` auftreten koennen.
public enum MealDraftError: Error {
    /// Die `MealEntry`, aus der dieser Entwurf per `init(editing:)` gebaut
    /// wurde, existiert im uebergebenen Context nicht mehr (z.B. zwischen-
    /// zeitlich geloescht).
    case originalMealMissing
}
#endif
