#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// One body-measurement row. Raw metric inputs (weight, circumferences in cm) plus
/// derived metrics (BMI, body-fat %, FFMI, BMR) — all stored unrounded so the UI
/// can apply `truncated(to: 2)` when displaying.
///
/// Conforms to `WeightSample` so it plugs straight into `BodyCalculations.projectWeightTrend`.
@Model
public final class BodyMeasurement: WeightSample {
    public var date: Date
    public var ageYearsAtMeasurement: Int

    public var weightKg: Double

    // Raw circumferences (all optional — user fills what they measured).
    public var neckCm: Double?
    public var waistCm: Double?
    public var hipCm: Double?
    public var shoulderCm: Double?
    public var chestCm: Double?
    public var upperArmCm: Double?
    public var thighCm: Double?
    public var calfCm: Double?

    // Derived metrics — populated at save time via BodyCalculations.computeDerivedFields.
    public var bmi: Double?
    public var navyBodyFatPct: Double?
    public var deurenbergBodyFatPct: Double?
    public var selectedBodyFatPct: Double?
    public var fatFreeMassKg: Double?
    public var ffmi: Double?
    public var normalizedFfmi: Double?
    public var bmr: Double?

    public init(
        date: Date = Date(),
        ageYearsAtMeasurement: Int,
        weightKg: Double,
        neckCm: Double? = nil,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        shoulderCm: Double? = nil,
        chestCm: Double? = nil,
        upperArmCm: Double? = nil,
        thighCm: Double? = nil,
        calfCm: Double? = nil,
        bmi: Double? = nil,
        navyBodyFatPct: Double? = nil,
        deurenbergBodyFatPct: Double? = nil,
        selectedBodyFatPct: Double? = nil,
        fatFreeMassKg: Double? = nil,
        ffmi: Double? = nil,
        normalizedFfmi: Double? = nil,
        bmr: Double? = nil
    ) {
        self.date = date
        self.ageYearsAtMeasurement = ageYearsAtMeasurement
        self.weightKg = weightKg
        self.neckCm = neckCm
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.shoulderCm = shoulderCm
        self.chestCm = chestCm
        self.upperArmCm = upperArmCm
        self.thighCm = thighCm
        self.calfCm = calfCm
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

extension BodyMeasurement {
    /// Build a fully-populated row with ALL derived fields filled in. Mirrors
    /// `buildBodyMeasurement` in `BodyCalculations.kt` — used by both onboarding
    /// (so the very first measurement already has KFA/FFMI on Home) and the
    /// regular save path.
    ///
    /// Pass `selectedBodyFatPct = nil` to let the function pick a sensible default:
    /// Navy if waist+neck (+hip for female) are given, otherwise Deurenberg.
    public static func makeDerived(
        date: Date = Date(),
        ageYears: Int,
        weightKg: Double,
        heightCm: Double,
        profile: BodyFormulaProfile,
        neckCm: Double? = nil,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        shoulderCm: Double? = nil,
        chestCm: Double? = nil,
        upperArmCm: Double? = nil,
        thighCm: Double? = nil,
        calfCm: Double? = nil,
        selectedBodyFatPct: Double? = nil
    ) -> BodyMeasurement {
        let bmi = heightCm > 0 ? BodyCalculations.bmi(weightKg: weightKg, heightCm: heightCm) : nil
        let canCalcNavy = heightCm > 0 && neckCm != nil && waistCm != nil &&
            (profile == .male || hipCm != nil)
        let navyBf: Double? = canCalcNavy
            ? BodyCalculations.navyBodyFat(profile: profile, heightCm: heightCm,
                                           neckCm: neckCm!, waistCm: waistCm!, hipCm: hipCm)
            : nil
        let deurenBf: Double? = bmi.map {
            BodyCalculations.deurenbergBodyFat(bmi: $0, ageYears: ageYears, profile: profile)
        }
        let chosenBf = selectedBodyFatPct ?? navyBf ?? deurenBf
        let ffm = chosenBf.map { BodyCalculations.fatFreeMass(weightKg: weightKg, bodyFatPercentage: $0) }
        let ffmi = (ffm != nil && heightCm > 0)
            ? BodyCalculations.ffmi(fatFreeMassKg: ffm!, heightCm: heightCm)
            : nil
        let nFfmi = (ffmi != nil && heightCm > 0)
            ? BodyCalculations.normalizedFfmi(ffmi: ffmi!, heightCm: heightCm)
            : nil
        let bmr = heightCm > 0
            ? BodyCalculations.bmrMifflinStJeor(weightKg: weightKg, heightCm: heightCm,
                                                ageYears: ageYears, profile: profile)
            : nil

        return BodyMeasurement(
            date: date,
            ageYearsAtMeasurement: ageYears,
            weightKg: weightKg,
            neckCm: neckCm, waistCm: waistCm, hipCm: hipCm,
            shoulderCm: shoulderCm, chestCm: chestCm, upperArmCm: upperArmCm,
            thighCm: thighCm, calfCm: calfCm,
            bmi: bmi,
            navyBodyFatPct: navyBf,
            deurenbergBodyFatPct: deurenBf,
            selectedBodyFatPct: selectedBodyFatPct,
            fatFreeMassKg: ffm,
            ffmi: ffmi,
            normalizedFfmi: nFfmi,
            bmr: bmr
        )
    }
}
#endif
