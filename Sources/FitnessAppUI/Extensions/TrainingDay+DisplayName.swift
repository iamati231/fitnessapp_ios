#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftUI
import FitnessAppData

/// DEL-123: Lokalisierter Display-Name fuer SwiftData-`TrainingDay`.
///
/// Identisches Pattern wie `TrainingPlan.displayName`. Catalog-Lookup wenn
/// `localizationKey` gesetzt (geadoptete Template-Tage), sonst Fallback
/// auf `name`. Custom-Tage und Legacy-Daten zeigen weiterhin ihre rohen
/// (vermutlich deutschen) Namen.
extension TrainingDay {
    public var displayName: String {
        if let key = localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }
}
#endif
