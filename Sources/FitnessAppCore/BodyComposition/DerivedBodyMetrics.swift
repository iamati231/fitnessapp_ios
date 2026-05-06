import Foundation

/// Bundle of all body-composition values derived from a single set of raw inputs.
/// Mirrors `DerivedBodyMetrics` in `BodyCalculations.kt`.
public struct DerivedBodyMetrics: Equatable, Sendable {
    public let bmi: Double
    public let navyBodyFatPct: Double?
    public let deurenbergBodyFatPct: Double
    public let selectedBodyFatPct: Double
    public let fatFreeMassKg: Double
    public let ffmi: Double
    public let normalizedFfmi: Double
    public let bmr: Double

    public init(
        bmi: Double,
        navyBodyFatPct: Double?,
        deurenbergBodyFatPct: Double,
        selectedBodyFatPct: Double,
        fatFreeMassKg: Double,
        ffmi: Double,
        normalizedFfmi: Double,
        bmr: Double
    ) {
        self.bmi = bmi
        self.navyBodyFatPct = navyBodyFatPct
        self.deurenbergBodyFatPct = deurenbergBodyFatPct
        self.selectedBodyFatPct = selectedBodyFatPct
        self.fatFreeMassKg = fatFreeMassKg
        self.ffmi = ffmi
        self.normalizedFfmi = normalizedFfmi
        self.bmr = bmr
    }
}
