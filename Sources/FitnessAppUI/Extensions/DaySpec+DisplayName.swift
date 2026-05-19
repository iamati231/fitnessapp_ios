#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FitnessAppCore

/// DEL-115: Lokalisierter Display-Name fuer `DaySpec` (Tagesname innerhalb
/// eines `ProgramTemplate`).
///
/// **Vertrag:**
///   * Wenn `localizationKey` non-nil + non-empty ist (alle Shipped-Day-
///     Specs nach DEL-115), wird der Catalog-Eintrag aufgeloest
///     (`plan.day.<suffix>`) → multilinguale Anzeige.
///   * Sonst fällt es auf das rohe `name`-Feld zurueck. Das deckt:
///     - Custom-Tage in User-erstellten Plänen
///     - Day-Specs ohne Annotation (defensiv — sollte nach DEL-115 keinen
///       Library-Day-Spec mehr betreffen)
///
/// **Wo aufrufen:** Template-Picker-Day-Header in `TemplatePreviewView`,
/// `ProgramTemplatePickerView`. SwiftData-Side `TrainingDay`-Models nutzen
/// weiter `day.name` direkt — beim Adopt snapshotted, danach editierbar.
extension DaySpec {
    public var displayName: String {
        if let key = localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }
}
#endif
