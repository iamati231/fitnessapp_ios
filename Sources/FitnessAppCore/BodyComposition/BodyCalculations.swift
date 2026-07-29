import Foundation

/// Pure body-composition formulas (BMI, Navy KFA, Deurenberg, FFMI, BMR, WHR, weight-trend).
///
/// All inputs are metric (kg, cm). Results are raw, unrounded `Double` values — the UI is
/// responsible for `truncated(to:)` + `formattedTwoDecimals` (see `DoubleFormatting.swift`).
///
/// 1:1 port of `BodyCalculations.kt` from the Android codebase. Formula constants and
/// algorithm semantics are byte-identical so parity tests against Android values pass.
public enum BodyCalculations {

    // MARK: BMI

    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    // MARK: Navy body-fat % (Hodgdon & Beckett — measurements in inches)

    /// US Navy direct-regression formula. Returns `nil` if inputs are out of valid
    /// domain (non-positive measurements, missing hip for female, log10 of <=0).
    ///
    /// Male:   %BF = 86.010 * log10(waist - neck) - 70.041 * log10(height) + 36.76
    /// Female: %BF = 163.205 * log10(waist + hip - neck) - 97.684 * log10(height) - 78.387
    public static func navyBodyFat(
        profile: BodyFormulaProfile,
        heightCm: Double,
        neckCm: Double,
        waistCm: Double,
        hipCm: Double? = nil
    ) -> Double? {
        guard heightCm > 0, neckCm > 0, waistCm > 0 else { return nil }
        let height = cmToInches(heightCm)
        let neck = cmToInches(neckCm)
        let waist = cmToInches(waistCm)

        switch profile {
        case .male:
            let waistMinusNeck = waist - neck
            guard waistMinusNeck > 0 else { return nil }
            return 86.010 * log10(waistMinusNeck) - 70.041 * log10(height) + 36.76
        case .female:
            guard let hipCm, hipCm > 0 else { return nil }
            let hip = cmToInches(hipCm)
            let denom = waist + hip - neck
            guard denom > 0 else { return nil }
            return 163.205 * log10(denom) - 97.684 * log10(height) - 78.387
        }
    }

    // MARK: Deurenberg body-fat % (BMI-based)

    public static func deurenbergBodyFat(
        bmi: Double,
        ageYears: Int,
        profile: BodyFormulaProfile
    ) -> Double {
        let sexValue = (profile == .male) ? 1.0 : 0.0
        return 1.20 * bmi + 0.23 * Double(ageYears) - 10.8 * sexValue - 5.4
    }

    // MARK: Fat-free mass / fat mass

    public static func fatFreeMass(weightKg: Double, bodyFatPercentage: Double) -> Double {
        weightKg * (1.0 - bodyFatPercentage / 100.0)
    }

    // DEL-242: `fatMass` entfernt — nur ein Test rief es auf. Es gibt kein
    // Feld dafuer in `DerivedBodyMetrics`, keine CSV-Spalte und keinen Aufruf
    // in `makeDerived`. Verlustfrei rekonstruierbar als
    // `weightKg - fatFreeMass(...)`, falls die Fettmasse je angezeigt werden
    // soll.

    // MARK: FFMI / normalized FFMI

    public static func ffmi(fatFreeMassKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100.0
        return fatFreeMassKg / (heightM * heightM)
    }

    public static func normalizedFfmi(ffmi: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100.0
        return ffmi + 6.1 * (1.8 - heightM)
    }

    // MARK: WHR (Waist-to-Hip Ratio)

    /// WHO reference: women >= 0.85 / men >= 0.90 indicates elevated abdominal-obesity risk.
    public static func whr(waistCm: Double, hipCm: Double) -> Double {
        guard hipCm > 0 else { return 0.0 }
        return waistCm / hipCm
    }

    // MARK: BMR

    public static func bmrMifflinStJeor(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        profile: BodyFormulaProfile
    ) -> Double {
        let base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(ageYears)
        return profile == .male ? base + 5.0 : base - 161.0
    }

    /// Katch-McArdle BMR — uses lean body mass. More accurate for athletes because
    /// it accounts for body composition rather than just weight, height, and age.
    public static func bmrKatchMcArdle(fatFreeMassKg: Double) -> Double {
        370.0 + 21.6 * fatFreeMassKg
    }

    /// TDEE = BMR * Physical Activity Level. Default PAL = 1.55 (moderately active).
    public static func tdee(bmr: Double, activityFactor: Double = 1.55) -> Double {
        bmr * activityFactor
    }

    // MARK: Weight-trend projection (linear regression)

    private static let secondsPerWeek: Double = 7 * 24 * 3600

