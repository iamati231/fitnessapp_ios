import Foundation

/// Allergene nach EU-LMIV (14 Hauptallergene).
/// Ein Rezept traegt jeden Allergen den es enthaelt — aber NUR wenn
/// `Recipe.allergenVerified == true`. Ist dieser Wert `false`, gilt der
/// Allergen-Status als unbekannt: bei aktivierten Ausschluessen muss das
/// Rezept sicher herausgefiltert werden, unabhaengig von diesem Array.
public enum RecipeAllergen: String, Codable, Sendable, CaseIterable {
    case gluten
    case lactose
    /// Schalen- und Baumnuesse (ohne Erdnuesse).
    case nuts
    case peanuts
    case eggs
    case soy
    case fish
    case shellfish
    case sesame
    case celery
    case mustard
    case sulfites
    case lupin
    case molluscs
}
