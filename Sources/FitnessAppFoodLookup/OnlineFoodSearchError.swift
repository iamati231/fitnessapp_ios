import Foundation

/// Every error `OnlineFoodSearching.search` can throw. Deliberately a small,
/// closed set — callers (UI) switch over this, never over `URLError`/`Error`
/// directly, so no network/decoding detail leaks past this module's boundary.
public enum OnlineFoodSearchError: Error, Sendable, Equatable {
    case noNetwork
    case rateLimited
    case noResults
    case invalidResponse
}
