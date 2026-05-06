#if canImport(HealthKit)
import Foundation
import HealthKit

/// Thin actor over `HKHealthStore` exposing async/await reads + writes for the
/// three body-composition quantities the app cares about: weight, body-fat percent,
/// lean body mass. Keeps the legacy completion-handler queries off the public API —
/// callers only see `try await`.
///
/// Authorization, queries, and writes all flow through this single type. The
/// `HealthKitController` (`@MainActor`, `@Observable`) wraps it for the UI layer.
public actor HealthKitService {

    // MARK: HKQuantity types

    private let store: HKHealthStore

    private static let weightType   = HKQuantityType(.bodyMass)
    private static let bodyFatType  = HKQuantityType(.bodyFatPercentage)
    private static let leanMassType = HKQuantityType(.leanBodyMass)

    // MARK: Lifecycle

    public static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public init() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.unavailable
        }
        self.store = HKHealthStore()
    }

    // MARK: Authorization

    public func requestAuthorization() async throws {
        let toShare: Set<HKSampleType> = [Self.weightType, Self.bodyFatType, Self.leanMassType]
        let toRead:  Set<HKObjectType> = [Self.weightType, Self.bodyFatType, Self.leanMassType]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
        } catch {
            throw HealthKitError.authorizationFailed(reason: error.localizedDescription)
        }
    }

    /// Approximate status — HealthKit only tells us about WRITE permissions for
    /// privacy, so we use weight-write-status as the proxy for "is the connection
    /// set up". This matches the practical user mental model.
    public func currentAuthorizationStatus() -> HealthKitAuthorizationStatus {
        switch store.authorizationStatus(for: Self.weightType) {
        case .notDetermined:     return .notDetermined
        case .sharingDenied:     return .sharingDenied
        case .sharingAuthorized: return .sharingAuthorized
        @unknown default:        return .notDetermined
        }
    }

    // MARK: Reads

    public func latestWeight() async throws -> WeightReading? {
        guard let sample = try await latestSample(of: Self.weightType) else { return nil }
        let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        return WeightReading(
            weightKg: kg,
            date: sample.endDate,
            sourceName: sample.sourceRevision.source.name
        )
    }

    public func latestBodyFatPercent() async throws -> Double? {
        guard let sample = try await latestSample(of: Self.bodyFatType) else { return nil }
        let fraction = sample.quantity.doubleValue(for: HKUnit.percent())
        return fraction * 100.0
    }

    public func latestLeanBodyMassKg() async throws -> Double? {
        guard let sample = try await latestSample(of: Self.leanMassType) else { return nil }
        return sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    // MARK: Writes

    public func saveWeight(_ kg: Double, on date: Date) async throws {
        guard kg > 0 else {
            throw HealthKitError.invalidValue(reason: "weight must be > 0 kg")
        }
        let q = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: Self.weightType, quantity: q, start: date, end: date)
        try await persist(sample)
    }

    public func saveBodyFatPercent(_ percent: Double, on date: Date) async throws {
        guard percent > 0, percent < 100 else {
            throw HealthKitError.invalidValue(reason: "bodyFatPercent must be in (0, 100)")
        }
        let q = HKQuantity(unit: .percent(), doubleValue: percent / 100.0)
        let sample = HKQuantitySample(type: Self.bodyFatType, quantity: q, start: date, end: date)
        try await persist(sample)
    }

    public func saveLeanBodyMass(_ kg: Double, on date: Date) async throws {
        guard kg > 0 else {
            throw HealthKitError.invalidValue(reason: "leanBodyMass must be > 0 kg")
        }
        let q = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: Self.leanMassType, quantity: q, start: date, end: date)
        try await persist(sample)
    }

    // MARK: Internals

    /// Wraps the legacy completion-handler `HKSampleQuery` as async — iOS 17 doesn't
    /// have `HKSampleQueryDescriptor` (that's iOS 18+), so we keep the bridge here.
    private func latestSample(of type: HKQuantityType) async throws -> HKQuantitySample? {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate,
                                                  ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(
                        reason: error.localizedDescription))
                } else {
                    continuation.resume(returning: samples?.first as? HKQuantitySample)
                }
            }
            store.execute(query)
        }
    }

    private func persist(_ sample: HKObject) async throws {
        do {
            try await store.save(sample)
        } catch {
            throw HealthKitError.saveFailed(reason: error.localizedDescription)
        }
    }
}
#endif
