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

    /// Wird nur geschrieben: `saveWorkout` haengt einem Lauf-/Geh-Workout ein
    /// Distanz-Sample an, und `HKWorkoutBuilder.addSamples` verlangt dafuer die
    /// Schreibberechtigung des Sample-Typs. NICHT Teil von
    /// `requestAuthorization()`: die Freigabe wird schrittweise angefragt
    /// (`requestWorkoutWriteAuthorization(includeDistance:)`) — beim Einschalten
    /// von Cardio, ueber die Schaltflaeche "Geh- und Laufdistanz erlauben" und vor
    /// einem Export frueherer Laeufe mit km (jeweils nur, solange sie noch
    /// unentschieden ist).
    private static let distanceType = HKQuantityType(.distanceWalkingRunning)

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
        // workoutType is a write target here: we push our own finished
        // workouts (Krafttraining is on by default). The walking/running
        // DISTANCE type is deliberately NOT part of this request — cardio
        // writing is opt-in, and its distance permission is asked
        // incrementally (`requestWorkoutWriteAuthorization(includeDistance:)`):
        // when the user turns cardio on, via the in-app distance button, or
        // before an export of past runs with km.
        // workoutType is ALSO in `toRead` (reading other apps' workouts for the
        // Workout-Import and for the duplicate check of the export). iOS tracks
        // "was the user asked?" per TYPE, not per access mode: a type first
        // requested for one mode only can never get the other mode through a
        // sheet later (no sheet appears, the Health app has no switch for it).
        // So workoutType is ALWAYS requested for write AND read together — here,
        // in `requestWorkoutReadAuthorization()` and in
        // `requestWorkoutWriteAuthorization(includeDistance:)`.
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
            HKObjectType.workoutType(),
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

    /// Authorization request for reading OTHER apps' workouts (e.g. Adidas
    /// Running, Strava) — used by the Workout-Import toggle and the export's
    /// duplicate check.
    ///
    /// The Trainings type is requested for WRITE and READ together, never for
    /// reading alone: a read-only request marks the type as "asked", after which
    /// iOS reports its write status as denied, shows no sheet for the write
    /// permission any more, and lists no write switch in the Health app. (That is
    /// exactly what happened to users who turned the import on before allowing
    /// Trainings to be written.)
    ///
    /// iOS is asked only when `statusForAuthorizationRequest` says it would show
    /// a sheet; otherwise the call is skipped, so an existing permission record
    /// is never touched. There is no status to read back afterwards — HealthKit
    /// never discloses read grant/deny.
    public func requestWorkoutReadAuthorization() async throws {
        guard await workoutRequestStatus() != .unnecessary else { return }
        let workoutType = HKObjectType.workoutType()
        do {
            try await store.requestAuthorization(toShare: [workoutType], read: [workoutType])
        } catch {
            throw HealthKitError.authorizationFailed(reason: error.localizedDescription)
        }
    }

    /// Would a request for the Trainings type (write + read together) show the
    /// sheet right now? `.unknown` when the query fails.
    public func workoutRequestStatus() async -> HealthKitRequestStatus {
        let workoutType = HKObjectType.workoutType()
        do {
            let status = try await store.statusForAuthorizationRequest(
                toShare: [workoutType], read: [workoutType]
            )
            switch status {
            case .shouldRequest: return .shouldRequest
            case .unnecessary:   return .unnecessary
            default:             return .unknown
            }
        } catch {
            return .unknown
        }
    }

    /// Incremental, user-initiated request for the WRITE permission of the
    /// Trainings type (and, when `includeDistance` is set, the walking/running
    /// distance type). Users who connected Apple Health before a type joined
    /// `requestAuthorization()` are never shown that dialog again by the
    /// connect rows (they only appear while the weight status is
    /// `.notDetermined`), so this is the way to ask for it later.
    ///
    /// The Trainings type goes into the request (write AND read, see
    /// `requestWorkoutReadAuthorization`) only while iOS would still show a
    /// sheet for it (`WorkoutWriteAuthorization.canRequestWorkout`). A "denied"
    /// status alone is NOT a reason to skip: it is also what iOS reports for a
    /// type that was only requested for reading. The distance type needs the
    /// Trainings permission to be of any use, so it is requested only while that
    /// is granted or still askable, and only while it is `.notDetermined`.
    /// With nothing left to ask this does nothing — callers re-read the status,
    /// because a returning request says nothing about what the user granted.
    public func requestWorkoutWriteAuthorization(includeDistance: Bool) async throws {
        let workoutType = HKObjectType.workoutType()
        let workoutStatus = Self.map(store.authorizationStatus(for: workoutType))
        let requestStatus = await workoutRequestStatus()
        let askWorkout = WorkoutWriteAuthorization.canRequestWorkout(status: workoutStatus, request: requestStatus)

        var toShare: Set<HKSampleType> = []
        var toRead: Set<HKObjectType> = []
        if askWorkout {
            toShare.insert(workoutType)
            toRead.insert(workoutType)
        }
        if includeDistance,
           askWorkout || workoutStatus == .sharingAuthorized,
           store.authorizationStatus(for: Self.distanceType) == .notDetermined {
            toShare.insert(Self.distanceType)
        }
        guard !toShare.isEmpty else { return }

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
        Self.map(store.authorizationStatus(for: Self.weightType))
    }

    /// Write status of the Trainings type and the distance type, read fresh
    /// from HealthKit (no cache). The workout live gate and the export read
    /// this at write time.
    public func currentWorkoutWriteAuthorization() async -> WorkoutWriteAuthorization {
        WorkoutWriteAuthorization(
            workout: Self.map(store.authorizationStatus(for: HKObjectType.workoutType())),
            distance: Self.map(store.authorizationStatus(for: Self.distanceType)),
            workoutRequest: await workoutRequestStatus()
        )
    }

    private static func map(_ status: HKAuthorizationStatus) -> HealthKitAuthorizationStatus {
        switch status {
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
    /// filter, every workout we push via `saveWorkout` would loop straight
    /// back in as a "new external"
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
                        sourceBundleIdentifier: bundleID,
                        activeDurationSeconds: workout.duration
                    )
                }
                continuation.resume(returning: externals)
            }
            store.execute(query)
        }
    }

    /// Time windows of ALL workouts HealthKit shows this app between `start`
    /// and `end` — own and other apps', any activity type. The history export
    /// compares its candidates against these to avoid duplicates.
    ///
    /// What is visible depends on the permissions: with write access only the
    /// workouts this app wrote itself; other apps' workouts need the READ
    /// permission (`requestWorkoutReadAuthorization`) — and HealthKit never
    /// reveals whether that was granted: without it the result is simply
    /// shorter, not an error. Callers must not read an empty result as
    /// "nothing else exists".
    ///
    /// Throws `HealthKitError.databaseInaccessible` while the device is locked
    /// (queries fail then, writes are cached) and `.queryFailed` otherwise.
    public func fetchWorkoutWindows(from start: Date, to end: Date) async throws -> [HealthWorkoutWindow] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let ownBundleID = Bundle.main.bundleIdentifier

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: Self.mapQueryError(error))
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                let windows: [HealthWorkoutWindow] = workouts.map { workout in
                    HealthWorkoutWindow(
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        sourceName: workout.sourceRevision.source.name,
                        isOwnSource: workout.sourceRevision.source.bundleIdentifier == ownBundleID
                    )
                }
                continuation.resume(returning: windows)
            }
            store.execute(query)
        }
    }

    private static func mapQueryError(_ error: Error) -> HealthKitError {
        if (error as? HKError)?.code == .errorDatabaseInaccessible {
            return .databaseInaccessible
        }
        return .queryFailed(reason: error.localizedDescription)
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

    /// Writes one finished workout (strength, running, walking, cycling or
    /// generic cardio) to Apple Health with `HKWorkoutBuilder`, also for
    /// workouts in the past.
    ///
    /// - The Trainings write permission is read fresh from HealthKit BEFORE
    ///   anything is started (no cache): without it nothing is written and
    ///   `HealthKitError.writeNotAuthorized` is thrown. Because
    ///   `addSamples` stores samples immediately and `discardWorkout()` does not
    ///   remove them, starting without the permission could otherwise leave an
    ///   orphaned distance sample behind.
    /// - Energy and heart rate are deliberately NOT written — without sensors
    ///   they would be invented values (App Review 5.1.3(ii)). Consequently the
    ///   Move ring is not filled by these workouts; Health lists them as
    ///   workouts.
    /// - The distance SAMPLE (`distanceWalkingRunning`) is only attached for
    ///   running/walking and only when that type is authorized; if HealthKit
    ///   rejects it the workout is kept without distance (the kilometres stay
    ///   in the metadata). `distanceAttached` in the result tells which.
    /// - `finishWorkout()` returning `nil` is reported as `.unverified`, not as
    ///   success (see `HealthWorkoutWriteOutcome`).
    /// - Metadata goes into a single `addMetadata` call: the indoor flag plus the
    ///   app's own entries (`HealthWorkoutDraft.customMetadata`), which Health
    ///   shows under short readable keys (`HealthWorkoutMetadataLabels`).
    /// - Those own entries are a bonus like the distance sample: HealthKit
    ///   documents neither limits for metadata text nor rules for custom keys, so
    ///   if the save fails (`mayBeCausedByOptionalMetadata`) the workout is
    ///   written once more WITHOUT them. Safe because the retry only happens
    ///   when no sample was added before the failure, and a failed attempt is
    ///   discarded.
    public func saveWorkout(_ draft: HealthWorkoutDraft) async throws -> HealthWorkoutWriteOutcome {
        var addedSample = false
        do {
            return try await writeWorkout(draft, withCustomMetadata: true, addedSample: &addedSample)
        } catch let error as HealthKitError {
            guard error.mayBeCausedByOptionalMetadata,
                  !addedSample,
                  !draft.customMetadata.isEmpty
            else { throw error }
            var addedSampleOnRetry = false
            return try await writeWorkout(draft, withCustomMetadata: false, addedSample: &addedSampleOnRetry)
        }
    }

    /// - Parameter addedSample: set to `true` as soon as a sample is handed to the
    ///   builder (it is stored at once and survives `discardWorkout()`), so the
    ///   caller knows a retry could duplicate it.
    private func writeWorkout(
        _ draft: HealthWorkoutDraft,
        withCustomMetadata: Bool,
        addedSample: inout Bool
    ) async throws -> HealthWorkoutWriteOutcome {
        let workoutType = HKObjectType.workoutType()
        guard store.authorizationStatus(for: workoutType) == .sharingAuthorized else {
            throw HealthKitError.writeNotAuthorized
        }
        guard draft.endDate > draft.startDate else {
            throw HealthKitError.invalidWorkout(reason: "end date is not after start date")
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = Self.activityType(for: draft.kind)
        if let indoor = draft.isIndoor {
            configuration.locationType = indoor ? .indoor : .outdoor
        }

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: nil
        )

        // The app's own entries (rounded and labelled for Health's raw display)
        // come from the draft; the indoor flag is HealthKit's own key.
        var metadata: [String: Any] = withCustomMetadata ? draft.customMetadata : [:]
        if let indoor = draft.isIndoor {
            metadata[HKMetadataKeyIndoorWorkout] = indoor
        }

        var distanceAttached = false
        var finishCalled = false
        do {
            try await builder.beginCollection(at: draft.startDate)
            if !metadata.isEmpty {
                try await builder.addMetadata(metadata)
            }

            if let km = draft.sampleDistanceKm, km.isFinite, km > 0,
               draft.kind == .running || draft.kind == .walking,
               store.authorizationStatus(for: Self.distanceType) == .sharingAuthorized {
                let quantity = HKQuantity(unit: HKUnit.meter(), doubleValue: km * 1000.0)
                let sample = HKQuantitySample(
                    type: Self.distanceType,
                    quantity: quantity,
                    start: draft.startDate,
                    end: draft.endDate
                )
                do {
                    addedSample = true
                    try await builder.addSamples([sample])
                    distanceAttached = true
                } catch {
                    // Die Distanz ist Beiwerk: lehnt HealthKit das Sample ab,
                    // bleibt das Workout erhalten (Kilometer in den Metadaten).
                }
            }

            try await builder.endCollection(at: draft.endDate)
            finishCalled = true
            let workout = try await builder.finishWorkout()
            return workout == nil
                ? .unverified(distanceAttached: distanceAttached)
                : .written(distanceAttached: distanceAttached)
        } catch {
            // Nach finishWorkout ist der Builder fertig; nur davor verwerfen.
            if !finishCalled {
                builder.discardWorkout()
            }
            throw Self.mapSaveError(error)
        }
    }

    private static func activityType(for kind: HealthWorkoutKind) -> HKWorkoutActivityType {
        switch kind {
        case .strengthTraining: return .traditionalStrengthTraining
        case .running:          return .running
        case .walking:          return .walking
        case .cycling:          return .cycling
        case .mixedCardio:      return .mixedCardio
        }
    }

    private static func mapSaveError(_ error: Error) -> HealthKitError {
        if let healthError = error as? HealthKitError {
            return healthError
        }
        if let hkError = error as? HKError {
            switch hkError.code {
            case .errorAuthorizationDenied, .errorAuthorizationNotDetermined:
                return .writeNotAuthorized
            case .errorDatabaseInaccessible:
                return .databaseInaccessible
            case .errorInvalidArgument:
                return .invalidWorkout(reason: hkError.localizedDescription)
            default:
                break
            }
        }
        return .saveFailed(reason: error.localizedDescription)
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
