#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FitnessAppCore

/// DEL-115: Lokalisierter Display-Name fuer `ProgramTemplate`.
///
/// **Vertrag (analog zu `ExerciseTemplate.displayName`):**
///   * Wenn `localizationKey` non-nil + non-empty ist (alle 14 Shipped-
///     Plan-Templates nach DEL-113), wird der Catalog-Eintrag aufgeloest
///     (`plan.template.<id>`) → multilinguale Anzeige.
///   * Sonst fällt es auf das rohe `name`-Feld zurueck. Custom-Pläne, die
///     der User selbst angelegt hat, haben keinen `localizationKey` und
///     bekommen ihren handgetippten Namen 1:1 angezeigt.
///
/// **Wo aufrufen:** an JEDER UI-Surface, die einen Template-Plan-Namen
/// anzeigt — `ProgramTemplatePickerView`, `OnboardingView`-Plan-Auswahl,
/// `TemplatePreviewView`, `DayPickerSheet`-Header. SwiftData-instanziierte
/// `TrainingPlan`-Rows zeigen weiterhin `plan.name` direkt — der Snapshot
/// erfolgt beim Adopt; spaetere Sprachumschaltung greift nur fuer
/// Template-Surfaces.
extension ProgramTemplate {
    public var displayName: String {
        if let key = localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }

    /// DEL-116: Lokalisierter Tagline-Helper.
    /// Vertrag analog zu `displayName` — Catalog-Lookup wenn Key gesetzt,
    /// sonst Fallback auf das rohe `tagline`-Feld.
    public var displayTagline: String {
        if let key = taglineKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return tagline
    }

    /// DEL-116: Lokalisierter Focus-Label-Helper.
    public var displayFocus: String {
        if let key = focusKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return focus
    }

    /// DEL-116: Lokalisierter Description-Helper.
    public var displayDescription: String {
        if let key = descriptionKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return descriptionText
    }
}
#endif
