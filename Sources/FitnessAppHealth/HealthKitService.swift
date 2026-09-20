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
    private static let heightType   = HKQuantityType(.height)
    private static let dobType      = HKCharacteristicType(.dateOfBirth)
    private static let sexType      = HKCharacteristicType(.biologicalSex)

    /// DEL-132 (Phase 3): Hero-Metric-Sources fuer das Dashboard.
    /// Read-only — wir schreiben weder Ruhepuls noch Schritte zurueck
    /// (Apple Watch / iPhone Sensors generieren die ohnehin).
    private static let restingHRType  = HKQuantityType(.restingHeartRate)
    private static let stepCountType  = HKQuantityType(.stepCount)

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
        //
        // Characteristic types (dateOfBirth, biologicalSex) are read-only by
        // design; they're set in the user's Health profile and we can pre-fill
        // them into onboarding.
        let toShare: Set<HKSampleType> = [
            Self.weightType, Self.bodyFatType, Self.leanMassType,
            HKObjectType.workoutType()
        ]
        let toRead:  Set<HKObjectType> = [
            Self.weightType, Self.bodyFatType, Self.leanMassType,
            Self.heightType, Self.dobType, Self.sexType,
            // DEL-132 (Phase 3): Hero-Metric Read-Permissions.
            // restingHR + steps werden nicht zurueckgeschrieben, daher
            // nur in `toRead`.
            Self.restingHRType, Self.stepCountType,
        ]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
        } catch {
            throw HealthKitError.authorizationFailed(reason: error.localizedDescription)
        }
    }

    /// Separate, narrowly-scoped authorization request for reading OTHER apps'
    /// workouts (e.g. Adidas Running, Strava) — deliberately kept out of the
    /// general `requestAuthorization()` `toRead` set. That method is triggered
    /// from six existing UI entry points (onboarding, measurement, dashboard
    /// hero-cards, settings, profile editor) that have nothing to do with
    /// workout import; folding `workoutType` into it would re-prompt every
    /// already-connected user the next time they hit ANY of those, just for
    /// re-asking a permission they never wanted. Calling `requestAuthorization`
    /// again here with a disjoint `read` set is a valid incremental HealthKit
    /// request — types already granted from the first call aren't re-asked.
    public func requestWorkoutReadAuthorization() async throws {
        do {
            try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
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

    /// DEL-132 (Phase 3): Letzter Ruhepuls in BPM. Apple Watch schreibt
    /// einen neuen Wert ca. einmal pro Tag (errechnet aus den niedrigsten
    /// Stunden-Mittelwerten der vergangenen Tage). Wir nehmen einfach den
    /// neuesten Sample — kein Aggregation noetig, der Wert IST schon der
    /// "stabile Ruhepuls".
    public func latestRestingHeartRateBPM() async throws -> Double? {
        guard let sample = try await latestSample(of: Self.restingHRType) else { return nil }
        return sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    /// DEL-132 (Phase 3): Heutige Schritte. Anders als Ruhepuls (point
    /// sample) sind Schritte cumulativ — jedes iPhone/Watch-Update
    /// schreibt einen kleinen Delta-Sample. Wir aggregieren via
    /// `HKStatisticsQuery` mit `.cumulativeSum` ueber das Date-Interval
    /// `startOfDay ... now`. Locale-aware via Calendar.current.
    public func stepCountToday() async throws -> Double? {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: Self.stepCountType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(
                        reason: error.localizedDescription))
                    return
                }
                let count = statistics?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: count)
            }
            store.execute(query)
        }
    }

    /// Most recent height in centimetres. Comes from manual entries in Apple
    /// Health (no device auto-measures height), so it's typically the value
    /// the user originally set in the Health-App profile and never updates.
    public func latestHeightCm() async throws -> Double? {
        guard let sample = try await latestSample(of: Self.heightType) else { return nil }
        return sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
    }

    /// Returns the user's date of birth from the Health profile, or nil if
    /// not set. Characteristic types throw a "no data" error when unset —
    /// we catch that and return nil so the caller can fall back gracefully.
    public func dateOfBirth() async -> Date? {
        do {
            let components = try store.dateOfBirthComponents()
            return Calendar.current.date(from: components)
        } catch {
            return nil
        }
    }

    /// Returns the biological sex from the Health profile, or .notSet if the
    /// user hasn't set it. Maps to our domain enum via `BodyFormulaProfile(hk:)`
    /// extension in `HealthKitController`.
    public func biologicalSex() async -> HKBiologicalSex {
        do {
            return try store.biologicalSex().biologicalSex
        } catch {
            return .notSet
        }
    }

    /// Pulls running/cycling workouts written by OTHER apps (e.g. Adidas
    /// Running) since `since` (or all-time when `nil`). Excludes this app's
    /// own written workouts by source bundle identifier — without that
    /// filter, every workout we push via `saveStrengthTrainingWorkout`/
    /// `saveRunningWorkout` would loop straight back in as a "new external"
    /// workout on the next sync.
    ///
    /// Read authorization is invisible to us by design (see
    /// `requestWorkoutReadAuthorization`) — if the user denied it, this
    /// simply returns an empty array, indistinguishable from "no matching
    /// workouts exist yet".
    public func fetchExternalWorkouts(since: Date?) async throws -> [ExternalWorkoutSample] {
        var predicates: [NSPredicate] = [
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .running),
                HKQuery.predicateForWorkouts(with: .cycling)
            ])
        ]
        if let since {
            predicates.append(HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate))
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let ownBundleID = Bundle.main.bundleIdentifier

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(
                        reason: error.localizedDescription))
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                let externals: [ExternalWorkoutSample] = workouts.compactMap { workout in
                    let bundleID = workout.sourceRevision.source.bundleIdentifier
                    guard bundleID != ownBundleID,
                          let activity = ExternalWorkoutActivityType(hk: workout.workoutActivityType)
                    else { return nil }
                    return ExternalWorkoutSample(
                        hkUUID: workout.uuid.uuidString,
                        activityType: activity,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        distanceKm: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)),
                        sourceName: workout.sourceRevision.source.name,
                        sourceBundleIdentifier: bundleID
                    )
                }
                continuation.resume(returning: externals)
            }
            store.execute(query)
        }
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

    /// DEL-063: Cardio-Sessions (z.B. Hybrid-Lauftage) duerfen nicht als
    /// `.traditionalStrengthTraining` in Apple Health landen — die Fitness-
    /// App wertet sie sonst falsch fuer den Bewegungs-Ring aus.
    ///
    /// Diese Methode schreibt das Workout als `.running` und haengt
    /// zusaetzlich ein `distanceWalkingRunning`-Quantity-Sample an, damit
    /// die Gesamt-Kilometer in den Trainings-Statistiken erscheinen.
    ///
    /// **Custom metadata**: bundle-prefixed Keys (`TotalDistanceKm`,
    /// `AveragePaceMinPerKm`) bleiben fuer eventuelle App-zu-App-Reads
    /// erhalten.
    public func saveRunningWorkout(
        startDate: Date,
        endDate: Date,
        totalDistanceKm: Double,
        averagePaceMinPerKm: Double?
    ) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: nil
        )

        var metadata: [String: Any] = [
            "com.atamya.FitnessApp.TotalDistanceKm": totalDistanceKm
        ]
        if let pace = averagePaceMinPerKm, pace > 0 {
            metadata["com.atamya.FitnessApp.AveragePaceMinPerKm"] = pace
        }

        do {
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata(metadata)

            // Distanz-Sample anhaengen, damit die Apple-Health-UI die
            // Kilometer sauber zaehlt und die Fitness-Bewegungs-Ringe
            // korrekt aufgeladen werden.
            if totalDistanceKm > 0 {
                let distanceMeters = totalDistanceKm * 1000.0
                let distanceQuantity = HKQuantity(
                    unit: HKUnit.meter(),
                    doubleValue: distanceMeters
                )
                let distanceSample = HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([distanceSample])
            }

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

private extension ExternalWorkoutActivityType {
    init?(hk: HKWorkoutActivityType) {
        switch hk {
        case .running: self = .running
        case .cycling: self = .cycling
        default: return nil
        }
    }
}
#endif
