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

    public init(
        hkUUID: String,
        activityType: ExternalWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        distanceKm: Double?,
        sourceName: String,
        sourceBundleIdentifier: String
    ) {
        self.hkUUID = hkUUID
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.distanceKm = distanceKm
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
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
