import Foundation

/// One Open-Food-Facts search hit, already mapped away from the raw JSON
/// shape. Nutrient fields are `nil` (never `0`) whenever Open Food Facts
/// doesn't have that value for the product — it's crowd-sourced data, so
/// gaps are common and must not be presented as "zero calories".
public struct OnlineFoodCandidate: Sendable, Equatable, Identifiable {
    /// Open Food Facts product barcode ("code"), or a generated UUID string
    /// when a hit has no code (keeps `Identifiable` usable either way).
    public let id: String
    public let name: String
    public let brand: String?
    public let kcalPer100g: Double?
    public let proteinPer100g: Double?
    public let carbsPer100g: Double?
    public let fatPer100g: Double?

    public init(
        id: String,
        name: String,
        brand: String?,
        kcalPer100g: Double?,
        proteinPer100g: Double?,
        carbsPer100g: Double?,
        fatPer100g: Double?
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
    }
}
