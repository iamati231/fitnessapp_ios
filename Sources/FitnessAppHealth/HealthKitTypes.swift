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
