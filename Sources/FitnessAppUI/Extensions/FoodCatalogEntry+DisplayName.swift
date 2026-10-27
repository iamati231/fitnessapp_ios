#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import FitnessAppData

/// writing-block.md Punkt 6 ("Lebensmittelname folgt nicht der aktuellen
/// App-Sprache"): catalog-based food names must re-render in whatever
/// language the app is currently running in, even for a meal logged weeks
/// ago in a different language — but a user-created or online-imported
/// name (free text, no catalog translation) must never be touched.
///
/// `FoodCatalogEntry.displayName` already distinguishes the two cases (see
/// its own doc comment) — `resolvedName(for:)` only has to read the right
/// field. The part that was missing: a SAVED `MealItem`/`MealDraft.Item`
/// freezes its catalog-resolved name into `nameSnapshot` at save time
/// (needed so historical nutrient/identity data survives a later catalog
/// change), and nothing ever re-resolved it afterwards — so a catalog-based
/// name stayed frozen in whatever language was active when it was logged,
/// exactly like `nameSnapshot` for workouts did before DEL-149's
/// `Exercise.resolvedDisplayName(forStoredName:)`. Unlike the exercise case,
/// a meal item already carries a stable `catalogID` (no name-based
/// reverse-lookup needed) — `resolvedMealItemName` just re-resolves through
/// the CURRENT catalog entry when one still exists for that ID.

/// Online-importierte/manuell angelegte Eintraege haben einen Klartext-Namen
/// statt eines xcstrings-Keys (kein Lokalisierungs-Key fuer vom Nutzer/einer
/// Online-Quelle stammenden Text) — der hat Vorrang vor `nameKey`.
public func resolvedName(for entry: FoodCatalogEntry) -> String {
    entry.displayName ?? String(localized: String.LocalizationValue(entry.nameKey), bundle: .module)
}

/// `catalogID` is `nil` for pre-OFF-01 legacy rows or if the matching
/// `FoodCatalogEntry` was since deleted — falls back to the frozen
/// `nameSnapshot` in both cases, exactly today's (pre-fix) behavior. When
/// the entry still exists, `resolvedName(for:)` already handles both the
/// catalog (locale-following) and user/online (frozen) cases correctly.
public func resolvedMealItemName(
    nameSnapshot: String,
    catalogID: String?,
    catalogEntries: [FoodCatalogEntry]
) -> String {
    guard let catalogID,
          let entry = catalogEntries.first(where: { $0.catalogID == catalogID })
    else { return nameSnapshot }
    return resolvedName(for: entry)
}
#endif
