import Foundation

/// Approximate authorization status as exposed to the UI.
///
/// HealthKit refuses to disclose READ-side authorization for privacy reasons — only
/// write-side status is queryable. We mirror that into a four-case enum that matches
/// what the user actually needs to know:
///   - `.unavailable`: device doesn't support HealthKit (rare — iPad without HK).
///   - `.notDetermined`: user hasn't been asked yet.
///   - `.sharingDenied`: user denied write permission.
///   - `.sharingAuthorized`: write permission granted (read is then assumed).
public enum HealthKitAuthorizationStatus: Sendable, Equatable {
    case unavailable
    case notDetermined
    case sharingDenied
    case sharingAuthorized

    /// Short English name for diagnostics.
    public var diagnosticName: String {
        switch self {
        case .unavailable:       return "unavailable"
        case .notDetermined:     return "notDetermined"
        case .sharingDenied:     return "denied"
        case .sharingAuthorized: return "authorized"
        }
    }
}

/// Would asking again show the permission sheet? Mirrors
/// `HKAuthorizationRequestStatus`: `.shouldRequest` = at least one of the
/// requested types was never asked about, `.unnecessary` = every type counts as
/// already asked (iOS then shows no sheet), `.unknown` = the query failed.
public enum HealthKitRequestStatus: Sendable, Equatable {
    case unknown
    case shouldRequest
    case unnecessary

    /// Short English name for diagnostics.
    public var diagnosticName: String {
        switch self {
        case .unknown:       return "unknown"
        case .shouldRequest: return "shouldRequest"
        case .unnecessary:   return "unnecessary"
        }
    }
}

/// How the Trainings screen presents the Trainings write permission.
public enum WorkoutAccessState: Sendable, Equatable {
    case unavailable
    case granted
    /// iOS can still show the permission sheet for the Trainings type.
    case canRequest
    /// iOS shows no sheet any more (the type counts as answered). The user has
    /// to switch it on in the Health app — if the switch exists there at all.
    case blocked
}

/// Write-side authorization for the two types the workout feature needs:
/// the Trainings (workout) type and the walking/running distance type.
/// A separate struct instead of a new case on `HealthKitAuthorizationStatus`:
/// four views switch exhaustively over that enum.
///
/// HealthKit has ONE write permission for workouts ("Trainings"); whether
/// strength and/or cardio is written is an app-level choice
/// (`HealthWritePreferences` in Core). The distance type is requested
/// incrementally (cardio switch turned on, in-app distance button, or before
/// exporting past runs with km), never as part of the initial connect.
///
/// `workoutRequest` exists because `workout == .sharingDenied` is ambiguous:
/// HealthKit reports it both after the user said "Don't Allow" AND for a type
/// that was only ever requested for READING (the Workout-Import does exactly
/// that). iOS tracks "was asked" per TYPE, not per access mode, so in the
/// second case no sheet will ever appear and the Health app has no switch to
/// flip. Only `HKHealthStore.statusForAuthorizationRequest` tells the two apart.
public struct WorkoutWriteAuthorization: Sendable, Equatable {
    public let workout: HealthKitAuthorizationStatus
    public let distance: HealthKitAuthorizationStatus
    /// Would a request for the Trainings type (write + read together) show the
    /// sheet? `.unknown` when it was not (or could not be) determined.
    public let workoutRequest: HealthKitRequestStatus

    public init(
        workout: HealthKitAuthorizationStatus,
        distance: HealthKitAuthorizationStatus,
        workoutRequest: HealthKitRequestStatus = .unknown
    ) {
        self.workout = workout
        self.distance = distance
        self.workoutRequest = workoutRequest
    }

    public static let unavailable = WorkoutWriteAuthorization(workout: .unavailable, distance: .unavailable)

    public var canWriteWorkouts: Bool { workout == .sharingAuthorized }

    /// Single decision for both the screen and the service request: may we ask
    /// iOS for the Trainings permission right now?
    public static func canRequestWorkout(
        status: HealthKitAuthorizationStatus,
        request: HealthKitRequestStatus
    ) -> Bool {
        switch status {
        case .notDetermined:
            // Never asked for writing. Even a contradictory `.unnecessary` is
            // tried once; the screen then reports a request without a sheet.
            return true
        case .sharingDenied:
            // "Denied" is no proof that the user said no (see the type's note).
            // Only a definite "unnecessary" rules the sheet out; if the query
            // failed (`.unknown`) a harmless attempt is better than a dead end.
            return request != .unnecessary
        case .sharingAuthorized, .unavailable:
            return false
        }
    }

