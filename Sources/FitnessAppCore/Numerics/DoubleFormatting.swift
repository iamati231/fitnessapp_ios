import Foundation

extension Double {
    /// Truncate (NOT round) to `decimals` decimal places.
    ///
    /// Body-composition values are floored so calculated metrics aren't cosmetically
    /// rounded up (15.86 stays "15.86" rather than jumping to "15.9"). Floor-rounding
    /// is the right call for fitness tracking — overstating progress destroys trust
    /// the moment the user spot-checks the math.
    ///
    /// Mirrors `Double.truncateTo(decimals: Int)` in `BodyCalculations.kt` (uses `floor`).
    public func truncated(to decimals: Int) -> Double {
        precondition(decimals >= 0, "decimals must be non-negative")
        let factor = pow(10.0, Double(decimals))
        return (self * factor).rounded(.down) / factor
    }

    /// App-wide standard for numeric display — ALWAYS 2 decimals.
    ///
    /// Forces trailing zeros (80.0 -> "80,00") for a uniform typographic look across
    /// dashboards, cards, and calculator results. Locale-aware via `Locale.current`,
    /// so DE users see the comma separator ("80,00") and EN/TR users see the dot.
    ///
    /// Where it matters, apply `truncated(to: 2)` BEFORE formatting so values aren't
    /// rounded up:  `value.truncated(to: 2).formattedTwoDecimals`.
    public var formattedTwoDecimals: String {
        String(format: "%.2f", locale: Locale.current, self)
    }
}
