import Foundation

/// Laedt und cached die lokale Rezeptdatenbank aus `recipes.json`.
/// Analoges Muster zu `FoodCatalogData` — JSON-basiert statt Swift-Literale,
/// damit neue Rezepte ohne Neucompilierung via App-Update rollbar sind.
public enum RecipeCatalogData {
    /// Alle Rezepte aus der mitgelieferten `recipes.json`.
    /// Leer (kein Crash) wenn die Datei fehlt oder nicht dekodierbar ist.
    public static let all: [Recipe] = load()

    private static func load() -> [Recipe] {
        guard let url = Bundle.module.url(forResource: "recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(RecipeFileCatalog.self, from: data)
        else { return [] }
        return catalog.recipes
    }
}

private struct RecipeFileCatalog: Codable {
    let schemaVersion: Int
    let recipes: [Recipe]
}
