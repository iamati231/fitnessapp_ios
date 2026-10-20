import Foundation

/// Display-only kg<->lbs conversion backing the `weight_unit` app setting
/// (`@AppStorage("weight_unit")`, values `"kg"`/`"lbs"`).
///
/// Storage stays kg everywhere (`*Kg`-named properties, `ExerciseLog.weight`)
/// - this converts ONLY for presenting or parsing a value in the user's
/// chosen display unit, never for persisting a non-kg number. Replaces the
/// previously duplicated `kg / 0.453592` call sites in `ExerciseDetailView`,
/// `ExerciseCard` and `SettingsView`.
public enum WeightUnit: String, Sendable {
    case kg, lbs

    /// Same constant every existing conversion already used.
    static let kgPerLb = 0.453592

    public init(rawSetting: String) {
        self = rawSetting == "lbs" ? .lbs : .kg
    }

    /// Canonical kg value -> this unit, for display.
    public func fromKg(_ kg: Double) -> Double {
        self == .kg ? kg : kg / Self.kgPerLb
    }

    /// A value entered in this unit -> canonical kg, for storage.
    public func toKg(_ value: Double) -> Double {
        self == .kg ? value : value * Self.kgPerLb
    }
}
