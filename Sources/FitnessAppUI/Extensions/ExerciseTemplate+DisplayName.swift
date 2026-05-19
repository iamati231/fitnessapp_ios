#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import FitnessAppCore
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

/// Plan-Side Exercise.
///
/// **DEL-118-Update:** Beim Plan-Adopt wird nur der rohe DE-`name` als
/// Snapshot ins SwiftData-Modell geschrieben (kein `localizationKey`-
/// Feld, das vor DEL-118 nicht existierte). Damit Dashboard, History und
/// Plan-Detail die geadoptierten Uebungen trotzdem multilingual rendern,
/// macht `displayName` einen Library-Lookup ueber den DE-Namen:
///
///   1. Wenn `name` einer ExerciseLibraryData.all-Eintrag matcht UND
///      dort ein `localizationKey` annotiert ist → Catalog-Resolution.
///   2. Sonst Fallback auf das rohe `name`-Feld. Das deckt:
///      - Custom-User-Uebungen (nie in der Library)
///      - User-Renamen nach dem Plan-Adopt
///      - Library-Eintraege ohne Annotation (defensiv — DEL-113 hat alle
///        119 Eintraege durch annotiert, der Pfad sollte nicht greifen).
///
/// Performance-Hinweis: `ExerciseLibraryData.all.first(where:)` ist O(n)
/// pro Aufruf bei n≈123. Hot-paths (Dashboard-Plan-Vorschau, History)
/// rendern max. ~10 Uebungen pro Frame → vernachlaessigbar. Bei Bedarf
/// later via `static let nameToKeyMap: [String: String]` cachen.
extension Exercise {
    public var displayName: String {
        if let entry = ExerciseLibraryData.all.first(where: { $0.name == name }),
           let key = entry.localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }
}
#endif
