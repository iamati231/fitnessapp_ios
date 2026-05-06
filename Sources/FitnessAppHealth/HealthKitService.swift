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
        // workoutType is *only* a write target — HealthKit never lets us read
        // workouts from other apps anyway, so leaving it out of toRead matches
        // reality.
        let toShare: Set<HKSampleType> = [
            Self.weightType, Self.bodyFatType, Self.leanMassType,
            HKObjectType.workoutType()
        ]
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

    /// Pushes a finished strength-training workout to Apple Health. The user's
    /// Activity rings (Move + Exercise) and the Fitness app's "Workouts" list
    /// pick this up — same surface as an Apple-Watch-recorded workout.
    ///
    /// **No `totalEnergyBurned`** by design: without live heart-rate samples we
    /// can't estimate calories accurately, and shipping a fabricated number
    /// would corrupt the user's energy data. Apple Health falls back to a
    /// conservative estimate from background pulse data, which is the right
    /// behavior.
    ///
    /// **Custom metadata** uses bundle-prefixed keys so other apps that read
    /// our workouts (rare, but possible) can find our specifics without
    /// colliding with Apple's reserved namespace.
    public func saveStrengthTrainingWorkout(
        startDate: Date,
        endDate: Date,
        totalSets: Int,
        totalVolumeKg: Double
    ) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: nil
        )

        // HKMetadataKeyIndoorWorkout is Apple's standard flag — the Fitness
        // app uses it to skip GPS-route rendering. The bundle-prefixed keys
        // are our own.
        let metadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: true,
            "com.atamya.FitnessApp.TotalSets": totalSets,
            "com.atamya.FitnessApp.TotalVolumeKg": totalVolumeKg
        ]

        do {
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata(metadata)
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
        } catch {
            throw HealthKitError.saveFailed(reason: error.localizedDescription)
        }
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
