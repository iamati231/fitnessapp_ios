#if canImport(SwiftUI)
import FitnessAppCore

/// OFF-01 (docs/AUDIT_2026-10-23_DELTIQ.md): Eine Stelle fuer die Anzeige von
/// Naehrwerten, die unbekannt sein koennen.
///
/// Regel: ein unbekannter Wert wird als „-" gezeigt — **nie** als 0, und nie
/// als leer (ein leeres Feld sieht wie ein Anzeigefehler aus). Bekannte
/// Werte behalten die bestehende Formatierung (`truncated(to:)` +
/// `formattedTwoDecimals`), damit sich ausserhalb des Unbekannt-Falls
/// nichts aendert.
@available(iOS 17.0, macOS 14.0, *)
public enum NutritionDisplay {

    /// Zeichen fuer „Wert unbekannt". Ein Gedankenstrich, keine 0.
    public static let unknownValue = "–"

    /// „150,00 g" oder „–" (ohne Einheit — eine Einheit an einem fehlenden
    /// Wert wuerde eine Genauigkeit vortaeuschen, die nicht existiert).
    public static func text(_ value: KnownValue, unit: String, decimals: Int = 2) -> String {
        guard let amount = value.value else { return unknownValue }
        return "\(amount.truncated(to: decimals).formattedTwoDecimals) \(unit)"
    }

    /// Nur der Zahlen-/Strich-Teil, fuer Stellen, die die Einheit selbst
    /// anhaengen (z. B. „– / 150 g").
    public static func text(_ value: KnownValue, decimals: Int = 2) -> String {
        guard let amount = value.value else { return unknownValue }
        return amount.truncated(to: decimals).formattedTwoDecimals
    }
}
#endif
