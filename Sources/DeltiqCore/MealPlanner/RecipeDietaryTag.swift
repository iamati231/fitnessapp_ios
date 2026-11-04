import Foundation

/// Ernaehrungsweise-Qualifikation eines Rezepts.
/// Nur redaktionell gesetzt — KEINE automatische Ableitung aus Zutaten.
public enum RecipeDietaryTag: String, Codable, Sendable, CaseIterable {
    case vegan
    case vegetarian
    case pescetarian
    /// Enthält Schweinefleisch — bei aktivem Halal-Filter ausschließen.
    case containsPork
    /// Enthält Alkohol als Zutat — bei aktivem Halal-Filter ausschließen.
    case containsAlcohol
}
