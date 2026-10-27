// ─────────────────────────────────────────────────────────────────────────────
// Research basis (checked 2026-10-27, live requests against the production
// Product Opener API — the brief asked to verify this before writing the
// Decodable types below, same discipline as OnlineFoodSearchClient.swift):
//
//   curl -G "https://world.openfoodfacts.org/api/v2/product/3017620422003.json" \
//     --data-urlencode "fields=code,status,product_name,brands,nutriments" \
//     -H "User-Agent: FitnessAppResearch/0.1 (a.isik@atamya.com)"
//
// Result: HTTP 200, `{"code":"3017620422003","product":{"brands":"Nutella,
// Ferrero","code":"3017620422003","nutriments":{"energy-kcal_100g":539,
// "proteins_100g":6.3,"carbohydrates_100g":57.5,"fat_100g":30.9,...},
// "product_name":"Nutella"},"status":1,"status_verbose":"product found"}`.
//
//   - Top level: `code`, `status` (1 == found), `status_verbose`, `product`.
//     `product` is ABSENT when `status == 0`.
//   - `product.brands` is a single comma-joined STRING here ("Nutella,
//     Ferrero") — NOT an array like the search endpoint's `hits[].brands`.
//     Different endpoint, different shape; must not reuse the search
//     endpoint's `Hit` type.
//   - `product.nutriments` uses the SAME key names as the search endpoint
//     (`energy-kcal_100g`, `proteins_100g`, `carbohydrates_100g`,
//     `fat_100g`), confirmed identical in this response.
//
// Unknown/unassigned barcode (random 13-digit code, verified via
// PowerShell Invoke-WebRequest since curl was unavailable in that shell):
//   GET .../api/v2/product/0238954471860.json
//   -> HTTP 404, body {"code":"0238954471860","status":0,
//      "status_verbose":"product not found"}
// Conclusion: HTTP 404 is the reliable "not found" signal; `status == 0`/
// missing `product` is the defensive body-level fallback for any other
// 2xx-with-status-0 response shape.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Abstraction over "look up one Open Food Facts product by its exact
/// barcode" (Product Opener API), separate from `OnlineFoodSearching`
/// (free-text Search-a-licious API) — different endpoint, different
/// response shape, same error vocabulary and User-Agent discipline.
public protocol OnlineFoodBarcodeLookup: Sendable {
    /// - Parameter barcode: the scanned code, passed through VERBATIM as a
    ///   `String` — never parsed as a number, so a leading zero (common in
    ///   EAN-8/UPC-A codes) is never silently dropped.
    /// - Throws: `OnlineFoodSearchError`, never a raw `URLError`/`DecodingError`.
    func lookup(barcode: String) async throws -> OnlineFoodCandidate
}

/// Talks to the Open Food Facts "Product Opener" API
/// (`https://world.openfoodfacts.org/api/v2/product/{barcode}.json`).
public struct OpenFoodFactsBarcodeLookupClient: OnlineFoodBarcodeLookup {
    private static let noNetworkCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .dnsLookupFailed
    ]

    private let userAgent: String
    private let urlSession: URLSession

    /// - Parameter userAgent: sent verbatim as the `User-Agent` header, same
    ///   format Open Food Facts requires for `OpenFoodFactsSearchClient`.
    public init(userAgent: String) {
        self.init(userAgent: userAgent, urlSession: URLSession(configuration: .ephemeral))
    }

    /// Test seam, same purpose as `OpenFoodFactsSearchClient`'s.
    init(userAgent: String, urlSession: URLSession) {
        self.userAgent = userAgent
        self.urlSession = urlSession
    }

    public func lookup(barcode: String) async throws -> OnlineFoodCandidate {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        // EAN-13/EAN-8/UPC are digits-only by construction (the scanner is
        // restricted to those symbologies) — reject anything else before it
        // ever reaches a URL path, rather than trusting scanner output.
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else {
            throw OnlineFoodSearchError.invalidResponse
        }
        guard var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json") else {
            throw OnlineFoodSearchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "fields", value: "code,status,product_name,brands,nutriments")
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
        // Confirmed live: an unknown barcode is HTTP 404, not a 200 with an
        // empty body — checked before the generic 2xx gate below.
        if httpResponse.statusCode == 404 {
            throw OnlineFoodSearchError.noResults
        }
        if httpResponse.statusCode == 503 {
            throw OnlineFoodSearchError.rateLimited
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OnlineFoodSearchError.invalidResponse
        }

        let decoded: ProductResponse
        do {
            decoded = try JSONDecoder().decode(ProductResponse.self, from: data)
        } catch {
            throw OnlineFoodSearchError.invalidResponse
        }

        guard decoded.status == 1, let product = decoded.product else {
            throw OnlineFoodSearchError.noResults
        }
        // A product the API considers "found" but with no usable name is
        // incomplete data, not "not found" — distinct failure mode so the UI
        // isn't told "no product" when one technically exists.
        guard let candidate = product.toCandidate(code: decoded.code ?? trimmed) else {
            throw OnlineFoodSearchError.invalidResponse
        }
        return candidate
    }
}

private struct ProductResponse: Decodable {
    let code: String?
    let status: Int?
    let product: Product?
}

private struct Product: Decodable {
    let productName: String?
    let brands: String?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
    }

    func toCandidate(code: String) -> OnlineFoodCandidate? {
        guard let name = productName, !name.isEmpty else { return nil }
        let trimmedBrands = brands?.trimmingCharacters(in: .whitespacesAndNewlines)
        return OnlineFoodCandidate(
            id: code,
            name: name,
            brand: (trimmedBrands?.isEmpty ?? true) ? nil : trimmedBrands,
            kcalPer100g: nutriments?.kcalPer100g,
            proteinPer100g: nutriments?.proteins100g,
            carbsPer100g: nutriments?.carbohydrates100g,
            fatPer100g: nutriments?.fat100g
        )
    }
}

/// Same field set/semantics as `OnlineFoodSearchClient.swift`'s private
/// `Nutriments` — duplicated rather than shared, since the two live in
/// different files with independent response-decoding lifecycles and the
/// type itself is ~10 lines.
private struct Nutriments: Decodable {
    let energyKcal100g: Double?
    let energyKj100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKj100g = "energy-kj_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }

    var kcalPer100g: Double? {
        energyKcal100g ?? energyKj100g.map { $0 / 4.184 }
    }
}
