import Foundation

/// Minimal interface a row needs to participate in the weight-trend regression.
/// Decouples `BodyCalculations.projectWeightTrend` from the SwiftData model so
/// the algorithm stays testable with plain structs.
public protocol WeightSample {
    var date: Date { get }
    var weightKg: Double { get }
}
