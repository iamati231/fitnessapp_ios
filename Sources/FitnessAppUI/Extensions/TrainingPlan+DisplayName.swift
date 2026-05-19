#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftUI
import FitnessAppData

/// DEL-123: Lokalisierter Display-Name fuer SwiftData-`TrainingPlan`.
///
/// Vertrag analog zu `ProgramTemplate.displayName` aus DEL-115:
///   * Wenn `localizationKey` non-nil + non-empty (geadoptete Templates
///     ab DEL-123), wird der Catalog-Eintrag aufgeloest. Multilinguales
///     Rendering.
///   * Sonst Fallback auf rohes `name`-Feld. Das deckt:
///     - Custom-User-Plaene (kein Template-Origin)
///     - Legacy-Daten (Plaene adopted vor DEL-123) — die zeigen weiterhin
///       den deutschen Snapshot bis der User den Plan re-adopted ODER
///       wir einen Backfill-Pass implementieren (LibrarySeeder-style).
///   * User-renamen ueberschreiben `name`, behalten aber `localizationKey`
///     — Plan-Display nimmt dann den Lookup-Wert. Wenn das fuer den User
///     verwirrend ist (er hat ja explizit umbenannt), waere das ein
///     separates Ticket: localizationKey nach User-Rename loeschen.
extension TrainingPlan {
    public var displayName: String {
        if let key = localizationKey, !key.isEmpty {
            return String(localized: String.LocalizationValue(key), bundle: .module)
        }
        return name
    }
}
#endif