    /// Compact technical state for support and TestFlight feedback (not localized).
    public var diagnosticDescription: String {
        "workout=\(workout.diagnosticName) · request=\(workoutRequest.diagnosticName) · distance=\(distance.diagnosticName)"
    }

    public var workoutAccess: WorkoutAccessState {
        switch workout {
        case .unavailable:
            return .unavailable
        case .sharingAuthorized:
            return .granted
        case .notDetermined, .sharingDenied:
            return Self.canRequestWorkout(status: workout, request: workoutRequest) ? .canRequest : .blocked
        }
    }
}

/// Activity kinds the app writes to Apple Health. Mirrors
/// `HealthWorkoutActivity` in Core — `FitnessAppHealth` deliberately does not
/// depend on Core, so the UI layer maps between the two.
public enum HealthWorkoutKind: String, Sendable, Equatable {
    case strengthTraining
    case running
    case walking
    case cycling
    case mixedCardio
}

/// The labels of the app's own metadata entries in Apple Health.
///
/// Health's detail screen shows a custom entry under its KEY, verbatim — a
/// reverse-DNS key like `com.atamya.FitnessApp.TotalSets` would be printed in full.
/// So the keys are short, readable texts. The UI layer passes them in the app's
/// language (this module does not know the string catalog); the defaults are
/// English.
public struct HealthWorkoutMetadataLabels: Sendable, Equatable {
    public var exercises: String
    public var sets: String
    public var volumeKg: String
    public var distanceKm: String
    public var averagePace: String

    public init(exercises: String, sets: String, volumeKg: String, distanceKm: String, averagePace: String) {
        self.exercises = exercises
        self.sets = sets
        self.volumeKg = volumeKg
        self.distanceKm = distanceKm
        self.averagePace = averagePace
    }

    public static let `default` = HealthWorkoutMetadataLabels(
        exercises: "Exercises",
        sets: "Sets",
        volumeKg: "Volume (kg)",
        distanceKm: "Distance (km)",
        averagePace: "Avg. pace (min/km)"
    )

    /// Every label usable as a metadata key: not blank and not in Apple's reserved
    /// "HK" namespace; otherwise the English default.
    var sanitized: HealthWorkoutMetadataLabels {
        func usable(_ label: String, _ fallback: String) -> String {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.hasPrefix("HK") ? fallback : trimmed
        }
        let fallback = Self.default
        return HealthWorkoutMetadataLabels(
            exercises: usable(exercises, fallback.exercises),
            sets: usable(sets, fallback.sets),
            volumeKg: usable(volumeKg, fallback.volumeKg),
            distanceKm: usable(distanceKm, fallback.distanceKm),
            averagePace: usable(averagePace, fallback.averagePace)
        )
    }
}

/// A finished workout to write to Apple Health, as plain values.
public struct HealthWorkoutDraft: Sendable, Equatable {
    public let kind: HealthWorkoutKind
    public let startDate: Date
    public let endDate: Date
    /// `nil` = unknown: neither location type nor indoor flag is set.
    public let isIndoor: Bool?
    /// Walking/running distance for the HealthKit distance SAMPLE
    /// (`running`/`walking` only; needs the distance write permission).
    public let sampleDistanceKm: Double?
    /// Total distance for the workout METADATA only (any cardio kind).
    public let totalDistanceKm: Double?
    public let averagePaceMinPerKm: Double?
    public let totalSets: Int?
    public let totalVolumeKg: Double?
    /// Names of the exercises (strength training only), in the order they were
    /// done — names only, no sets, reps or weights. Written as one text entry in
    /// the workout's metadata (see `HealthWorkoutDraft.exerciseListText`).
    public let exerciseNames: [String]
    /// How the app's own entries are labelled in Health (see the type).
    public let metadataLabels: HealthWorkoutMetadataLabels

    public init(
        kind: HealthWorkoutKind,
        startDate: Date,
        endDate: Date,
        isIndoor: Bool?,
        sampleDistanceKm: Double? = nil,
        totalDistanceKm: Double? = nil,
        averagePaceMinPerKm: Double? = nil,
        totalSets: Int? = nil,
        totalVolumeKg: Double? = nil,
        exerciseNames: [String] = [],
        metadataLabels: HealthWorkoutMetadataLabels = .default
    ) {
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.isIndoor = isIndoor
        self.sampleDistanceKm = sampleDistanceKm
        self.totalDistanceKm = totalDistanceKm
        self.averagePaceMinPerKm = averagePaceMinPerKm
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.exerciseNames = exerciseNames
        self.metadataLabels = metadataLabels
    }
}

