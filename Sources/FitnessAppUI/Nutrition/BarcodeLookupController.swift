#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
#if canImport(Combine)
import Combine
#endif
import FitnessAppFoodLookup

/// Task: Ernährungssuche erweitern + Barcode-Scan ergänzen. All barcode-
/// lookup network state/logic, kept OUT of the scanner UI itself — same
/// separation `OnlineFoodSearchController` already establishes for text
/// search, so this logic is testable via XCTest without a real camera or
/// `DataScannerViewController` (this package has no device/UI-test harness,
/// only `swift test`).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class BarcodeLookupController: ObservableObject {
    @Published private(set) var isLookingUp: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var foundCandidate: OnlineFoodCandidate?

    /// "Verarbeite einen erkannten Barcode nur einmal pro Scanvorgang"
    /// (brief): once a lookup has STARTED, every further detection from the
    /// same scan session — the same barcode fired twice by the scanner, or a
    /// second different one before the view closes — is ignored. Reset only
    /// by `reset()`, called right before a NEW scan session opens.
    private(set) var hasStartedLookup: Bool = false

    private let lookup: OnlineFoodBarcodeLookup

    init(lookup: OnlineFoodBarcodeLookup) {
        self.lookup = lookup
    }

    /// - Parameter errorText: maps each `OnlineFoodSearchError` case to an
    ///   already-localized string, same pattern/reason as
    ///   `OnlineFoodSearchController.search`'s `errorText`.
    func process(barcode: String, errorText: (OnlineFoodSearchError) -> String) async {
        guard !hasStartedLookup else { return }
        hasStartedLookup = true
        isLookingUp = true
        errorMessage = nil
        defer { isLookingUp = false }
        do {
            foundCandidate = try await lookup.lookup(barcode: barcode)
        } catch let error as OnlineFoodSearchError {
            errorMessage = errorText(error)
        } catch {
            errorMessage = errorText(.invalidResponse)
        }
    }

    /// Call before opening a new scan session (or after the found candidate
    /// has been handed off to the preview sheet), so the next scan can
    /// process a barcode again.
    func reset() {
        hasStartedLookup = false
        isLookingUp = false
        errorMessage = nil
        foundCandidate = nil
    }
}
#endif
