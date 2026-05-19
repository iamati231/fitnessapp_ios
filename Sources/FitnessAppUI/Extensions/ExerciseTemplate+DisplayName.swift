#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import FitnessAppData

/// DEL-111: Lokalisierter Display-Name fuer Library-`ExerciseTemplate`s.
///
/// **Vertrag:**
///   * Wenn `localizationKey` non-nil ist (kanonische Library-Lifts mit
///     gepflegter DE/EN/TR-Übersetzung in `Localizable.xcstrings`), wird
///     der Catalog-Eintrag aufgelöst → multilinguale Anzeige.
///   * Sonst fällt es auf das rohe `name`-Feld zurück. Das deckt:
///     - Custom-User-Übungen (kein localizationKey)
///     - Library-Einträge ohne Übersetzungsannotation (noch deutsch,
///       siehe DEL-111-Scope: 13 kanonische Lifts in Wave 1)
///
/// **Wo aufrufen:** an JEDER UI-Surface, die einen Library-Template-Namen
/// anzeigt — ExercisePickerView, TemplatePreviewView, addExercise-Pfad
/// im DayEditor. Plan-Side-Exercises übernehmen den `displayName` als
/// Snapshot beim Picker-Pick.
extension ExerciseTemplate {
    public var displayName: String {
        if let key = localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }
}

/// Plan-Side Exercise hat keinen `localizationKey` (User-Custom-Renamen
/// sind möglich), aber der Display-Pfad nimmt einfach den `name`-Wert.
/// Diese Mirror-Property existiert nur für Call-Site-Symmetrie — UI-Code
/// kann `exercise.displayName` aufrufen, ohne zu wissen, ob Library- oder
/// Plan-Side.
extension Exercise {
    public var displayName: String { name }
}
#endif
