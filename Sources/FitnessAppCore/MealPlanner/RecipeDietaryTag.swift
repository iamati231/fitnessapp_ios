import Foundation

/// Ernaehrungsweise-Qualifikation eines Rezepts.
/// Nur redaktionell gesetzt — KEINE automatische Ableitung aus Zutaten.
public enum RecipeDietaryTag: String, Codable, Sendable, CaseIterable {
    case vegan
    case vegetarian
    case pescetarian
}
