import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import FitnessAppFoodLookup

/// Same mock-`URLProtocol` approach as `OnlineFoodSearchClientTests` — own
/// copy per test file (each is `private`, no cross-file sharing needed), so
/// neither file's `requestHandler` state can leak into the other's run.
private final class MockBarcodeURLProtocol: URLProtocol {
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

final class OnlineFoodBarcodeLookupClientTests: XCTestCase {

    private func makeClient() -> OpenFoodFactsBarcodeLookupClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockBarcodeURLProtocol.self]
        return OpenFoodFactsBarcodeLookupClient(userAgent: "FitnessAppTests/1 (test@example.com)", urlSession: URLSession(configuration: config))
    }

    private func stub(status: Int, body: Data) {
        MockBarcodeURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)
            return (response, body, nil)
        }
    }

    override func tearDown() {
        MockBarcodeURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: Test 1: valid product response maps to a candidate

    func test_lookup_withFullProduct_mapsToCandidate() async throws {
        let json = """
        {"code":"3017620422003","status":1,"product":{"product_name":"Nutella","brands":"Nutella, Ferrero",
        "nutriments":{"energy-kcal_100g":539,"proteins_100g":6.3,"carbohydrates_100g":57.5,"fat_100g":30.9}}}
        """
        stub(status: 200, body: Data(json.utf8))

        let candidate = try await makeClient().lookup(barcode: "3017620422003")

        XCTAssertEqual(candidate.id, "3017620422003")
        XCTAssertEqual(candidate.name, "Nutella")
        XCTAssertEqual(candidate.brand, "Nutella, Ferrero")
        XCTAssertEqual(candidate.kcalPer100g, 539)
        XCTAssertEqual(candidate.proteinPer100g, 6.3)
        XCTAssertEqual(candidate.carbsPer100g, 57.5)
        XCTAssertEqual(candidate.fatPer100g, 30.9)
    }

    // MARK: Test 2: a barcode with a leading zero is transmitted unchanged

    func test_lookup_withLeadingZeroBarcode_usesItVerbatimInTheRequestURL() async throws {
        var capturedURL: URL?
        MockBarcodeURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            let json = #"{"code":"0048151623457","status":1,"product":{"product_name":"Padded Code Product"}}"#
            return (response, Data(json.utf8), nil)
        }

        let candidate = try await makeClient().lookup(barcode: "0048151623457")

        let url = try XCTUnwrap(capturedURL)
        XCTAssertTrue(url.path.contains("/0048151623457.json"), "die fuehrende Null darf nicht verloren gehen: \(url.path)")
        XCTAssertEqual(candidate.id, "0048151623457")
    }

    // MARK: Test 3: unknown product -> noResults, not a crash

    func test_lookup_withHTTP404_throwsNoResults() async throws {
        stub(status: 404, body: Data(#"{"code":"0238954471860","status":0,"status_verbose":"product not found"}"#.utf8))

        do {
            _ = try await makeClient().lookup(barcode: "0238954471860")
            XCTFail("expected noResults")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .noResults)
        }
    }

    func test_lookup_withStatusZeroBody_throwsNoResults() async throws {
        // Defensive fallback: a 2xx response that still reports status == 0
        // (e.g. an invalid/normalized code, confirmed live for "0000000000000")
        // must not be treated as a found product either.
        stub(status: 200, body: Data(#"{"code":"00000000","status":0,"status_verbose":"no code or invalid code"}"#.utf8))

        do {
            _ = try await makeClient().lookup(barcode: "0000000000000")
            XCTFail("expected noResults")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .noResults)
        }
    }

    // MARK: Test 4: partial/missing nutrients stay nil, never 0

    func test_lookup_withMissingNutriments_mapsAllNutrientsToNil() async throws {
        stub(status: 200, body: Data(#"{"code":"9999999999999","status":1,"product":{"product_name":"Salatgurke"}}"#.utf8))

        let candidate = try await makeClient().lookup(barcode: "9999999999999")

        XCTAssertNil(candidate.kcalPer100g)
        XCTAssertNil(candidate.proteinPer100g)
        XCTAssertNil(candidate.carbsPer100g)
        XCTAssertNil(candidate.fatPer100g)
        XCTAssertNil(candidate.brand)
    }

    func test_lookup_withFoundStatusButNoProductName_throwsInvalidResponse() async throws {
        // status == 1 (found) but the product has no usable name: incomplete
        // data, distinct from "not found" — see client doc comment.
        stub(status: 200, body: Data(#"{"code":"1","status":1,"product":{}}"#.utf8))

        do {
            _ = try await makeClient().lookup(barcode: "1")
            XCTFail("expected invalidResponse")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    // MARK: Test 5: network error, invalid JSON, and rate limit map correctly

    func test_lookup_withNoNetwork_throwsNoNetwork() async throws {
        MockBarcodeURLProtocol.requestHandler = { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }

        do {
            _ = try await makeClient().lookup(barcode: "123")
            XCTFail("expected noNetwork")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .noNetwork)
        }
    }

    func test_lookup_withInvalidJSON_throwsInvalidResponse() async throws {
        stub(status: 200, body: Data("not json at all".utf8))

        do {
            _ = try await makeClient().lookup(barcode: "123")
            XCTFail("expected invalidResponse")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func test_lookup_withHTTP503_throwsRateLimited() async throws {
        stub(status: 503, body: Data())

        do {
            _ = try await makeClient().lookup(barcode: "123")
            XCTFail("expected rateLimited")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .rateLimited)
        }
    }

    // MARK: Non-digit barcode is rejected before it ever reaches a URL

    func test_lookup_withNonDigitBarcode_throwsInvalidResponseWithoutNetworkCall() async throws {
        var requestMade = false
        MockBarcodeURLProtocol.requestHandler = { request in
            requestMade = true
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (response, Data(#"{"status":0}"#.utf8), nil)
        }

        do {
            _ = try await makeClient().lookup(barcode: "../../etc/passwd")
            XCTFail("expected invalidResponse")
        } catch let error as OnlineFoodSearchError {
            XCTAssertEqual(error, .invalidResponse)
        }
        XCTAssertFalse(requestMade, "ein ungueltiger Barcode darf nie als URL-Pfad verwendet werden")
    }
}
