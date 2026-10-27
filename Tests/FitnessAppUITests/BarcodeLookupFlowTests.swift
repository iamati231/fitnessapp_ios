#if canImport(SwiftData)
import XCTest
@testable import FitnessAppUI
import FitnessAppFoodLookup

/// Task: Barcode-Scan ergänzen. `BarcodeLookupController` is the testable
/// seam the brief asks for ("Barcode-Verarbeitung in eine testbare Funktion/
/// einen testbaren Controller extrahieren") — these tests drive it with a
/// fake `OnlineFoodBarcodeLookup`, no camera/`DataScannerViewController`
/// involved, same approach `OnlineFoodLookupFlowTests` uses for text search.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class BarcodeLookupFlowTests: XCTestCase {

    private static let candidate = OnlineFoodCandidate(
        id: "3017620422003", name: "Nutella", brand: "Ferrero",
        kcalPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57.5, fatPer100g: 30.9
    )

    private struct FakeBarcodeLookup: OnlineFoodBarcodeLookup {
        let result: Result<OnlineFoodCandidate, OnlineFoodSearchError>
        func lookup(barcode: String) async throws -> OnlineFoodCandidate { try result.get() }
    }

    /// Counts calls — used by the "at most one lookup per scan" test, same
    /// lock-protected-class reasoning as `SpyOnlineFoodSearcher`.
    private final class SpyBarcodeLookup: OnlineFoodBarcodeLookup, @unchecked Sendable {
        private let lock = NSLock()
        private var _callCount = 0
        var callCount: Int { lock.lock(); defer { lock.unlock() }; return _callCount }
        let result: Result<OnlineFoodCandidate, OnlineFoodSearchError>

        init(result: Result<OnlineFoodCandidate, OnlineFoodSearchError>) { self.result = result }

        func lookup(barcode: String) async throws -> OnlineFoodCandidate {
            lock.lock(); _callCount += 1; lock.unlock()
            return try result.get()
        }
    }

    // MARK: Barcode test 1: a valid product response is mapped to the candidate

    func testProcess_withFoundProduct_setsFoundCandidate() async {
        let controller = BarcodeLookupController(lookup: FakeBarcodeLookup(result: .success(Self.candidate)))

        await controller.process(barcode: "3017620422003") { _ in "" }

        XCTAssertEqual(controller.foundCandidate, Self.candidate)
        XCTAssertNil(controller.errorMessage)
        XCTAssertFalse(controller.isLookingUp)
    }

    // MARK: Barcode test 3: unknown product -> clear "not found" state, no crash

    func testProcess_withNoResultsError_setsLocalizedErrorAndNoCandidate() async {
        let controller = BarcodeLookupController(lookup: FakeBarcodeLookup(result: .failure(.noResults)))

        await controller.process(barcode: "0238954471860") { error in
            switch error {
            case .noResults: return "Produkt nicht gefunden."
            default: XCTFail("falscher Fehlerfall gemappt: \(error)"); return ""
            }
        }

        XCTAssertNil(controller.foundCandidate)
        XCTAssertEqual(controller.errorMessage, "Produkt nicht gefunden.")
    }

    // MARK: Barcode test 5: network/invalid-JSON/rate-limit errors are mapped, not crashes

    func testProcess_withNetworkError_setsLocalizedErrorAndNoCandidate() async {
        let controller = BarcodeLookupController(lookup: FakeBarcodeLookup(result: .failure(.noNetwork)))

        await controller.process(barcode: "123") { error in
            error == .noNetwork ? "Keine Internetverbindung." : ""
        }

        XCTAssertNil(controller.foundCandidate)
        XCTAssertEqual(controller.errorMessage, "Keine Internetverbindung.")
    }

    // MARK: Barcode test 6: a scan triggers at most one product lookup

    func testProcess_calledTwiceForTheSameScanSession_onlyOneLookupHappens() async {
        let spy = SpyBarcodeLookup(result: .success(Self.candidate))
        let controller = BarcodeLookupController(lookup: spy)

        // Simulates the scanner delegate firing twice (same or different
        // barcode) before the first lookup's result is handled.
        async let first: Void = controller.process(barcode: "3017620422003") { _ in "" }
        async let second: Void = controller.process(barcode: "4000000000000") { _ in "" }
        _ = await (first, second)

        XCTAssertEqual(spy.callCount, 1, "ein Scan darf hoechstens eine Produktabfrage ausloesen")

        // A later scan (after `reset()`) can process a barcode again.
        controller.reset()
        await controller.process(barcode: "3017620422003") { _ in "" }
        XCTAssertEqual(spy.callCount, 2)
    }

    // MARK: reset() clears found candidate/error so the next scan starts clean

    func testReset_clearsPreviousResultAndAllowsReprocessing() async {
        let controller = BarcodeLookupController(lookup: FakeBarcodeLookup(result: .success(Self.candidate)))
        await controller.process(barcode: "3017620422003") { _ in "" }
        XCTAssertNotNil(controller.foundCandidate)
        XCTAssertTrue(controller.hasStartedLookup)

        controller.reset()

        XCTAssertNil(controller.foundCandidate)
        XCTAssertNil(controller.errorMessage)
        XCTAssertFalse(controller.hasStartedLookup)
    }

    // MARK: Barcode test 7: a hit is routed through the SAME preview/confirm sheet as text search

    func testHandleBarcodeDetectedRoutesThroughTheSharedPreviewSheetNotAnAutomaticSave() throws {
        let source = try String(contentsOf: sourcesRoot.appendingPathComponent("Nutrition/AddMealView.swift"), encoding: .utf8)
        guard let range = source.range(of: "private func handleBarcodeDetected(_ barcode: String) {") else {
            XCTFail("handleBarcodeDetected nicht gefunden")
            return
        }
        let block = try XCTUnwrap(matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(
            block.contains("onlineSearch.select(candidate)"),
            "ein Barcode-Treffer muss denselben Vorschau-/Bestaetigungsablauf wie die Textsuche durchlaufen, statt direkt zu speichern"
        )
        XCTAssertFalse(block.contains("modelContext.insert"), "ein Scan darf nicht direkt (ohne Bestaetigung) speichern")
        XCTAssertFalse(block.contains("draft.addItem"), "ein Scan darf nicht direkt (ohne Bestaetigung) zur Mahlzeit hinzufuegen")

        // `.barcode` must share `confirmOnlineImport`'s plain `selectEntry`
        // path (same as `.manual`), never the AI-candidate path.
        guard let confirmRange = source.range(of: "private func confirmOnlineImport(_ values: OnlineFoodImportValues) {") else {
            XCTFail("confirmOnlineImport nicht gefunden")
            return
        }
        let confirmBlock = try XCTUnwrap(matchingBraceBlock(in: source, afterOpenBrace: confirmRange.upperBound))
        XCTAssertTrue(confirmBlock.contains("case .aiCandidate(let candidate) = origin"))
    }

    // MARK: - Fixtures / helpers (mirrors OnlineFoodLookupFlowTests' source-reading helpers)

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }
}

/// Barcode test 8: camera unavailable / permission denied must resolve to a
/// defined UI state, never crash — pure-function test, no AVFoundation/
/// VisionKit involved (those can't run in `swift test` anyway; this is the
/// part of that behavior that IS unit-testable, see `BarcodeScanGate.swift`).
final class BarcodeScanGateTests: XCTestCase {
    func testUnsupportedDeviceWinsOverAnyPermissionState() {
        for permission: CameraPermissionState in [.authorized, .notDetermined, .deniedOrRestricted] {
            XCTAssertEqual(barcodeScanAvailability(isDeviceSupported: false, permission: permission), .unsupportedDevice)
        }
    }

    func testSupportedDeviceMapsEachPermissionStateToItsOwnAvailability() {
        XCTAssertEqual(barcodeScanAvailability(isDeviceSupported: true, permission: .authorized), .ready)
        XCTAssertEqual(barcodeScanAvailability(isDeviceSupported: true, permission: .notDetermined), .permissionNotDetermined)
        XCTAssertEqual(barcodeScanAvailability(isDeviceSupported: true, permission: .deniedOrRestricted), .permissionDenied)
    }
}
#endif
