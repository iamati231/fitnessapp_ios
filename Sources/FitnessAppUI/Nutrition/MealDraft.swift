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

    public init(date: Date, mealType: MealType) {
        self.date = date
        self.mealType = mealType
    }

    public func addItem(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues) {
        items.append(Item(catalogID: catalogID, nameSnapshot: nameSnapshot, quantity: quantity, unit: unit, nutrients: nutrients))
    }

    /// Summe aller Positionen — REIN lesend. Kein `ModelContext`-Zugriff,
    /// keine Seiteneffekte: das ist die gesamte Vorschau-Garantie.
    public var totalPreview: NutrientValues {
        NutrientValues.sum(items.map(\.nutrients))
    }

    /// Baut EINE `MealEntry` + ihre `MealItem`s und persistiert sie.
    ///
    /// - Doppeltap: Ist `didSaveSuccessfully` bereits `true`, wird sofort
    ///   `.success(())` zurueckgegeben, OHNE den Context erneut anzufassen —
    ///   das ist der vollstaendige Schutz, unabhaengig vom UI-Button-Zustand.
    /// - Erfolg: `didSaveSuccessfully = true`.
    /// - Fehler: die eingefuegte `MealEntry` (kaskadiert ihre Items) wird
    ///   wieder geloescht, `items`/`didSaveSuccessfully` bleiben unveraendert,
    ///   der Fehler geht als `.failure` zurueck — der Entwurf bleibt fuer
    ///   einen erneuten Versuch vollstaendig erhalten.
    @discardableResult
    public func save(
        into context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) -> Result<Void, Error> {
        if didSaveSuccessfully {
            return .success(())
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
#endif
