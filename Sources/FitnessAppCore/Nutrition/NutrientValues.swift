import Foundation

/// Ein einzelner Naehrwert eines Eintrags — **bekannt oder unbekannt**.
///
/// Audit docs/AUDIT_2026-10-23_DELTIQ.md, Befund OFF-01: Open Food Facts ist
/// eine Community-Datenbank, einzelne Makros fehlen dort regelmaessig. Ein
/// fehlender Wert ist unbekannt und NICHT null — „0 g Fett" ist eine Aussage
/// ueber das Lebensmittel, „Fett unbekannt" eine andere. Dieses Enum macht
/// das an der Datengrenze explizit, damit nirgends ein `?? 0` entstehen kann.
public enum KnownValue: Sendable, Codable, Equatable {
    case known(Double)
    case unknown

    public init(_ value: Double?) {
        if let value {
            self = .known(value)
        } else {
            self = .unknown
        }
    }

    public var value: Double? {
        if case .known(let value) = self { return value }
        return nil
    }

    public var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }
}

/// OFF-01: gemeinsame Bitzmaske fuer die drei Stellen, die unbekannte Werte
/// persistieren oder aus einem Backup lesen (`FoodCatalogEntry`,
/// `MealItem`, `DataImportService`). Bit 0 = kcal, 1 = Protein,
/// 2 = Kohlenhydrate, 3 = Fett.
public extension KnownValue {
    /// Alle vier Werte bekannt — der Default jeder additiv hinzugefuegten
    /// Maske, damit Bestandsdaten unveraendert als "bekannt" gelesen werden.
    static let allKnownMask = 0b1111

    static func mask(kcal: Bool, protein: Bool, carbs: Bool, fat: Bool) -> Int {
        (kcal ? 1 : 0) | (protein ? 2 : 0) | (carbs ? 4 : 0) | (fat ? 8 : 0)
    }
}

/// Naehrwerte einer Menge (z. B. "200 g Haehnchenbrust"). Reiner Daten-
/// Container — exakte, ungerundete `Double`-Werte; Rundung/Truncate passiert
/// erst bei der Anzeige (siehe `DoubleFormatting.swift`).
///
/// Seit OFF-01 kann ein einzelner Wert `unknown` sein (fehlender
/// Open-Food-Facts-Wert). Die Rechenregeln sind bewusst konservativ:
/// - `sum`: eine Summe ist nur dann bekannt, wenn ALLE Summanden es sind
///   (unbekannt + 0 ist weiterhin unbekannt). Ein Tag mit einer Position
///   ohne Fett-Wert zeigt fuer Fett „-" statt einer zu kleinen Zahl.
/// - `partiallyKnown`: mindestens ein Wert in mindestens einer Position ist
///   unbekannt. Die UI kennzeichnet damit Tagessummen als unvollstaendig.
public struct NutrientValues: Sendable, Codable, Equatable {
    public let kcal: KnownValue
    public let proteinG: KnownValue
    public let carbsG: KnownValue
    public let fatG: KnownValue

    public init(kcal: KnownValue, proteinG: KnownValue, carbsG: KnownValue, fatG: KnownValue) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }

    /// Alle vier Werte bekannt — der Normalfall (Katalog, eigene Lebensmittel,
    /// KI-Extraktion rechnet nie mit fehlenden Werten).
    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double) {
        self.init(kcal: KnownValue(kcal), proteinG: KnownValue(proteinG), carbsG: KnownValue(carbsG), fatG: KnownValue(fatG))
    }

    /// Gemischter Fall: einzelne Werte koennen fehlen (`nil`), z. B. aus
    /// Open Food Facts. `nil` wird zu `.unknown`, nie zu `0`.
    public init(kcal: Double?, proteinG: Double?, carbsG: Double?, fatG: Double?) {
        self.init(kcal: KnownValue(kcal), proteinG: KnownValue(proteinG), carbsG: KnownValue(carbsG), fatG: KnownValue(fatG))
    }

    public static let zero = NutrientValues(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

    /// `true`, sobald mindestens ein Wert unbekannt ist.
    public var partiallyKnown: Bool {
        kcal.isUnknown || proteinG.isUnknown || carbsG.isUnknown || fatG.isUnknown
    }

    /// Summe aller Positionen. Ein Wert bleibt unbekannt, sobald ER in
    /// irgendeiner Position unbekannt ist (`allKnownOrUnknown` unten) —
    /// fehlende Werte werden nie als 0 in die Summe eingerechnet.
    public static func sum(_ values: [NutrientValues]) -> NutrientValues {
        NutrientValues(
            kcal: allKnownOrUnknown(values.map(\.kcal)),
            proteinG: allKnownOrUnknown(values.map(\.proteinG)),
            carbsG: allKnownOrUnknown(values.map(\.carbsG)),
            fatG: allKnownOrUnknown(values.map(\.fatG))
        )
    }

    /// Wertet ein „skaliert auf 0 Mengeneinheiten"-Ergebnis ein: bei
    /// `faktor == 0` ist jeder Naehrwert fachlich 0 (auch bei unbekanntem
    /// Wert pro 100 g) — 0 g eines Lebensmittels enthalten 0 g Fett,
    /// unabhaengig davon, ob der Gehalt pro 100 g bekannt ist.
    static func scaled(_ value: KnownValue, by factor: Double) -> KnownValue {
        if factor == 0 { return .known(0) }
        switch value {
        case .known(let amount):
            return .known(amount * factor)
        case .unknown:
            return .unknown
        }
    }

    private static func allKnownOrUnknown(_ values: [KnownValue]) -> KnownValue {
        var total = 0.0
        for value in values {
            switch value {
            case .known(let amount):
                total += amount
            case .unknown:
                return .unknown
            }
        }
        return .known(total)
    }
}

/// OFF-01: Liest einen einzelnen Naehrwert aus einer Backup-Zeile, wobei die
/// additive Bitzmaske entscheidet, ob der gespeicherte Wert Inhalt ist oder
/// nur der Platzhalter eines unbekannten Werts. Bewusst hier in Core, damit
/// `DataImportService` (Data) keine eigene CSV-Sonderlogik braucht und die
/// Regel zusammen mit dem Typ an einer Stelle steht.
public enum NutrientsImport {
    /// - Parameters:
    ///   - bit: das Bit dieser Dimension in `mask` (1, 2, 4 oder 8).
    ///   - mask: Wert der Spalte `known_nutrients`; `KnownValue.allKnownMask`,
    ///     wenn die Spalte fehlt (Backup von vor OFF-01).
    public static func value(
        _ row: CSVRow,
        key: String,
        bit: Int,
        mask: Int
    ) -> KnownValue {
        guard (mask & bit) != 0 else { return .unknown }
        guard let amount = row.double(key) else { return .unknown }
        return .known(amount)
    }
}
