import Foundation

/// Naehrwerte einer Menge (z. B. "200 g Haehnchenbrust"). Reiner Daten-
/// Container — exakte, ungerundete `Double`-Werte; Rundung/Truncate passiert
/// erst bei der Anzeige (siehe `DoubleFormatting.swift`).
public struct NutrientValues: Sendable, Codable, Equatable {
    public let kcal: Double
    public let proteinG: Double
    public let carbsG: Double
    public let fatG: Double

    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }

    public static let zero = NutrientValues(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

    public static func sum(_ values: [NutrientValues]) -> NutrientValues {
        values.reduce(.zero) { partial, value in
            NutrientValues(
                kcal: partial.kcal + value.kcal,
                proteinG: partial.proteinG + value.proteinG,
                carbsG: partial.carbsG + value.carbsG,
                fatG: partial.fatG + value.fatG
            )
        }
    }
}
