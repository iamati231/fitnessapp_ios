#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftUI
import FitnessAppData

/// DEL-123: Lokalisierter Display-Name fuer SwiftData-`TrainingDay`.
///
/// Identisches Pattern wie `TrainingPlan.displayName`. Catalog-Lookup wenn
/// `localizationKey` gesetzt (geadoptete Template-Tage, und seit DEL-247
/// auch geadoptete "Plan bauen"-Tage), sonst Fallback auf `name`. Custom-Tage
/// und Legacy-Daten zeigen weiterhin ihre rohen (vermutlich deutschen)
/// Namen. Key-Aufloesung (inkl. der DEL-247-Zusammensetzung) via
/// `resolveDayLocalizationKey` in `DaySpec+DisplayName.swift`.
extension TrainingDay {
    public var displayName: String {
        // DEL-125: User-Custom-Override gewinnt.
        if let custom = customName, !custom.isEmpty {
            return custom
        }
        if let key = localizationKey, !key.isEmpty {
            return resolveDayLocalizationKey(key)
        }
        return name
    }

    /// DEL-125: nur der lokalisierte System-Name (TextField-Placeholder).
    public var localizedSystemName: String {
        if let key = localizationKey, !key.isEmpty {
            return resolveDayLocalizationKey(key)
        }
        return name
    }
}
#endif
