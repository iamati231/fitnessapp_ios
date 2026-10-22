// ─────────────────────────────────────────────────────────────────────────────
// Research basis (checked 2026-10-22, live request against the production
// search API — the official OpenAPI 3.1.0 spec leaves every `hits[]` entry
// as an untyped `"type":"object"`, so this had to be verified against a real
// response before the Decodable types below could be written):
//
//   curl -G "https://search.openfoodfacts.org/search" \
//     --data-urlencode "q=nutella" --data-urlencode "page_size=1" \
//     --data-urlencode "langs=de" \
//     -H "User-Agent: FitnessAppResearch/0.1 (a.isik@atamya.com)"
//
// Result: HTTP 200. Top-level keys (confirms the planning doc's assumption):
//   hits, aggregations, facets, charts, page, page_size, page_count, debug,
//   took, timed_out, count, is_count_exact, warnings.
// One `hits[]` entry's keys (abbreviated to what matters here) included:
//   code, brands, product_name, product_name_<lang>, nutriments, plus a lot
//   of unrelated fields (images, ecoscore_data, nutriscore_*, categories_tags,
//   …) that this module ignores — Decodable silently skips unknown keys, so
//   nothing special is needed for that.
//   - `code`: String, the barcode, e.g. "0013402060046".
//   - `brands`: [String] (an ARRAY, not a single string) when present, e.g.
//     ["Nutella"]; can be ABSENT from a hit entirely.
//   - `product_name`: String when present; CAN BE ABSENT from a hit (seen on
//     a real hit in the same response) — never force-unwrapped here.
//   - `nutriments`: an object when present; the object itself can be ABSENT
//     from a hit (not `null`, just missing) when a product has no nutrient
//     data at all. Confirmed real key names exactly as assumed in the plan:
//       energy-kcal_100g, proteins_100g, carbohydrates_100g, fat_100g
//     (also saw sugars_100g, salt_100g, sodium_100g, saturated-fat_100g,
//     which this module doesn't need). Any of the four keys above can be
//     individually ABSENT from `nutriments` even when `nutriments` itself is
//     present (confirmed: a hit with `nutriments` had no `fat_100g`) — so
//     missing-field-in-a-present-object and missing-object-entirely both
//     decode the same way here: the corresponding `OnlineFoodCandidate`
//     property is `nil`, never `0`.
// Conclusion: every field this module reads from a hit is Optional in the
// Decodable types, with no `nutriments` sub-object ever force-unwrapped.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(FoundationNetworking)
// Linux/Windows swift-corelibs-foundation splits URLSession/HTTPURLResponse
// out of Foundation into this module; Apple platforms have them in Foundation.
import FoundationNetworking
#endif

/// Abstraction over "search Open Food Facts for a free-text query", so UI/AI
/// layers (Task 2+) can depend on this instead of `OpenFoodFactsSearchClient`
/// directly (fakeable in their own tests).
public protocol OnlineFoodSearching: Sendable {
    /// - Throws: `OnlineFoodSearchError`, never a raw `URLError`/`DecodingError`.
    func search(query: String, locale: Locale) async throws -> [OnlineFoodCandidate]
}

/// Talks to the Open Food Facts "Search-a-licious" API
/// (`https://search.openfoodfacts.org/search`, `GET`, free text via `q`).
public struct OpenFoodFactsSearchClient: OnlineFoodSearching {
    private static let searchURL = URL(string: "https://search.openfoodfacts.org/search")!
    // shortcut: fixed page size, no pagination support; revisit if a caller
    // ever needs more than the first page of results.
    private static let pageSize = 20
    // Connectivity-flavored URLError codes map to .noNetwork; anything else
    // network-ish (bad status, timeout aside) maps to .invalidResponse rather
    // than guessing at every possible URLError case.
    private static let noNetworkCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .dnsLookupFailed
    ]

    private let userAgent: String
    private let urlSession: URLSession

    /// - Parameter userAgent: sent verbatim as the `User-Agent` header. Open
    ///   Food Facts requires the `AppName/Version (ContactEmail)` format.
    public init(userAgent: String) {
        self.init(userAgent: userAgent, urlSession: URLSession(configuration: .ephemeral))
    }

    /// Test seam: lets `OnlineFoodSearchClientTests` inject a session backed
    /// by a mock `URLProtocol` instead of hitting the network.
    init(userAgent: String, urlSession: URLSession) {
        self.userAgent = userAgent
        self.urlSession = urlSession
    }

    public func search(query: String, locale: Locale) async throws -> [OnlineFoodCandidate] {
        guard var components = URLComponents(url: Self.searchURL, resolvingAgainstBaseURL: false) else {
            throw OnlineFoodSearchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "langs", value: locale.language.languageCode?.identifier ?? "en"),
            URLQueryItem(name: "page_size", value: String(Self.pageSize))
        ]
        guard let url = components.url else {
            throw OnlineFoodSearchError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError where Self.noNetworkCodes.contains(error.code) {
            throw OnlineFoodSearchError.noNetwork
        } catch {
            throw OnlineFoodSearchError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnlineFoodSearchError.invalidResponse
        }
        if httpResponse.statusCode == 503 {
            throw OnlineFoodSearchError.rateLimited
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OnlineFoodSearchError.invalidResponse
        }

        let decoded: SearchResponse
        do {
            decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw OnlineFoodSearchError.invalidResponse
        }

        guard !decoded.hits.isEmpty else {
            throw OnlineFoodSearchError.noResults
        }

        let candidates = decoded.hits.compactMap { $0.toCandidate() }
        guard !candidates.isEmpty else {
            throw OnlineFoodSearchError.noResults
        }
        return candidates
    }
}

/// `SuccessSearchResponse` as far as this module needs it.
private struct SearchResponse: Decodable {
    let hits: [Hit]
}

private struct Hit: Decodable {
    let code: String?
    let productName: String?
    let brands: [String]?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
    }

    func toCandidate() -> OnlineFoodCandidate? {
        guard let name = productName, !name.isEmpty else { return nil }
        let joinedBrand = brands?.joined(separator: ", ")
        return OnlineFoodCandidate(
            id: code ?? UUID().uuidString,
            name: name,
            brand: (joinedBrand?.isEmpty ?? true) ? nil : joinedBrand,
            kcalPer100g: nutriments?.energyKcal100g,
            proteinPer100g: nutriments?.proteins100g,
            carbsPer100g: nutriments?.carbohydrates100g,
            fatPer100g: nutriments?.fat100g
        )
    }
}

private struct Nutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}
