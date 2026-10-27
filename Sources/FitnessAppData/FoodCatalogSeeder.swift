#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Seeds the `FoodCatalogEntry` table with the canonical entries from
/// `FoodCatalogData`. Idempotent: skips if any entry already exists.
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

    /// UX-Katalog-Erweiterung: additives Backfill fuer System-Katalogeintraege,
    /// die NACH dem ersten Seed zu `FoodCatalogData.all` hinzugekommen sind
    /// (z.B. der 2026-10-Katalogausbau von 130 auf 234 Eintraege) — der oben
    /// dokumentierte `seedIfNeeded`-Shortcut war genau dieser Fall: ohne
    /// diesen Backfill bleibt jeder Bestandsnutzer dauerhaft auf 130
    /// Eintraegen stehen, weil `seedIfNeeded`'s Leer-Check fuer immer `false`
    /// liefert. Gleiches Diff-Backfill-Muster wie
    /// `LibrarySeeder.backfillNewLibraryEntriesIfNeeded` — Diff gegen die
    /// bereits persistierten `catalogID`s der `.seeded`-Eintraege (nicht ALLE
    /// Eintraege: `.onlineImported`/`.userCreated`-Zeilen tragen keine
    /// `FoodCatalogData`-ID und wuerden den Diff sonst verfaelschen).
    ///
    /// Returns: Anzahl der nachgezogenen Eintraege.
    @discardableResult
    public static func backfillNewCatalogEntriesIfNeeded(in context: ModelContext) -> Int {
        let seededRaw = FoodCatalogEntrySource.seeded.rawValue
        let descriptor = FetchDescriptor<FoodCatalogEntry>(predicate: #Predicate { $0.sourceRaw == seededRaw })
        // Wie bei `seedIfNeeded`: ein fehlgeschlagener Fetch darf nicht als
        // "keine IDs vorhanden" gelten, sonst wuerde der GESAMTE Katalog
        // faelschlich erneut eingefuegt (Duplikate).
        let existingEntries: [FoodCatalogEntry]
        do {
            existingEntries = try context.fetch(descriptor)
        } catch {
            return 0
        }
        let existingIDs = Set(existingEntries.map(\.catalogID))

        var added = 0
        for item in FoodCatalogData.all where !existingIDs.contains(item.id) {
            context.insert(FoodCatalogEntry(from: item))
            added += 1
        }
        return added
    }
}
#endif