    /// Linear-regression projection on the last up-to-6 measurements.
    /// Returns `nil` when:
    ///  - fewer than 3 measurements,
    ///  - measurements span less than 1 day,
    ///  - x-variance is degenerate (all measurements within microseconds),
    ///  - projected weight falls outside the plausible range 20-400 kg.
    public static func projectWeightTrend(
        measurements: [some WeightSample],
        weeksAhead: Int
    ) -> Double? {
        let sorted = measurements.sorted { $0.date < $1.date }
        let points = Array(sorted.suffix(6))
        guard points.count >= 3 else { return nil }

        let firstDate = points.first!.date
        let lastDate = points.last!.date
        let spanWeeks = lastDate.timeIntervalSince(firstDate) / secondsPerWeek
        guard spanWeeks >= 1.0 / 7.0 else { return nil }

        let xValues = points.map { $0.date.timeIntervalSince(firstDate) / secondsPerWeek }
        let yValues = points.map { $0.weightKg }
        let xMean = xValues.reduce(0, +) / Double(xValues.count)
        let yMean = yValues.reduce(0, +) / Double(yValues.count)

        let ssXX = xValues.reduce(0.0) { acc, x in acc + (x - xMean) * (x - xMean) }
        guard ssXX >= 1e-9 else { return nil }

        let slope = zip(xValues, yValues).reduce(0.0) { acc, pair in
            acc + (pair.0 - xMean) * (pair.1 - yMean)
        } / ssXX

        let projectedX = xValues.last! + Double(weeksAhead)
        let projected = yMean + slope * (projectedX - xMean)
        return (20.0...400.0).contains(projected) ? projected : nil
    }

    /// Weight delta vs. the most recent measurement at least 6 days older than
    /// the latest one. Returns nil when no such reference exists (only one
    /// measurement, or all measurements within a week of the latest).
    ///
    /// Six-day threshold (rather than strict 7) is intentional — users don't
    /// measure on the dot. Any reasonably-spaced "last week" sample counts.
    /// Used by `DashboardView`'s "+0.40 kg / Wo." badge.
    public static func weeklyWeightDelta(measurements: [some WeightSample]) -> Double? {
        let sorted = measurements.sorted { $0.date > $1.date }
        guard let latest = sorted.first else { return nil }
        let cutoff = latest.date.addingTimeInterval(-6 * 24 * 3600)
        guard let weekAgo = sorted.first(where: { $0.date <= cutoff }) else { return nil }
        return latest.weightKg - weekAgo.weightKg
    }

    /// True when recent measurements show a >2 kg standard deviation — signals the
    /// projection is unreliable and the UI should hide it (or warn the user).
    public static func isTrendUnreliable(measurements: [some WeightSample]) -> Bool {
        let points = Array(measurements.sorted { $0.date < $1.date }.suffix(6))
        guard points.count >= 3 else { return false }
        let weights = points.map { $0.weightKg }
        let mean = weights.reduce(0, +) / Double(weights.count)
        let variance = weights.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(weights.count)
        return variance > 4.0
    }

    // MARK: Compose all derived fields

    /// Compute every derived metric for a single measurement. Mirrors
    /// `BodyCalculations.computeDerivedFields` in Kotlin — Navy KFA is preferred when
    /// available; BMR uses Katch-McArdle when Navy is available, otherwise Mifflin-St Jeor.
    public static func computeDerivedFields(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        profile: BodyFormulaProfile,
        neckCm: Double?,
        waistCm: Double?,
        hipCm: Double?
    ) -> DerivedBodyMetrics {
        let bmiValue = bmi(weightKg: weightKg, heightCm: heightCm)

        let canCalcNavy = neckCm != nil && waistCm != nil &&
            (profile == .male || hipCm != nil)
        let navyKfa: Double? = canCalcNavy
            ? navyBodyFat(profile: profile, heightCm: heightCm,
                          neckCm: neckCm!, waistCm: waistCm!, hipCm: hipCm)
            : nil

        let deurenbergKfa = deurenbergBodyFat(bmi: bmiValue, ageYears: ageYears, profile: profile)
        let selectedKfa = navyKfa ?? deurenbergKfa
        let ffm = fatFreeMass(weightKg: weightKg, bodyFatPercentage: selectedKfa)
        let ffmiValue = ffmi(fatFreeMassKg: ffm, heightCm: heightCm)
        let normFfmi = normalizedFfmi(ffmi: ffmiValue, heightCm: heightCm)

        // Prefer Katch-McArdle (uses fat-free mass — more accurate for athletes);
        // fall back to Mifflin-St Jeor only when Navy KFA wasn't available.
        let bmr = navyKfa != nil
            ? bmrKatchMcArdle(fatFreeMassKg: ffm)
            : bmrMifflinStJeor(weightKg: weightKg, heightCm: heightCm,
                               ageYears: ageYears, profile: profile)

        return DerivedBodyMetrics(
            bmi: bmiValue,
            navyBodyFatPct: navyKfa,
            deurenbergBodyFatPct: deurenbergKfa,
            selectedBodyFatPct: selectedKfa,
            fatFreeMassKg: ffm,
            ffmi: ffmiValue,
            normalizedFfmi: normFfmi,
            bmr: bmr
        )
    }

    // MARK: Internals

    private static func cmToInches(_ cm: Double) -> Double { cm / 2.54 }
}
