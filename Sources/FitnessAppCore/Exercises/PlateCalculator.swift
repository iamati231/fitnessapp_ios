import Foundation

/// One row in the plate breakdown: weight (kg or lbs) + count per side.
public struct PlateConfig: Equatable, Sendable {
    public let weight: Double
    public let count: Int
    public init(weight: Double, count: Int) {
        self.weight = weight
        self.count = count
    }
}

/// Plate-Calculator with greedy + per-plate inventory cap.
///
/// Mirrors `calcPlates` in Android `CalculatorsScreen.kt`. The greedy is intentional:
/// users want the visually-cleanest stack ("1x25 + 1x15" beats "5x8"), and the cap
/// forces the algorithm into smaller plates when the heavier ones run out.
public enum PlateCalculator {

    // MARK: Constants (mirroring Android)

    public static let availablePlatesKg:  [Double] = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
    public static let availablePlatesLbs: [Double] = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5, 1.25]

    public static let maxTargetKg:  Double = 500.0
    public static let maxTargetLbs: Double = 1100.0
    public static let maxBarKg:     Double = 30.0
    public static let maxBarLbs:    Double = 65.0

    /// Heavy-Lifter default inventory per side. Equals the hard MAX cap per plate
    /// class so 500 kg (resp. 1100 lbs) total is reachable with the heavy plates.
    public static let defaultInventoryKg: [Double: Int] = [
        25.0: 10, 20.0: 10, 15.0: 1, 10.0: 1, 5.0: 1, 2.5: 1, 1.25: 1
    ]
    public static let defaultInventoryLbs: [Double: Int] = [
        45.0: 10, 35.0: 10, 25.0: 1, 10.0: 1, 5.0: 1, 2.5: 1, 1.25: 1
    ]

    // MARK: Algorithm

    /// Greedy with per-plate cap. Iterates plates heaviest-first; for each plate,
    /// takes `min(needed, cap)`. The leftover spills into smaller plates so the
    /// breakdown stays loadable with the user's actual inventory.
    ///
    /// `plates` MUST be sorted heaviest-first.
    /// `inventory[plate]` missing -> treated as `Int.max` (unlimited).
    /// Returns an empty array when target <= bar.
    public static func calculate(
        targetKg target: Double,
        barKg bar: Double,
        plates: [Double],
        inventory: [Double: Int]
    ) -> [PlateConfig] {
        let perSide = (target - bar) / 2.0
        guard perSide > 0 else { return [] }

        var remaining = perSide
        var result: [PlateConfig] = []
        for plate in plates {
            if remaining < 0.01 { break }
            let cap = inventory[plate] ?? .max
            if cap <= 0 { continue }
            let needed = Int(remaining / plate)
            let count = min(needed, cap)
            if count > 0 {
                result.append(PlateConfig(weight: plate, count: count))
                remaining -= Double(count) * plate
            }
        }
        return result
    }

    // MARK: Convenience

    public enum Unit: String, Sendable {
        case kg, lbs

        public var availablePlates: [Double] {
            self == .kg ? PlateCalculator.availablePlatesKg : PlateCalculator.availablePlatesLbs
        }
        public var defaultInventory: [Double: Int] {
            self == .kg ? PlateCalculator.defaultInventoryKg : PlateCalculator.defaultInventoryLbs
        }
        public var maxTarget: Double {
            self == .kg ? PlateCalculator.maxTargetKg : PlateCalculator.maxTargetLbs
        }
        public var maxBar: Double {
            self == .kg ? PlateCalculator.maxBarKg : PlateCalculator.maxBarLbs
        }
    }

    /// Convenience overload using a unit (auto-picks plate set + default inventory).
    public static func calculate(
        target: Double,
        bar: Double,
        unit: Unit,
        inventory: [Double: Int]? = nil
    ) -> [PlateConfig] {
        calculate(
            targetKg: target,
            barKg: bar,
            plates: unit.availablePlates,
            inventory: inventory ?? unit.defaultInventory
        )
    }
}
