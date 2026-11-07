import Foundation

/// Laedt und cached die lokale Rezeptdatenbank aus `recipes.json`.
/// Analoges Muster zu `FoodCatalogData` — JSON-basiert statt Swift-Literale,
/// damit neue Rezepte ohne Neucompilierung via App-Update rollbar sind.
public enum RecipeCatalogData {
    /// Alle Rezepte aus der mitgelieferten `recipes.json`.
    /// Leer (kein Crash) wenn die Datei fehlt oder nicht dekodierbar ist.
    public static let all: [Recipe] = load()

    private static func load() -> [Recipe] {
        guard let url = Bundle.module.url(forResource: "recipes", withExtension: "json") else {
            assertionFailure("recipes.json nicht im Bundle — fehlt .process(\"Resources\") in Package.swift?")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(RecipeFileCatalog.self, from: data)
            return catalog.recipes
        } catch {
            assertionFailure("recipes.json konnte nicht dekodiert werden: \(error)")
            return []
        }
    }
}

private struct RecipeFileCatalog: Codable {
    let schemaVersion: Int
    let recipes: [Recipe]
}
