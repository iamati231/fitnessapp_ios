import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import FitnessAppFoodLookup

/// Intercepts every request the client's `URLSession` makes, so these tests
/// never touch the real network. `requestHandler` is static because
/// `URLProtocol` instances are created by the URL loading system itself (no
/// way to inject per-instance state) — fine as long as XCTest runs these
/// tests serially, which is the default.
private final class MockURLProtocol: URLProtocol {
    static var requestHandler: (@Sendable (URLRequest) -> (HTTPURLResponse?, Data?, Error?))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data, error) = handler(request)
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class OnlineFoodSearchClientTests: XCTestCase {

    private func makeClient() -> OpenFoodFactsSearchClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return OpenFoodFactsSearchClient(userAgent: "FitnessAppTests/1 (test@example.com)", urlSession: URLSession(configuration: config))
    }

    private func stub(status: Int, body: Data) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)
            return (response, body, nil)
        }
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: Success, full nutrients

    func test_search_withFullNutrients_mapsAllFields() async throws {
        let json = """
        {"hits":[{"code":"0013402060046","brands":["Nutella"],"product_name":"Nutella",
        "nutriments":{"energy-kcal_100g":539,"proteins_100g":6.3,"carbohydrates_100g":57.5,"fat_100g":30.9}}]}
        """
        stub(status: 200, body: Data(json.utf8))

        let result = try await makeClient().search(query: "nutella", locale: Locale(identifier: "de_DE"), page: 1)

        XCTAssertEqual(result.candidates.count, 1)
        let candidate = result.candidates[0]
        XCTAssertEqual(candidate.id, "0013402060046")
        XCTAssertEqual(candidate.name, "Nutella")
        XCTAssertEqual(candidate.brand, "Nutella")
        XCTAssertEqual(candidate.kcalPer100g, 539)
        XCTAssertEqual(candidate.proteinPer100g, 6.3)
        XCTAssertEqual(candidate.carbsPer100g, 57.5)
        XCTAssertEqual(candidate.fatPer100g, 30.9)
    }

    // MARK: Partial nutrients -> nil, not 0

    func test_search_withMissingProtein_mapsToNilNotZero() async throws {
        let json = """
        {"hits":[{"code":"123","product_name":"Mystery Bar",
        "nutriments":{"energy-kcal_100g":400,"carbohydrates_100g":50,"fat_100g":10}}]}
        """
        stub(status: 200, body: Data(json.utf8))

        let result = try await makeClient().search(query: "mystery", locale: Locale(identifier: "en_US"), page: 1)

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertNil(result.candidates[0].proteinPer100g)
        XCTAssertEqual(result.candidates[0].kcalPer100g, 400)
    }

    func test_search_withNoNutrimentsObjectAtAll_mapsAllNutrientsToNil() async throws {
        let json = """
        {"hits":[{"code":"456","product_name":"No Data Product"}]}
        """
        stub(status: 200, body: Data(json.utf8))

        let result = try await makeClient().search(query: "nodata", locale: Locale(identifier: "en_US"), page: 1)

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertNil(result.candidates[0].kcalPer100g)
        XCTAssertNil(result.candidates[0].proteinPer100g)
        XCTAssertNil(result.candidates[0].carbsPer100g)
        XCTAssertNil(result.candidates[0].fatPer100g)
        XCTAssertNil(result.candidates[0].brand)
    }

    // MARK: kJ-only energy -> converted to kcal, not nil

    func test_search_withOnlyEnergyKj_fallsBackToConvertedKcal() async throws {
        let json = """
        {"hits":[{"code":"789","product_name":"KJ Only Product",
        "nutriments":{"energy-kj_100g":1673,"proteins_100g":5,"carbohydrates_100g":20,"fat_100g":3}}]}
        """
        stub(status: 200, body: Data(json.utf8))

        let result = try await makeClient().search(query: "kjonly", locale: Locale(identifier: "en_US"), page: 1)

        XCTAssertEqual(result.candidates.count, 1)
        // 1673 kJ / 4.184 ≈ 399.86 kcal
        XCTAssertEqual(result.candidates[0].kcalPer100g ?? -1, 399.86, accuracy: 0.1)
    }

    func test_search_withBothEnergyKcalAndKj_usesKcalAsIsNotKj() async throws {
        let json = """
        {"hits":[{"code":"790","product_name":"Both Energy Product",
        "nutriments":{"energy-kcal_100g":400,"energy-kj_100g":9999,"proteins_100g":5,"carbohydrates_100g":20,"fat_100g":3}}]}
        """
        stub(status: 200, body: Data(json.utf8))

        let result = try await makeClient().search(query: "bothenergy", locale: Locale(identifier: "en_US"), page: 1)

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].kcalPer100g, 400)
    }

    // MARK: Empty hits -> noResults (first page only)

    func test_search_withEmptyHits_throwsNoResults() async throws {
        stub(status: 200, body: Data(#"{"hits":[]}"#.utf8))

        do {
            _ = try await makeClient().search(query: "zzzznonexistent", locale: Locale(identifier: "en_US"), page: 1)
            XCTFail("expected noResults")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .noResults)
        }
    }

    // MARK: HTTP 503 -> rateLimited

    func test_search_withHTTP503_throwsRateLimited() async throws {
        stub(status: 503, body: Data())

        do {
            _ = try await makeClient().search(query: "nutella", locale: Locale(identifier: "en_US"), page: 1)
            XCTFail("expected rateLimited")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .rateLimited)
        }
    }

    // MARK: No network -> noNetwork

    func test_search_withNoNetwork_throwsNoNetwork() async throws {
        MockURLProtocol.requestHandler = { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }

        do {
            _ = try await makeClient().search(query: "nutella", locale: Locale(identifier: "en_US"), page: 1)
            XCTFail("expected noNetwork")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .noNetwork)
        }
    }

    // MARK: Invalid JSON -> invalidResponse, no crash

    func test_search_withInvalidJSON_throwsInvalidResponse() async throws {
        stub(status: 200, body: Data("not json at all".utf8))

        do {
            _ = try await makeClient().search(query: "nutella", locale: Locale(identifier: "en_US"), page: 1)
            XCTFail("expected invalidResponse")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    // MARK: Pagination — Test 1: first page uses expected request parameters

    func test_search_firstPage_usesExpectedQueryParametersAndRespectsPageCount() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            let json = #"{"hits":[{"code":"1","product_name":"A"}],"page":1,"page_count":3}"#
            return (response, Data(json.utf8), nil)
        }

        let result = try await makeClient().search(query: "milch", locale: Locale(identifier: "de_DE"), page: 1)

        let url = try XCTUnwrap(capturedURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "1")
        XCTAssertEqual(items.first(where: { $0.name == "page_size" })?.value, "20")
        XCTAssertEqual(items.first(where: { $0.name == "q" })?.value, "milch")
        XCTAssertTrue(result.hasMore, "page 1 of 3 muss weitere Seiten melden")
        XCTAssertEqual(result.page, 1)
    }

    // MARK: Pagination — Test 2: load-more requests the next page number

    func test_search_loadMore_requestsNextPageNumber() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            let json = #"{"hits":[{"code":"2","product_name":"B"}],"page":2,"page_count":2}"#
            return (response, Data(json.utf8), nil)
        }

        let result = try await makeClient().search(query: "milch", locale: Locale(identifier: "de_DE"), page: 2)

        let url = try XCTUnwrap(capturedURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "2")
        XCTAssertEqual(result.candidates.count, 1)
    }

    // MARK: Pagination — Test 4: last page (page == page_count) reports hasMore == false

    func test_search_lastPage_reportsHasMoreFalse() async throws {
        stub(status: 200, body: Data(#"{"hits":[{"code":"2","product_name":"B"}],"page":2,"page_count":2}"#.utf8))

        let result = try await makeClient().search(query: "milch", locale: Locale(identifier: "en_US"), page: 2)

        XCTAssertFalse(result.hasMore)
    }

    // MARK: Pagination — Test 7: missing/incomplete metadata doesn't crash or loop forever

    func test_search_withMissingPageCountMetadata_fallsBackToPageSizeHeuristicWithoutCrashing() async throws {
        let json = """
        {"hits":[{"code":"1","product_name":"A"},{"code":"2","product_name":"B"}]}
        """
        stub(status: 200, body: Data(json.utf8))

        let result = try await makeClient().search(query: "milch", locale: Locale(identifier: "en_US"), page: 1)

        XCTAssertEqual(result.candidates.count, 2)
        // 2 hits < the 20-item page size -> treated as the last page, never
        // an infinite "maybe more" that a caller could loop on forever.
        XCTAssertFalse(result.hasMore)
    }

    // MARK: Pagination — a second page with no hits ends pagination instead of throwing noResults

    func test_search_secondPageWithEmptyHits_returnsEmptyPageInsteadOfThrowing() async throws {
        stub(status: 200, body: Data(#"{"hits":[],"page":2,"page_count":2}"#.utf8))

        let result = try await makeClient().search(query: "milch", locale: Locale(identifier: "en_US"), page: 2)

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertFalse(result.hasMore)
    }
}
