#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Seeds the `FoodCatalogEntry` table with the canonical entries from
/// `FoodCatalogData`. Idempotent: skips if any entry already exists.
///
/// shortcut: kein Backfill fuer spaeter zu FoodCatalogData.all hinzugefuegte
/// Eintraege (anders als LibrarySeeder.swift:82-100) — fuer v1 akzeptabel, da
/// ein kompletter leerer Katalog nur beim allerersten Start vorkommt; sobald
/// nach dem Release ein neuer Katalogeintrag ergaenzt wird, hier denselben
/// Diff-Backfill wie LibrarySeeder nachziehen.
@MainActor
public enum FoodCatalogSeeder {

    /// Returns true if the catalog was actually seeded (was empty before),
    /// false if it was already populated.
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext) -> Bool {
        // Ein fehlgeschlagener Fetch darf niemals als "leer" interpretiert
        // werden (gleiches Fehlerverhalten wie LibrarySeeder.seedIfNeeded) —
        // im Zweifel nichts tun, der naechste Start versucht es erneut.
        let existing: Int
        do {
            existing = try context.fetchCount(FetchDescriptor<FoodCatalogEntry>())
        } catch {
            return false
        }
        guard existing == 0 else { return false }

        for item in FoodCatalogData.all {
            context.insert(FoodCatalogEntry(from: item))
        }
        return true
    }
}
#endif
