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
    /// `requestAuthorization()`: die Freigabe wird erst angefragt, wenn der
    /// Nutzer das Schreiben von Cardio einschaltet
    /// (`requestWorkoutWriteAuthorization(includeDistance:)`).
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
        // incrementally when the user turns it on
        // (`requestWorkoutWriteAuthorization(includeDistance:)`).
        // Reading OTHER apps' workouts (Workout-Import) is deliberately not
        // part of this request either — it has its own narrow
        // `requestWorkoutReadAuthorization()` below, so that the entry points
        // sharing this method never re-prompt for it.
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

    /// Incremental, user-initiated request for the WRITE permission of the
    /// Trainings type (and, when `includeDistance` is set, the walking/running
    /// distance type). Users who connected Apple Health before a type joined
    /// `requestAuthorization()` are never shown that dialog again by the
    /// connect rows (they only appear while the weight status is
    /// `.notDetermined`), so this is the way to ask for it later.
    ///
    /// Only types that are still `.notDetermined` go into the request: HealthKit
    /// shows the sheet when at least one requested type is undecided, and
    /// listing already decided types again would read like nagging. The
    /// distance type is skipped while the workout type is denied (a distance
    /// without a workout is worthless). With nothing left to ask this does
    /// nothing — callers re-read `currentWorkoutWriteAuthorization()`, because
    /// a returning request says nothing about what the user granted.
    public func requestWorkoutWriteAuthorization(includeDistance: Bool) async throws {
        let workoutType = HKObjectType.workoutType()
        let workoutStatus = store.authorizationStatus(for: workoutType)

        var toShare: Set<HKSampleType> = []
        if workoutStatus == .notDetermined {
            toShare.insert(workoutType)
        }
        if includeDistance,
           workoutStatus != .sharingDenied,
           store.authorizationStatus(for: Self.distanceType) == .notDetermined {
            toShare.insert(Self.distanceType)
        }
        guard !toShare.isEmpty else { return }

        do {
            try await store.requestAuthorization(toShare: toShare, read: [])
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
    public func currentWorkoutWriteAuthorization() -> WorkoutWriteAuthorization {
        WorkoutWriteAuthorization(
            workout: Self.map(store.authorizationStatus(for: HKObjectType.workoutType())),
            distance: Self.map(store.authorizationStatus(for: Self.distanceType))
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
    /// die Gesamt-Kilometer in den Trainings-Statistiken erscheinen — sofern
    /// der Nutzer diesen Typ freigegeben hat und HealthKit das Sample
    /// annimmt; das Workout selbst haengt davon nicht ab.
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
            // korrekt aufgeladen werden. Nur mit Schreibfreigabe fuer den
            // Typ: Nutzer, die Apple Health verbunden haben, bevor die
            // Distanz zu `requestAuthorization` gehoerte, wuerden sonst das
            // GANZE Workout verlieren (der Builder lehnt Samples ohne
            // Schreibrecht ab). Ohne Freigabe landet das Workout ohne
            // Distanz-Sample in Health; die Kilometer stehen weiter in den
            // Metadaten.
            if totalDistanceKm > 0,
               store.authorizationStatus(for: Self.distanceType) == .sharingAuthorized {
                let distanceMeters = totalDistanceKm * 1000.0
                let distanceQuantity = HKQuantity(
                    unit: HKUnit.meter(),
                    doubleValue: distanceMeters
                )
                let distanceSample = HKQuantitySample(
                    type: Self.distanceType,
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                do {
                    try await builder.addSamples([distanceSample])
                } catch {
                    // Die Distanz ist Beiwerk: lehnt HealthKit das Sample aus
                    // irgendeinem Grund ab, bleibt das Workout trotzdem
                    // erhalten (Kilometer stehen weiter in den Metadaten).
                }
            }

            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
        } catch {
            throw HealthKitError.saveFailed(reason: error.localizedDescription)
        }
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
    /// - Metadata goes into a single `addMetadata` call. Bundle-prefixed keys
    ///   keep our specifics apart from Apple's reserved namespace.
    public func saveWorkout(_ draft: HealthWorkoutDraft) async throws -> HealthWorkoutWriteOutcome {
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

        var metadata: [String: Any] = [:]
        if let indoor = draft.isIndoor {
            metadata[HKMetadataKeyIndoorWorkout] = indoor
        }
        if let sets = draft.totalSets {
            metadata["com.atamya.FitnessApp.TotalSets"] = sets
        }
        if let volume = draft.totalVolumeKg, volume.isFinite {
            metadata["com.atamya.FitnessApp.TotalVolumeKg"] = volume
        }
        if let km = draft.totalDistanceKm, km.isFinite, km > 0 {
            metadata["com.atamya.FitnessApp.TotalDistanceKm"] = km
        }
        if let pace = draft.averagePaceMinPerKm, pace.isFinite, pace > 0 {
            metadata["com.atamya.FitnessApp.AveragePaceMinPerKm"] = pace
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
