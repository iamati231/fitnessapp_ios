import Foundation

/// Mengen-Einheit fuer eine Nahrungsaufnahme (Spec 4.2). `.piece` und
/// `.milliliter` sind nur gueltig, wenn das jeweilige `FoodCatalogItem`
/// `pieceWeightGrams` bzw. `densityGramsPerMl` gesetzt hat — siehe
/// `FoodCatalogItem.supports(_:)`.
public enum FoodUnit: String, Codable, Sendable, CaseIterable {
    case gram
    case piece
    case milliliter
}