/// Result of writing one workout. `unverified` = `finishWorkout()` returned
/// `nil` without an error, which HealthKit documents for a locked device
/// (the workout is saved but not readable) and which has also been reported
/// on unlocked devices without a workout appearing — so it is NOT counted as
/// a confirmed success.
public enum HealthWorkoutWriteOutcome: Sendable, Equatable {
    case written(distanceAttached: Bool)
    case unverified(distanceAttached: Bool)
}

/// The time window of a workout that is visible in Apple Health (own or
/// another app's). Used to avoid duplicates when exporting past workouts.
public struct HealthWorkoutWindow: Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let sourceName: String
    public let isOwnSource: Bool

    public init(startDate: Date, endDate: Date, sourceName: String, isOwnSource: Bool) {
        self.startDate = startDate
        self.endDate = endDate
        self.sourceName = sourceName
        self.isOwnSource = isOwnSource
    }
}

/// One weight reading pulled from HealthKit. Source name comes from the writing
/// app/device (e.g. "Withings Body+", "iPhone", "Apple Watch") so the UI can show
/// where the value originated.
public struct WeightReading: Sendable, Equatable {
    public let weightKg: Double
    public let date: Date
    public let sourceName: String

    public init(weightKg: Double, date: Date, sourceName: String) {
        self.weightKg = weightKg
        self.date = date
        self.sourceName = sourceName
    }
}

/// Cross-platform mirror of `HKBiologicalSex`. Returning this enum from
/// `HealthKitController` keeps the SwiftUI layer free of `#if canImport(HealthKit)`
/// gates — callers branch on `.male`/`.female` without importing HealthKit.
public enum BiologicalSex: Sendable, Equatable {
    case male
    case female
    case other
    case notSet
}

/// Cardio activity types this app can pull in from other apps' HealthKit
/// workouts. Deliberately narrow (no strength training) — HealthKit gives
/// third-party workouts no set/rep breakdown, only duration + distance,
/// which only maps cleanly onto a single cardio `ExerciseLog`.
public enum ExternalWorkoutActivityType: String, Sendable, Equatable, CaseIterable {
    case running
    case cycling
}

/// One workout read back from Apple Health, written there by another app
/// (e.g. Adidas Running, Strava). `sourceBundleIdentifier` is what callers
/// use to exclude this app's own written workouts from re-import — see
/// `HealthKitService.fetchExternalWorkouts`.
public struct ExternalWorkoutSample: Sendable, Equatable {
    public let hkUUID: String
    public let activityType: ExternalWorkoutActivityType
    public let startDate: Date
    public let endDate: Date
    public let distanceKm: Double?
    public let sourceName: String
    public let sourceBundleIdentifier: String
    /// `HKWorkout.duration`: die AKTIVE Zeit des Workouts — ohne Pausen bzw. die
    /// Dauer, die die Quell-App angibt. Kann kuerzer sein als `startDate` bis
    /// `endDate`; das ist die Laufzeit, die auch die Quell-App zeigt.
    public let activeDurationSeconds: TimeInterval?

    public init(
        hkUUID: String,
        activityType: ExternalWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        distanceKm: Double?,
        sourceName: String,
        sourceBundleIdentifier: String,
        activeDurationSeconds: TimeInterval? = nil
    ) {
        self.hkUUID = hkUUID
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.distanceKm = distanceKm
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.activeDurationSeconds = activeDurationSeconds
    }
}

/// Bundle of values pulled from the Apple Health profile during onboarding.
/// All fields optional — Apple Health doesn't guarantee any particular
/// characteristic has been set by the user.
public struct OnboardingHealthSnapshot: Sendable, Equatable {
    public let dateOfBirth: Date?
    public let sex: BiologicalSex
    public let heightCm: Double?
    public let weightKg: Double?

    public init(dateOfBirth: Date?, sex: BiologicalSex, heightCm: Double?, weightKg: Double?) {
        self.dateOfBirth = dateOfBirth
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
    }

    public static let empty = OnboardingHealthSnapshot(
        dateOfBirth: nil, sex: .notSet, heightCm: nil, weightKg: nil
    )
}
