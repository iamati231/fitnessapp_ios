#if canImport(SwiftData)
import Foundation
import SwiftData

/// One sip of water — quick-add via the Water-Tracker tile in CalculatorsView.
/// Stored at millilitre precision; daily aggregation happens in the view.
@Model
public final class WaterEntry {
    public var date: Date
    public var amountMl: Int

    public init(date: Date = Date(), amountMl: Int) {
        self.date = date
        self.amountMl = amountMl
    }
}
#endif
